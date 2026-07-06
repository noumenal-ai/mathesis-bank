#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Mathesis — the per-deposit gate for form-raised deposit PRs.
#
#   ci/gate_deposit.sh <deposit-dir>
#
# where <deposit-dir> is a `deposits/<slug>/` directory containing exactly one
# `submission.lean` (the single-file format the site form emits: a leading
# `/-! ... @kind:/@title:/@decls:/@pin: ... -/` header, then Lean source).
#
# Flow:
#   1. parse   the @-header (ci/parse_deposit.py) — fail closed on bad header.
#   2. build   submission.lean UNDER ISOLATION at the pinned toolchain
#              (produces .olean; elaboration is the untrusted step).
#   3. export  the @decls' constant closure with lean4export → candidate.export.
#   4. adjudicate:
#        * @discharges set → fetch the frozen trusted reference R for that
#          claim and run  `mathesis-adjudicate --reference <R> <cand> -- <decls>`
#          (self-audit PLUS statement-identity; nonzero = smuggle/reject).
#        * no @discharges  → run `mathesis-adjudicate <cand> -- <decls>`
#          (self-audit only: replay + axioms + triviality).
#   5. emit    a markdown verdict to stdout and set the exit code.
#
# EXIT CODE CONTRACT (this is the gate; callers key on it, not on the markdown):
#   0  admit            — every leg passed, no triviality flag.
#   0  needs-review     — legs passed but a target is syntactically trivial
#                         (kernel-valid but possibly mis-claimed): a human
#                         merges, CI does not block. Exit 0 by design.
#   2  reject           — a leg failed: header invalid, build failed, export
#                         failed, replay rejected, an illegal axiom, or (with
#                         --reference) a statement-identity smuggle.
#   3  block            — @discharges points at a nonexistent MTH.C claim
#                         (a structural error in the deposit, not a proof
#                         failure): the deposit cannot be adjudicated at all.
# Only 0 is a pass; both 2 and 3 fail the PR job.
#
# ── ISOLATION / TRUST MODEL (read this) ──────────────────────────────────────
# Lean elaboration can run ARBITRARY IO at build time (via #eval, elaboration
# macros, `initialize`). The submission.lean here is UNTRUSTED (it came from a
# fork PR). Two independent layers contain it:
#
#   (a) The PR job runs on the `pull_request` event with a READ-ONLY token and
#       NO repo secrets (see .github/workflows/deposit.yml `permissions:
#       contents: read`). A malicious build cannot push, cannot exfiltrate a
#       secret (there are none), cannot mutate the repo. This is the primary
#       isolation and it is GitHub-enforced, not something this script can undo.
#   (b) FS confinement: if `landrun` (Landlock, Linux — the same tool the bank
#       VM uses) is on PATH, the `lean` build is wrapped in it so the build can
#       only read the toolchain + the deposit dir and write only to a scratch
#       out-dir. If landrun is absent (e.g. macOS local runs) the build runs
#       bare and we LOG LOUDLY that network-egress confinement is a documented
#       follow-on — the read-only token still holds.
#
# Crucially, the gate's TRUST is NOT in the build. The build is untrusted and
# only produces a CANDIDATE export. Admission is decided by the trusted Lean
# kernel RE-PLAYING that export from scratch (mathesis-adjudicate) plus, for a
# discharge, statement-identity against the FROZEN trusted R (which the deposit
# never gets to rebuild). So a malicious build can misbehave inside the sandbox
# but CANNOT forge an admission: a bogus export just fails replay or identity.
# ---------------------------------------------------------------------------
set -o pipefail

ROOT="${VERIFY_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
PY="${PYTHON:-python3}"

DEP_DIR="${1:?usage: gate_deposit.sh <deposit-dir>}"
DEP_DIR="$(cd "$DEP_DIR" 2>/dev/null && pwd || echo "$DEP_DIR")"
SLUG="$(basename "$DEP_DIR")"
SUBMISSION="$DEP_DIR/submission.lean"

# Tools (overridable so CI can point at the built exe / pinned exporter).
ADJUDICATE_BIN="${MATHESIS_ADJUDICATE:?set MATHESIS_ADJUDICATE to the built mathesis-adjudicate exe}"
LEAN4EXPORT_BIN="${MATHESIS_LEAN4EXPORT:-lean4export}"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/mth-gate-$SLUG.XXXXXX")"
CAND_EXPORT="$WORK/candidate.export"
trap 'rm -rf "$WORK"' EXIT

# Markdown verdict accumulates in this file; printed to stdout at the end.
REPORT="$WORK/report.md"
: > "$REPORT"
md() { printf '%s\n' "$*" >> "$REPORT"; }

emit_and_exit() {  # <exit-code>
  cat "$REPORT"
  exit "$1"
}

# Embed UNTRUSTED text (build/export/adjudicate/fetch logs, parser stderr) into
# the report as a GitHub-safe INDENTED code block. A ``` fenced block can be
# broken out of by a ``` line inside the untrusted content (fence-breakout →
# forged markdown / fake verdict in the PR comment). A 4-space-indented block
# has no closing delimiter to spoof: every line (backticks included) renders
# literally. Caller wraps with a leading + trailing `md ""`.
embed_log() { sed -e 's/\r$//' -e 's/^/    /'; }

md "### Deposit \`$SLUG\`"
md ""

# ── 1. parse ────────────────────────────────────────────────────────────────
if [ ! -f "$SUBMISSION" ]; then
  md "- **reject** — no \`submission.lean\` in \`$DEP_DIR\`."
  emit_and_exit 2
fi

PARSED="$("$PY" "$ROOT/ci/parse_deposit.py" "$SUBMISSION" 2>"$WORK/parse.err")"
if [ $? -ne 0 ]; then
  md "- **reject** — header parse failed:"
  md ""
  embed_log < "$WORK/parse.err" >> "$REPORT"
  md ""
  emit_and_exit 2
fi

jget() { "$PY" -c "import json,sys;print(json.load(sys.stdin).get(sys.argv[1]) or '')" "$1" <<<"$PARSED"; }
jget_list() { "$PY" -c "import json,sys;print(' '.join(json.load(sys.stdin).get(sys.argv[1]) or []))" "$1" <<<"$PARSED"; }

KIND="$(jget kind)"
TITLE="$(jget title)"
TITLE="${TITLE//\`/}"          # untrusted title: drop backticks so it stays inline-literal in the report
MODULE="$(jget module)"
PIN="$(jget pin)"
DISCHARGES="$(jget discharges)"
DECLS="$(jget_list decls)"     # space-joined (display only)

# Parse decls into an ARRAY so they reach lean4export / the gate exe as quoted
# argv items — never word-split or glob-expanded. parse_deposit.py already
# rejected any decl with whitespace/glob/shell metacharacters; this is the
# matching safe-passing side (defense-in-depth, not the only line of defense).
# `while read` (not `mapfile`) so this runs on bash 3.2 (macOS) as well as CI.
DECLS_ARR=()
while IFS= read -r __d; do [ -n "$__d" ] && DECLS_ARR+=("$__d"); done \
  < <("$PY" -c 'import json,sys;[print(x) for x in (json.load(sys.stdin).get("decls") or [])]' <<<"$PARSED")

md "- **kind**: \`$KIND\`  **title**: $TITLE  **module**: \`$MODULE\`"
md "- **decls**: $(printf '`%s` ' "${DECLS_ARR[@]}")"
md "- **pin**: \`$PIN\`"
[ -n "$DISCHARGES" ] && md "- **discharges**: \`$DISCHARGES\`"
md ""

# ── discharge preflight: a @discharges must resolve to a REAL MTH.C claim ────
# A dangling discharge is a structural error: we cannot know what R to check
# statement-identity against, so we BLOCK (exit 3) rather than silently self-
# auditing (which would let a deposit claim to discharge a claim it does not).
REF_EXPORT=""
TARGET_DECLS_ARR=("${DECLS_ARR[@]}")   # decls handed to the gate exe (claim's, under --reference)
if [ -n "$DISCHARGES" ]; then
  # Path-traversal belt: @discharges is interpolated into a registry path below.
  # parse_deposit.py already constrained it to the claims-handle grammar; re-check
  # here, fail-closed, so this script is safe even if invoked with a different
  # parser. A handle with `/`, `..`, or off-grammar shape never reaches the path.
  if [[ ! "$DISCHARGES" =~ ^MTH\.C-[0-9]{4}-[0-9]{4,}$ ]]; then
    md "- **block** — \`@discharges: $DISCHARGES\` is not a valid claims handle (MTH.C-YYYY-NNNN)."
    emit_and_exit 3
  fi
  CLAIM_MANIFEST="$ROOT/registry/claims/$DISCHARGES/manifest.json"
  if [ ! -f "$CLAIM_MANIFEST" ]; then
    md "- **block** — \`@discharges: $DISCHARGES\` points at a nonexistent claim (no \`registry/claims/$DISCHARGES/manifest.json\`)."
    emit_and_exit 3
  fi

  # The trusted target is the claim's OWN statement.decl_names (NOT the
  # deposit's @decls — the deposit does not get to rename the target it
  # claims to discharge). Statement-identity is checked against these.
  CLAIM_DECLS_ARR=()
  while IFS= read -r __d; do [ -n "$__d" ] && CLAIM_DECLS_ARR+=("$__d"); done < <("$PY" -c '
import json,sys
m=json.load(open(sys.argv[1]))
[print(x) for x in ((m.get("statement") or {}).get("decl_names") or [])]
' "$CLAIM_MANIFEST")
  if [ "${#CLAIM_DECLS_ARR[@]}" -eq 0 ]; then
    md "- **block** — claim \`$DISCHARGES\` has no \`statement.decl_names\` to check identity against."
    emit_and_exit 3
  fi

  # Fetch the frozen trusted reference blob by sha256 (reuses ci/fetch_exports.sh
  # semantics: content-addressed, sha256-verified after download). The claim's
  # frozen_export.sha256 is R.
  REF_SHA="$("$PY" -c '
import json,sys
m=json.load(open(sys.argv[1]))
print((m.get("frozen_export") or {}).get("sha256") or "")
' "$CLAIM_MANIFEST")"
  if [ -z "$REF_SHA" ]; then
    md "- **block** — claim \`$DISCHARGES\` has no \`frozen_export.sha256\` (no trusted reference R to check against)."
    emit_and_exit 3
  fi

  EXPORTS_DIR="${MATHESIS_EXPORTS_DIR:-$ROOT/registry/_shared/exports}"
  REF_EXPORT="$EXPORTS_DIR/$REF_SHA.export"
  if [ ! -f "$REF_EXPORT" ]; then
    # Reuse the shared fetch path. It resolves shas referenced by manifests
    # from the configured store and sha256-verifies each blob after download.
    md "- fetching frozen reference R (\`$REF_SHA\`) via ci/fetch_exports.sh"
    # Targeted: fetch ONLY this reference sha (not the whole corpus).
    if ! MATHESIS_EXPORTS_DIR="$EXPORTS_DIR" bash "$ROOT/ci/fetch_exports.sh" "$REF_SHA" >>"$WORK/fetch.log" 2>&1; then
      md "- **reject** — could not fetch/verify frozen reference R for \`$DISCHARGES\`:"
      md ""
      tail -n 20 "$WORK/fetch.log" | embed_log >> "$REPORT"
      md ""
      emit_and_exit 2
    fi
  fi
  if [ ! -f "$REF_EXPORT" ]; then
    md "- **reject** — frozen reference R blob \`$REF_SHA.export\` absent after fetch."
    emit_and_exit 2
  fi
  # RE-VERIFY the reference blob's sha256 HERE, unconditionally — do NOT trust it
  # by filename. fetch_exports.sh verifies on download, but the "already present"
  # branch above skips fetch entirely; an attacker who can seed a wrong-content
  # file at <REF_SHA>.export would otherwise supply a forged R. Content-addressing
  # is only a trust boundary if the content is actually hashed against the name.
  if command -v sha256sum >/dev/null 2>&1; then
    GOT_SHA="$(sha256sum "$REF_EXPORT" | cut -d' ' -f1)"
  else
    GOT_SHA="$(shasum -a 256 "$REF_EXPORT" | cut -d' ' -f1)"
  fi
  if [ "$GOT_SHA" != "$REF_SHA" ]; then
    md "- **reject** — frozen reference R blob content sha256 (\`$GOT_SHA\`) ≠ expected (\`$REF_SHA\`); refusing to trust it."
    emit_and_exit 2
  fi
  # Identity is checked on the CLAIM's decls (the trusted names, bank-owned).
  TARGET_DECLS_ARR=("${CLAIM_DECLS_ARR[@]}")
fi

# ── 2. build submission.lean UNDER ISOLATION at the pinned toolchain ─────────
# Pin the toolchain for the untrusted build to exactly the deposit @pin (which
# parse_deposit already forced == leanprover/lean4:v4.31.0). We use the same
# LEAN_SYSROOT the gate exe uses so `lean` resolves without a project toolchain.
md ""
md "#### build (untrusted, isolated)"
BUILD_LOG="$WORK/build.log"

# Copy the untrusted source into the scratch dir under a FIXED module name
# (Submission) so: (a) `lean --root=$WORK` treats the scratch dir as the module
# root — the source need not live inside any lake package, and lean will not
# reject it as "not contained in root directory"; and (b) the exported module
# name is deterministic regardless of the deposit @module (which is untrusted
# and could carry path separators). The deposit's decls are root-namespaced
# inside this module, so a fixed module name is sound.
cp "$SUBMISSION" "$WORK/Submission.lean"
# `timeout` bounds a non-terminating / runaway elaboration of the UNTRUSTED
# build (availability guard, independent of the read-only-token + replay trust
# model). Overridable via MATHESIS_BUILD_TIMEOUT (seconds). `timeout` is
# coreutils (present on the ubuntu-latest CI runner); portably fall back to
# `gtimeout`, else run without a bound (and note it) so non-Linux hosts work.
TIMEOUT_PREFIX=()
if command -v timeout >/dev/null 2>&1; then TIMEOUT_PREFIX=(timeout "${MATHESIS_BUILD_TIMEOUT:-300}")
elif command -v gtimeout >/dev/null 2>&1; then TIMEOUT_PREFIX=(gtimeout "${MATHESIS_BUILD_TIMEOUT:-300}")
else md "- (no \`timeout\` on PATH → untrusted build runs unbounded; CI runner has it)"; fi
LEAN_CMD=("${TIMEOUT_PREFIX[@]}" lean --root="$WORK" -o "$WORK/Submission.olean" "$WORK/Submission.lean")

# (b) FS-confine the build with landrun if present; otherwise run bare and log
# the residual-risk follow-on. Network-egress confinement is NOT provided by
# either path here — it is the documented follow-on. Trust is in the replay,
# not the build (see header).
if command -v landrun >/dev/null 2>&1; then
  md "- landrun present → FS-confined build (Landlock)."
  # Read: toolchain + deposit dir. Write: scratch out-dir only.
  landrun \
    --ro "${LEAN_SYSROOT:-$(lean --print-prefix 2>/dev/null)}" \
    --ro "$DEP_DIR" \
    --rw "$WORK" \
    -- "${LEAN_CMD[@]}" >"$BUILD_LOG" 2>&1
  BUILD_RC=$?
else
  md "- landrun NOT present → build runs BARE."
  md "  - Network-egress confinement is a documented FOLLOW-ON (landrun is the"
  md "    intended tool, Linux-only). The read-only PR token remains the primary"
  md "    isolation, and admission is decided by the trusted kernel REPLAY of the"
  md "    produced export, not by this build — a hostile build cannot forge"
  md "    admission, only misbehave within the (here weaker) sandbox."
  "${LEAN_CMD[@]}" >"$BUILD_LOG" 2>&1
  BUILD_RC=$?
fi

if [ "$BUILD_RC" -ne 0 ]; then
  md "- **reject** — submission.lean failed to build at \`$PIN\`:"
  md ""
  tail -n 40 "$BUILD_LOG" | embed_log >> "$REPORT"
  md ""
  emit_and_exit 2
fi
md "- build ok."

# ── 3. export the @decls closure with lean4export → candidate.export ─────────
# lean4export's argv convention (mirrors Manifest.freezeExportText):
#   lean4export <module> -- <decl1> <decl2> ...
# The module is the deposit @module (the form defaults it to `Submission`, the
# root name of submission.lean). We run it with the same LEAN_PATH the build
# used so the freshly-built Submission.olean is importable.
md ""
md "#### export (lean4export)"
EXPORT_LOG="$WORK/export.log"
# Make the just-built olean importable: prepend the scratch dir to LEAN_PATH.
export LEAN_PATH="$WORK${LEAN_PATH:+:$LEAN_PATH}"
# The build compiled the source as the fixed module `Submission` (see above);
# export that module's decl closure. @module is informational only. Decls are
# passed as a QUOTED array (no word-split/glob).
if ! "$LEAN4EXPORT_BIN" Submission -- "${DECLS_ARR[@]}" >"$CAND_EXPORT" 2>"$EXPORT_LOG"; then
  md "- **reject** — lean4export failed on module \`Submission\` (decls: $DECLS):"
  md ""
  tail -n 30 "$EXPORT_LOG" | embed_log >> "$REPORT"
  md ""
  emit_and_exit 2
fi
if [ ! -s "$CAND_EXPORT" ]; then
  md "- **reject** — lean4export produced an empty candidate export."
  emit_and_exit 2
fi
# lean4export can PANIC yet still exit 0 (fail-open) on some inputs, leaving a
# truncated/partial export. Two backstops make that fail-CLOSED: (1) reject now
# if it printed a panic/error to stderr; (2) the trusted gate exe REQUIRES every
# target decl to be present in the export ("target absent from candidate" →
# REJECTED), so a decl dropped from a partial export is caught at adjudication.
if grep -Eiq 'panic|internal error|stack overflow' "$EXPORT_LOG"; then
  md "- **reject** — lean4export reported a panic/error (regardless of exit code):"
  md ""
  tail -n 30 "$EXPORT_LOG" | embed_log >> "$REPORT"
  md ""
  emit_and_exit 2
fi
md "- exported \`$(wc -c <"$CAND_EXPORT" | tr -d ' ')\` bytes."

# ── 4. adjudicate ────────────────────────────────────────────────────────────
# With --reference: self-audit (replay+axioms+triviality) PLUS statement-
# identity against the frozen trusted R. The exe exits nonzero on a smuggle.
# Without: self-audit only.
md ""
md "#### adjudicate"
ADJ_OUT="$WORK/adj.json"
ADJ_ERR="$WORK/adj.err"

if [ -n "$REF_EXPORT" ]; then
  md "- mode: **discharge** (\`--reference\` statement-identity vs frozen R for \`$DISCHARGES\`)."
  "$ADJUDICATE_BIN" --reference "$REF_EXPORT" "$CAND_EXPORT" -- "${TARGET_DECLS_ARR[@]}" \
    >"$ADJ_OUT" 2>"$ADJ_ERR"
  ADJ_RC=$?
else
  md "- mode: **self-audit** (no \`@discharges\`; replay + axioms + triviality)."
  "$ADJUDICATE_BIN" "$CAND_EXPORT" -- "${TARGET_DECLS_ARR[@]}" \
    >"$ADJ_OUT" 2>"$ADJ_ERR"
  ADJ_RC=$?
fi

# The exe ALWAYS emits a complete JSON report on stdout, even when it exits
# nonzero (REJECTED). A nonzero exit with UNPARSEABLE stdout is a real crash.
if ! "$PY" -c 'import json,sys;json.load(open(sys.argv[1]))' "$ADJ_OUT" 2>/dev/null; then
  md "- **reject** — adjudicate exited $ADJ_RC with unparseable stdout (crash/panic):"
  md ""
  tail -n 30 "$ADJ_ERR" | embed_log >> "$REPORT"
  md ""
  emit_and_exit 2
fi

# Per-leg render from the JSON report. Fields (see MathesisAdjudicate.lean
# `main` schema): replay.accepted, targets[].{decl,axiom_audit,illegal_axiom,
# triviality,kind}, verdict. With --reference the exe adds a statement-identity
# leg and folds a smuggle into a nonzero exit + REJECTED verdict.
REPLAY_OK="$("$PY" -c 'import json,sys;d=json.load(open(sys.argv[1]));print(str((d.get("replay") or {}).get("accepted")).lower())' "$ADJ_OUT")"
VERDICT="$("$PY" -c 'import json,sys;d=json.load(open(sys.argv[1]));print(d.get("verdict") or "?")' "$ADJ_OUT")"

md ""
md "| leg | result |"
md "|---|---|"
md "| replay | $([ "$REPLAY_OK" = true ] && echo pass || echo **fail**) |"

# Per-target legs + triviality collection.
TRIVIAL_FLAGGED="$("$PY" - "$ADJ_OUT" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
trivial = []
rows = []
for t in (d.get("targets") or []):
    decl = t.get("decl", "?")
    audit = t.get("axiom_audit", "?")
    tier = t.get("kind", "?")
    illegal = t.get("illegal_axiom")
    triv = t.get("triviality")
    cell = "pass" if audit == "pass" else ("**fail** (illegal axiom `%s`)" % illegal if illegal else "**fail**")
    rows.append("| axioms `%s` (%s) | %s |" % (decl, tier, cell))
    if triv:
        trivial.append("%s: %s" % (decl, triv))
# Print table rows first, then a sentinel + the trivial list.
for r in rows:
    print(r)
print("@@TRIVIAL@@")
for x in trivial:
    print(x)
PY
)"
# Split rows from the trivial list on the sentinel.
ROWS="${TRIVIAL_FLAGGED%%@@TRIVIAL@@*}"
TRIVIALS="${TRIVIAL_FLAGGED#*@@TRIVIAL@@}"
printf '%s\n' "$ROWS" | sed '/^$/d' >> "$REPORT"

# Statement-identity leg is implicit in the exe's exit code under --reference:
# a smuggle → nonzero + REJECTED. Render it explicitly for the discharge case.
if [ -n "$REF_EXPORT" ]; then
  if [ "$ADJ_RC" -eq 0 ] && [ "$VERDICT" = "ADMITTED" ]; then
    md "| statement-identity | pass |"
  else
    md "| statement-identity | **fail** (smuggle or mismatch vs frozen R) |"
  fi
fi
md ""
md "- adjudicate verdict: **$VERDICT** (exit $ADJ_RC)"

# ── 5. decide exit code ──────────────────────────────────────────────────────
# The exe's exit code IS the mechanical gate (replay AND every axiom_audit AND,
# under --reference, statement-identity). Nonzero → reject.
if [ "$ADJ_RC" -ne 0 ]; then
  md ""
  md "- **verdict: reject** — a mechanical leg failed."
  emit_and_exit 2
fi

# Legs passed. Triviality is NOT a gate (a trivial theorem is kernel-valid) but
# routes to human review: a syntactically vacuous target may be mis-claimed.
TRIVIALS_CLEAN="$(printf '%s' "$TRIVIALS" | sed '/^$/d')"
if [ -n "$TRIVIALS_CLEAN" ]; then
  md ""
  md "- **verdict: needs-review** — mechanically clean, but a target is syntactically trivial (kernel-valid, possibly mis-claimed):"
  while IFS= read -r line; do
    [ -n "$line" ] && md "  - $line"
  done <<<"$TRIVIALS_CLEAN"
  md ""
  md "  A maintainer decides whether the claim matches the statement. CI does not block."
  emit_and_exit 0
fi

md ""
md "- **verdict: admit** — all legs passed, no triviality flag."
emit_and_exit 0
