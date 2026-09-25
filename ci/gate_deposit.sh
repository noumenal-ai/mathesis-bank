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
# A TWO-PART deposit (a `/-! @statement -/` section, then a `/-! @proof -/`
# section; see ci/parse_deposit.py) inserts, before step 2:
#   2s. build  the statement part under the same confinement, export it as the
#              reference R, check its form (ci/statement_form.py: every target a
#              theorem proved by exactly `sorry`), and have the adjudicator
#              replay R and audit every definition its statements name.
# and then runs steps 2–4 on the PROOF part, with `--reference R`. A POSED
# claim (`@statement` alone) stops after 2s with the verdict `posed`, keeping R
# in MATHESIS_OUT_DIR as statement.export + statement.sha256. The soundness
# argument is written out where 2s is, below.
#
# EXIT CODE CONTRACT (this is the gate; callers key on it, not on the markdown):
#   0  admit            — every leg passed, no triviality flag.
#   0  needs-review     — legs passed but a target is syntactically trivial
#                         (kernel-valid but possibly mis-claimed): a human
#                         merges, CI does not block. Exit 0 by design.
#   0  posed            — a claim posed without a proof: the statement builds,
#                         has the form of a statement, and R is kept. (A posed
#                         statement flagged trivial is needs-review, as above.)
#   2  reject          — a leg failed: header invalid, build failed, export
#                         failed, replay rejected, an illegal axiom, or (with
#                         --reference) a statement-identity smuggle; for a
#                         two-part deposit also a statement that is not in
#                         the form of one, or a proof whose statement differs
#                         from the deposit's own.
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

# `timeout` prefix builder. Neither lean4export nor mathesis-adjudicate was bounded before:
# lean4export parses an untrusted .olean and the adjudicator parses an untrusted .export, so a
# crafted input could hang either one indefinitely and wedge the job.
tmo() {  # tmo <seconds> -- builds a prefix array in TMO_PREFIX
  TMO_PREFIX=()
  if command -v timeout >/dev/null 2>&1; then TMO_PREFIX=(timeout "$1")
  elif command -v gtimeout >/dev/null 2>&1; then TMO_PREFIX=(gtimeout "$1")
  fi
}

WORK="$(mktemp -d "${TMPDIR:-/tmp}/mth-gate-$SLUG.XXXXXX")"
CAND_EXPORT="$WORK/candidate.export"
# A two-part deposit's statement export: the reference R its proof is checked against, and, for
# a posed claim, the only thing the gate produces. Outside every part's build directory.
STMT_EXPORT="$WORK/statement.export"
# The untrusted build gets a directory under $WORK and nothing else: $WORK/build for a single-part
# deposit, one per part for a two-part one (see build_part). Everything the gate itself writes and
# then trusts — the report that becomes the PR comment, the exports, the adjudicator's JSON, the
# logs — lives in $WORK, outside them. When a single-part build wrote into $WORK directly, a hostile
# build could rewrite report.md (forging the verdict text of the PR comment; the exit code was
# unaffected), or plant a symlink where the host would next write with `>`: `candidate.export`
# pointing at the checkout's `init.export` would have had the host overwrite the trusted reference
# with the candidate's own export.

# MATHESIS_OUT_DIR: where to KEEP the two artifacts a caller needs. Without it, the EXIT trap
# below deletes `candidate.export` — the blob that becomes the accession — and `adj.json`, the
# gate exe's structured report. The report is not optional: `admit` and `needs-review` are both
# exit code 0 (see the contract above), so a caller keying on `$?` cannot tell them apart, and
# the markdown is prose meant for a human rather than a machine.
OUT_DIR="${MATHESIS_OUT_DIR:-}"
if [ -n "$OUT_DIR" ]; then
  mkdir -p "$OUT_DIR" || { echo "FATAL: cannot create MATHESIS_OUT_DIR=$OUT_DIR" >&2; exit 2; }
fi

sha256_of() {  # sha256_of <file>: its hex sha256 on stdout
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | cut -d' ' -f1
  else
    shasum -a 256 "$1" | cut -d' ' -f1
  fi
}

keep_artifacts() {
  [ -n "$OUT_DIR" ] || return 0
  [ -s "$CAND_EXPORT" ] && cp "$CAND_EXPORT" "$OUT_DIR/candidate.export" 2>/dev/null
  [ -s "$WORK/adj.json" ] && cp "$WORK/adj.json" "$OUT_DIR/adj.json" 2>/dev/null
  [ -s "$REPORT" ] && cp "$REPORT" "$OUT_DIR/report.md" 2>/dev/null
  # Record the sha256 the caller must publish the blob under; content-addressing is the trust
  # boundary, so the name has to come from the content.
  if [ -s "$CAND_EXPORT" ]; then
    sha256_of "$CAND_EXPORT" > "$OUT_DIR/candidate.sha256"
  fi
  # A two-part or posed deposit's statement R, under the same rule. Kept only once the statement
  # has passed its form check: an export that failed it is not a claim anyone should freeze, and
  # leaving it in OUT_DIR would invite an ingestion step to do exactly that. The adjudicator's
  # report on R is kept either way, as adj.json is — it is the machine-readable reason.
  if [ -s "$STMT_EXPORT" ] && [ -n "${STMT_OK:-}" ]; then
    cp "$STMT_EXPORT" "$OUT_DIR/statement.export" 2>/dev/null
    sha256_of "$STMT_EXPORT" > "$OUT_DIR/statement.sha256"
  fi
  [ -s "$WORK/statement-adj.json" ] && cp "$WORK/statement-adj.json" "$OUT_DIR/statement-adj.json" 2>/dev/null
  return 0
}
trap 'keep_artifacts; rm -rf "$WORK"' EXIT

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
# single | two-part | pose (see parse_deposit.py). Empty from a parser that predates sections,
# which is read as single — the only mode such a parser could have validated.
MODE="$(jget mode)"
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
if [ "$MODE" = "two-part" ] || [ "$MODE" = "pose" ]; then
  # Line ranges, so a reviewer reading the PR diff can see which lines are the claim.
  PART_LINES="$("$PY" -c '
import json,sys
p = json.load(sys.stdin).get("parts") or {}
f = lambda k: ("%d-%d" % (p[k]["start"], p[k]["end"])) if p.get(k) else "none"
print("statement lines " + f("statement") + ", proof lines " + f("proof"))' <<<"$PARSED")"
  md "- **mode**: \`$MODE\` ($PART_LINES)"
fi
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

# ── the confined build and the export, as functions ──────────────────────────
# A two-part deposit is built TWICE — its statement, then its proof — and each
# build is exactly as untrusted as a single-part one. So the build and export
# are functions over a directory rather than two copies of this logic: a second
# copy is a second place for the confinement to drift, and the confinement is
# the part of this script that has already drifted once (see the uid note).
#
# Each part gets its OWN scratch directory, and it is the only thing its build
# can reach. That is load-bearing for two-part deposits: the statement's export
# R is written OUTSIDE both part directories, so the proof build — the second,
# and the one with a motive — cannot reach the reference it is about to be
# checked against, and rewrite it to agree with itself. (On the bare path
# nothing is confined and this does not hold; that path says so in the report.)
#
# A single-part deposit builds in $WORK/build, for the reason given where $WORK is made.

# build_part <dir> <log> <what>: build <dir>/Submission.lean → <dir>/Submission.olean,
# confined to <dir>. Rejects (exit 2) on failure, naming <what> as the thing that failed.
build_part() {
  local dir="$1" log="$2" what="$3"
  # `timeout` bounds a non-terminating / runaway elaboration of the UNTRUSTED
  # build (availability guard, independent of the read-only-token + replay trust
  # model). Overridable via MATHESIS_BUILD_TIMEOUT (seconds). `timeout` is
  # coreutils (present on the ubuntu-latest CI runner); portably fall back to
  # `gtimeout`, else run without a bound (and note it) so non-Linux hosts work.
  TIMEOUT_PREFIX=()
  if command -v timeout >/dev/null 2>&1; then TIMEOUT_PREFIX=(timeout "${MATHESIS_BUILD_TIMEOUT:-300}")
  elif command -v gtimeout >/dev/null 2>&1; then TIMEOUT_PREFIX=(gtimeout "${MATHESIS_BUILD_TIMEOUT:-300}")
  else md "- (no \`timeout\` on PATH → untrusted build runs unbounded; CI runner has it)"; fi
  LEAN_CMD=("${TIMEOUT_PREFIX[@]}" lean --root="$dir" -o "$dir/Submission.olean" "$dir/Submission.lean")

  # (b) FS-confine the build with landrun if present; otherwise run bare and log
  # the residual-risk follow-on. Network-egress confinement is NOT provided by
  # either path here — it is the documented follow-on. Trust is in the replay,
  # not the build (see header).
  # PREFERRED: a container with no network and one writable mount.
  #
  # This closes four gaps the landrun path never did, and the landrun path never ran anyway —
  # nothing installs it, so control always fell to the bare `else` below.
  #
  #   1. `--network none` is the egress denial named as a follow-on in three places.
  #   2. Only <dir> is writable and nothing else is mounted, so the CHECKOUT IS UNREACHABLE.
  #      That matters more than it sounds: the adjudicator binary, init.export, the exports dir
  #      and the claim manifest whose sha256 this script re-verifies all live in the checkout.
  #      A build that can rewrite them defeats the "trust is in the replay" argument entirely,
  #      because it can rewrite the replay.
  #   3. No inherited environment, so GH_TOKEN is no longer in scope during elaboration.
  #   4. cwd is /work, not the repo.
  #
  # A container still shares the host kernel, and Lean elaboration is arbitrary code execution,
  # so this shrinks the blast radius rather than closing it. Hardware isolation is the next phase.
  BUILDER_IMAGE="${MATHESIS_BUILDER_IMAGE:-}"
  if [ -n "$BUILDER_IMAGE" ] && command -v docker >/dev/null 2>&1; then
    md "- containerized build (\`--network none\`, scratch-only mount): \`$BUILDER_IMAGE\`."

    # The builder image runs as uid 10001 by design. `mktemp -d` makes $WORK 0700 owned by whoever
    # invoked this script, so on Linux uid 10001 cannot traverse it, cannot read Submission.lean,
    # and cannot write Submission.olean. The build then fails with
    #
    #     permission denied (error code: 4294967283)
    #       file: /work/Submission.lean
    #
    # which the block below reports as "reject — submission.lean failed to build": an
    # infrastructure fault recorded permanently against a depositor whose proof was fine. Every
    # Mathlib deposit would have hit it.
    #
    # This passed throughout development because Docker Desktop on macOS presents bind-mounted
    # files as owned by the container's user whatever the host says. On a Linux runner the uid
    # mapping is literal, so the bug only appears in the one place it matters. deposit-e2e.yml
    # exists to run this there, and found it on its first complete attempt.
    #
    # 0777 rather than a chown, which needs root on the host, or --user "$(id -u):$(id -g)", which
    # would discard the image's own unprivileged uid and its writable HOME. What is exposed is a
    # world-writable scratch directory for the duration of one build, holding the depositor's own
    # submission and an olean that is afterwards replayed through the trusted kernel — so tampering
    # with either buys nothing that writing the submission did not already buy.
    #
    # <dir> is always a subdirectory of $WORK, and $WORK itself stays 0700: the bind mount is
    # resolved on the host, so the container needs no way through the parent, and the report,
    # the exports and a sibling part's directory stay out of reach of anything else on the host.
    chmod 0777 "$dir"
    chmod 0644 "$dir/Submission.lean"

    docker run --rm \
      --network none \
      --read-only \
      --tmpfs /tmp \
      -v "$dir":/work \
      --memory "${MATHESIS_BUILD_MEMORY:-6g}" \
      --cpus "${MATHESIS_BUILD_CPUS:-2}" \
      --pids-limit "${MATHESIS_BUILD_PIDS:-512}" \
      -e HOME=/work \
      -w /work \
      "$BUILDER_IMAGE" \
      timeout "${MATHESIS_BUILD_TIMEOUT:-300}" \
        lean --root=/work -o /work/Submission.olean /work/Submission.lean \
      >"$log" 2>&1
    BUILD_RC=$?
  elif command -v landrun >/dev/null 2>&1; then
    md "- landrun present → FS-confined build (Landlock). NOTE: no egress confinement."
    # Read: toolchain + deposit dir. Write: this part's scratch dir only.
    landrun \
      --ro "${LEAN_SYSROOT:-$(lean --print-prefix 2>/dev/null)}" \
      --ro "$DEP_DIR" \
      --rw "$dir" \
      -- "${LEAN_CMD[@]}" >"$log" 2>&1
    BUILD_RC=$?
  else
    md "- **build runs BARE** — neither \`MATHESIS_BUILDER_IMAGE\` nor \`landrun\` is available."
    md "  - No egress confinement and no filesystem confinement. The untrusted build can reach"
    md "    the checkout, which holds the adjudicator binary and \`init.export\`, so the"
    md "    \"trust is in the replay\" argument does NOT hold on this path."
    md "  - Set \`MATHESIS_BUILDER_IMAGE\` to a Lean builder image to close that."
    "${LEAN_CMD[@]}" >"$log" 2>&1
    BUILD_RC=$?
  fi

  if [ "$BUILD_RC" -ne 0 ]; then
    md "- **reject** — $what failed to build at \`$PIN\`:"
    md ""
    tail -n 40 "$log" | embed_log >> "$REPORT"
    md ""
    emit_and_exit 2
  fi
  md "- build ok."
}

# export_part <dir> <out> <log> <label>: export the @decls closure of <dir>/Submission.olean to
# <out>. Rejects (exit 2) on failure; <label> prefixes the rejection ("" for a single part).
#
# lean4export's argv convention (mirrors Manifest.freezeExportText):
#   lean4export <module> -- <decl1> <decl2> ...
# The module is the deposit @module (the form defaults it to `Submission`, the
# root name of submission.lean). We run it with the same LEAN_PATH the build
# used so the freshly-built Submission.olean is importable.
export_part() {
  local dir="$1" out="$2" log="$3" label="$4" noun="candidate"
  [ -n "$label" ] && noun="statement"
  # The build compiled the source as the fixed module `Submission` (see above);
  # export that module's decl closure. @module is informational only. Decls are
  # passed as a QUOTED array (no word-split/glob).
  tmo "${MATHESIS_EXPORT_TIMEOUT:-900}"
  EXPORT_IMAGE="${MATHESIS_EXPORT_IMAGE:-}"
  if [ -n "$EXPORT_IMAGE" ] && command -v docker >/dev/null 2>&1; then
    # CONTAINERIZED EXPORT — required for any environment whose imports live in an image.
    #
    # Containerizing the build broke this step for Mathlib deposits: the build's LEAN_PATH moved
    # into the image, and the host has no Mathlib at all, so `lean4export Submission` here died
    # with "unknown module prefix 'Mathlib'" and every Mathlib deposit rejected at the export
    # step for a reason unrelated to its proof. Measured: build ok (4528-byte olean), export on
    # the host exit 1 / 0 bytes, export with the image's oleans exit 0 / 7350 bytes.
    #
    # Mounting the host's lean4export into the builder image is not a general fix — it is a
    # lake-built dynamic executable whose RPATH names the host's Lean sysroot, and ubuntu-latest
    # and debian bookworm do not share a glibc. So the binary comes from an image built on the
    # same base: $MATHESIS_EXPORT_IMAGE is the builder image plus lean4export.
    #
    # This is NOT a trust boundary. `candidate.export` is untrusted input either way — the
    # adjudicator replays it through the trusted kernel and requires every target to be present,
    # so a doctored export fails there, not here. Confinement bounds a hang and a fail-open
    # panic. (`importModules` does not re-run the deposit's `initialize` blocks: Lean requires
    # `enableInitializersExecution`, which lean4export does not opt into.)
    md "- containerized export (\`--network none\`, scratch mounted read-only): \`$EXPORT_IMAGE\`."
    # <dir> read-only: lean4export reads Submission.olean and writes only to stdout, which is
    # captured on the host. LEAN_PATH is assembled INSIDE the container so the image's own olean
    # path is used rather than a layout this script would have to hard-code.
    docker run --rm \
      --network none \
      --read-only \
      --tmpfs /tmp \
      -v "$dir":/work:ro \
      --memory "${MATHESIS_BUILD_MEMORY:-6g}" \
      --cpus "${MATHESIS_BUILD_CPUS:-2}" \
      --pids-limit "${MATHESIS_BUILD_PIDS:-512}" \
      -e HOME=/tmp \
      -w /tmp \
      --entrypoint sh "$EXPORT_IMAGE" -c '
        T="$1"; shift
        M="$1"; shift
        LEAN_PATH="/work${LEAN_PATH:+:$LEAN_PATH}"; export LEAN_PATH
        exec timeout "$T" lean4export "$M" -- "$@"
      ' sh "${MATHESIS_EXPORT_TIMEOUT:-900}" Submission "${DECLS_ARR[@]}" \
      >"$out" 2>"$log"
    EXPORT_RC=$?
  else
    # Host export: the toolchain resolves Init/Std/Lean on its own, which is why the Lean-core
    # path has always worked here. Prepend the scratch dir so the fresh Submission.olean is
    # importable.
    #
    # Scoped to this ONE command, not exported. It used to be `export`ed, and so leaked into
    # the adjudicator, which resolves its trusted `Init` through the same search path
    # (`Lean.initSearchPath` puts LEAN_PATH ahead of the sysroot). The scratch dir is written by
    # the untrusted build, so an `Init.olean` dropped there would have been what the adjudicator
    # bound the permitted axioms' types from. And a two-part deposit exports twice, so an
    # exported LEAN_PATH would also have stacked the statement's dir under the proof's.
    LEAN_PATH="$dir${LEAN_PATH:+:$LEAN_PATH}" \
      "${TMO_PREFIX[@]}" "$LEAN4EXPORT_BIN" Submission -- "${DECLS_ARR[@]}" \
      >"$out" 2>"$log"
    EXPORT_RC=$?
  fi
  if [ "$EXPORT_RC" -ne 0 ]; then
    md "- **reject** — ${label}lean4export failed on module \`Submission\` (decls: $DECLS):"
    md ""
    tail -n 30 "$log" | embed_log >> "$REPORT"
    md ""
    emit_and_exit 2
  fi
  if [ ! -s "$out" ]; then
    md "- **reject** — ${label}lean4export produced an empty ${noun} export."
    emit_and_exit 2
  fi
  # lean4export can PANIC yet still exit 0 (fail-open) on some inputs, leaving a
  # truncated/partial export. Two backstops make that fail-CLOSED: (1) reject now
  # if it printed a panic/error to stderr; (2) the trusted gate exe REQUIRES every
  # target decl to be present in the export ("target absent from candidate" →
  # REJECTED), so a decl dropped from a partial export is caught at adjudication.
  if grep -Eiq 'panic|internal error|stack overflow' "$log"; then
    md "- **reject** — ${label}lean4export reported a panic/error (regardless of exit code):"
    md ""
    tail -n 30 "$log" | embed_log >> "$REPORT"
    md ""
    emit_and_exit 2
  fi
  md "- exported \`$(wc -c <"$out" | tr -d ' ')\` bytes."
}

# TRUSTED_REFS: MATHESIS_INIT_EXPORT may name SEVERAL trusted references, separated by `:`. Each
# is a separate adjudication (see run_adjudicate), and every one must admit.
#
# A Mathlib deposit needs two. `init.export` holds the logical core and the kernel built-ins
# (`Nat.gcd`, `Lean.reduceBool`, ...), which the kernel computes with by name whatever a
# candidate's declaration of them says. `mathlib.export` holds the curated Mathlib vocabulary a
# claim is stated in (`Real`, `Set`, `mul_one`, ...). Neither covers the other. Measured on the
# pinned pair, init.export's constants that the Mathlib reference lacks:
#
#     Lean.reduceBool  Lean.reduceNat  Lean.trustCompiler  Nat.lor  Nat.shiftLeft
#     Nat.shiftLeft._f  Nat.xor  (and the anchor Mathesis.trustAnchor)
#
# so `mathlib.export` alone rejects every honest deposit whose built-in closure reaches `Nat.xor`
# ("... which the trusted init.export does not hold"), and `init.export` alone admits a deposit
# that ships its own `Real`. Merging them into one file is not an option either: lean4export
# numbers its name and expression tables per file, so two exports do not concatenate, and a
# regenerated union would be a new pinned artifact rather than the two already recorded.
#
# Running the adjudicator once per reference keeps both artifacts exactly as pinned. It costs one
# extra replay, which is small next to the build. An empty list is the old single, unset case.
TRUSTED_REFS=()
if [ -n "${MATHESIS_INIT_EXPORT:-}" ]; then
  IFS=':' read -r -a TRUSTED_REFS <<<"$MATHESIS_INIT_EXPORT"
fi

# require_live_reference: refuse before adjudicating if MATHESIS_INIT_EXPORT is set but empty,
# or names an entry that is.
#
# A CONFIGURED reference that loads to nothing silently disables the redefinition check, and
# the deposit is then ADMITTED. Measured against the real adjudicator with the same spoofing
# candidate (a deposit defining its own `Real := Unit` and proving "every two reals are equal"):
#
#   MATHESIS_INIT_EXPORT=mathlib.export  -> "loaded: 12683 constants"  exit 1  REJECTED
#   MATHESIS_INIT_EXPORT=<empty file>    -> "loaded: 0 constants"      exit 0  ADMITTED
#   MATHESIS_INIT_EXPORT=<garbage>       -> loader throws              exit 1  (fails closed)
#   MATHESIS_INIT_EXPORT unset           -> check DISABLED             exit 0  ADMITTED
#
# Unset is documented and deliberate. Garbage fails closed on its own. The dangerous case is the
# middle one: a zero-byte or truncated file looks configured, announces "0 constants", and
# admits the spoof — reachable from an interrupted download, a half-written upload, or a fetch
# that left an empty file behind. `ci/run_deposit_job.sh` already refuses an empty or
# hash-mismatched reference, but the gate must not depend on its caller for that. With a list,
# an empty ENTRY (`a::b`, a leading or trailing `:`) is the same hazard and is refused the same
# way. `read -a` drops a trailing empty field, so the list's shape is checked as well as its
# entries.
require_live_reference() {
  [ -n "${MATHESIS_INIT_EXPORT:-}" ] || return 0
  local ref bad=""
  case "$MATHESIS_INIT_EXPORT" in
    :*|*:|*::*) bad="<empty entry>" ;;
  esac
  if [ -z "$bad" ]; then
    for ref in "${TRUSTED_REFS[@]}"; do
      if [ -z "$ref" ]; then bad="<empty entry>"; break; fi
      if [ ! -s "$ref" ]; then bad="$ref"; break; fi
    done
  fi
  if [ -n "$bad" ]; then
    md "- **reject** — \`MATHESIS_INIT_EXPORT\` is set but empty or missing:"
    md "  \`$bad\`"
    md "  An empty reference loads as 0 constants and silently disables the"
    md "  trusted-redefinition check, so refusing is the only safe reading."
    emit_and_exit 2
  fi
}

# run_adjudicate <out.json> <err> [--reference <R>] <export> -- <decl> ...
#
# EVERY call to the trusted exe goes through here, so there is one place that decides how it is
# bounded and which trusted references it runs against. It runs the exe once per entry of
# TRUSTED_REFS (once with MATHESIS_INIT_EXPORT unset when there are none), each run with
# MATHESIS_INIT_EXPORT set to that one entry. It then sets:
#
#   ADJ_RC       the deciding run's exit code: the first nonzero one, else the first run's (0);
#   <out>/<err>  copies of the deciding run's report and stderr, which is what gets rendered;
#   ADJ_RUNS     every run's report, in reference order (<out> minus .json, then .<i>.json);
#   ADJ_RCS      every run's exit code, in the same order.
#
# Callers differ in what they key on, and a change here must keep both working: step 4 keys on
# ADJ_RC (0 iff every run ADMITTED); the statement audit of a two-part deposit expects every
# run to exit 1 — every statement theorem reaches sorryAx by construction — and keys on the
# per-target JSON instead (see `statement_form.py --audit`), so it audits each of ADJ_RUNS.
run_adjudicate() {
  local out="$1" err="$2"; shift 2
  local refs=("${TRUSTED_REFS[@]}") ref i=0 o e rc sel=0
  [ "${#refs[@]}" -gt 0 ] || refs=("")
  ADJ_RUNS=(); ADJ_RCS=(); ADJ_RC=0
  for ref in "${refs[@]}"; do
    i=$((i+1))
    o="${out%.json}.$i.json"; e="$err.$i"
    tmo "${MATHESIS_ADJUDICATE_TIMEOUT:-1800}"
    if [ -n "$ref" ]; then
      MATHESIS_INIT_EXPORT="$ref" "${TMO_PREFIX[@]}" "$ADJUDICATE_BIN" "$@" >"$o" 2>"$e"
    else
      env -u MATHESIS_INIT_EXPORT "${TMO_PREFIX[@]}" "$ADJUDICATE_BIN" "$@" >"$o" 2>"$e"
    fi
    rc=$?

    # Non-empty is necessary but not sufficient: a well-formed file whose records the loader
    # skips would also yield an empty trusted environment. The exe reports what it actually
    # loaded ("trusted init.export loaded: N constants"), so key on that rather than on the
    # file. This is the check that would have caught the measured ADMIT above regardless of
    # cause.
    if [ -n "$ref" ] && grep -q "loaded: 0 constants" "$e" 2>/dev/null; then
      md "- **reject** — the trusted reference loaded **0 constants**:"
      md "  \`$ref\`"
      md "  The redefinition check was therefore inactive, and a deposit redefining a"
      md "  reference constant would have been admitted. Refusing rather than trusting"
      md "  this verdict."
      md ""
      tail -n 10 "$e" | embed_log >> "$REPORT"
      emit_and_exit 2
    fi

    # The exe ALWAYS emits a complete JSON report on stdout, even when it exits
    # nonzero (REJECTED). A nonzero exit with UNPARSEABLE stdout is a real crash.
    if ! "$PY" -c 'import json,sys;json.load(open(sys.argv[1]))' "$o" 2>/dev/null; then
      md "- **reject** — adjudicate exited $rc with unparseable stdout (crash/panic):"
      [ "${#refs[@]}" -gt 1 ] && md "  (trusted reference \`$(basename "$ref")\`)"
      md ""
      tail -n 30 "$e" | embed_log >> "$REPORT"
      md ""
      emit_and_exit 2
    fi

    ADJ_RUNS+=("$o"); ADJ_RCS+=("$rc")
    # The first run that fails is the one rendered, because it is the one that decides; when
    # every run admits, the first (primary) run is rendered. Legs other than the redefinition
    # check do not depend on the reference, so which admitting run is shown does not change
    # the report.
    if [ "$sel" -eq 0 ] || { [ "$rc" -ne 0 ] && [ "$ADJ_RC" -eq 0 ]; }; then
      sel="$i"; ADJ_RC="$rc"
    fi
  done
  cp "${out%.json}.$sel.json" "$out"
  cp "$err.$sel" "$err"
}

# ── 2s. a two-part deposit's STATEMENT: build, export as R, check its form ───
# Everything a two-part (or posed) deposit adds happens here, before the build
# a single-part deposit starts at. The statement is built and exported exactly
# like a submission — same confinement, same exporter — and its export is R.
#
# THE SOUNDNESS ARGUMENT, in the order the gate establishes it:
#   1. R is the statement the depositor wrote. It is the export of the statement
#      part alone, built before the proof part exists anywhere on disk, and the
#      proof build cannot reach it (see the functions above).
#   2. R has the form of a statement. Its targets are theorems proved by exactly
#      `sorry` (statement_form.py, on the export), and every constant their
#      types name passes the trusted axiom audit — so every definition the claim
#      is ABOUT is sorry-free, uses permitted axioms only, and redefines nothing
#      trusted. R itself replays in the trusted kernel.
#   3. The proof proves R. It is adjudicated with `--reference R`, and the
#      statement-identity leg requires each target's type, and every constant
#      that type reaches — definition bodies, inductives, instances — to be
#      IDENTICAL in R and in the proof's export. The proof part re-states the
#      definitions (it cannot import the statement: see parse_deposit.py), and
#      that re-statement is exactly what this leg checks: an edited definition
#      is a different constant, and the deposit is rejected as a smuggle.
#   4. The proof is a proof. The same run replays the candidate in the trusted
#      kernel and audits every target's FULL closure, proof included, for
#      permitted axioms — a `sorry` left in the proof is sorryAx, and fails.
# Both parts are built as the module `Submission`, so names Lean derives from the
# module (`private` declarations) come out the same in R and in the candidate.
BUILD_DIR="$WORK/build"
SUBMISSION_LABEL="submission.lean"
# A mode this script does not know would otherwise fall through to the single-part path and
# build the WHOLE file — both sections at once — as though it had no sections at all.
case "$MODE" in
  ""|single|two-part|pose) ;;
  *) md "- **reject** — unknown deposit mode \`${MODE//\`/}\` from the parser; refusing to guess."
     emit_and_exit 2 ;;
esac
if [ "$MODE" = "two-part" ] || [ "$MODE" = "pose" ]; then
  # parse_deposit.py already refused @discharges together with a statement; re-check it here,
  # fail-closed, for the same reason the handle grammar is re-checked above: this script must be
  # safe even under a different parser. Two references and no rule to prefer one is not a state
  # to adjudicate in.
  if [ -n "$DISCHARGES" ]; then
    md "- **reject** — \`@discharges\` and a \`@statement\` section together: the statement of a"
    md "  registry claim is the registry's, so a discharging deposit carries none of its own."
    emit_and_exit 2
  fi

  md ""
  md "#### statement build (untrusted, isolated)"
  STMT_DIR="$WORK/statement"
  mkdir "$STMT_DIR" || { md "- **reject** — cannot create the statement's scratch dir."; emit_and_exit 2; }
  if ! "$PY" "$ROOT/ci/parse_deposit.py" --part statement "$SUBMISSION" \
       >"$STMT_DIR/Submission.lean" 2>"$WORK/parse.err"; then
    md "- **reject** — could not cut the statement part out of submission.lean:"
    md ""
    embed_log < "$WORK/parse.err" >> "$REPORT"
    md ""
    emit_and_exit 2
  fi
  build_part "$STMT_DIR" "$WORK/statement-build.log" "the statement part of submission.lean"

  md ""
  md "#### statement export (reference R)"
  export_part "$STMT_DIR" "$STMT_EXPORT" "$WORK/statement-export.log" "statement part: "

  md ""
  md "#### statement form"
  # Source-level form was checked by the parser before anything was built; this is the same
  # property on the export (the authority), and it yields the ROOTS: the constants the targets'
  # types name, whose audit below is the check that the statement's definitions are clean.
  if ! "$PY" "$ROOT/ci/statement_form.py" "$STMT_EXPORT" "${DECLS_ARR[@]}" \
       >"$WORK/statement-roots" 2>"$WORK/statement-form.err"; then
    md "- **reject** — the statement is not in the form of a statement:"
    md ""
    embed_log < "$WORK/statement-form.err" >> "$REPORT"
    md ""
    emit_and_exit 2
  fi
  ROOTS_ARR=()
  while IFS= read -r __r; do [ -n "$__r" ] && ROOTS_ARR+=("$__r"); done < "$WORK/statement-roots"

  # One trusted run over R: the targets AND the roots. It replays R through the kernel, audits
  # each root's full closure, and — because every target's proof is sorry — reports each target
  # as failing on sorryAx, which is expected and which `--audit` insists is the ONLY failure.
  #
  # With several trusted references there is one run, and so one report, per reference, and
  # each is audited: a definition that is clean against `init.export` but redefines a Mathlib
  # constant is caught only by the `mathlib.export` run. The audit rendered is the first one
  # that is not clean, else the first.
  require_live_reference
  run_adjudicate "$WORK/statement-adj.json" "$WORK/statement-adj.err" \
    "$STMT_EXPORT" -- "${DECLS_ARR[@]}" "${ROOTS_ARR[@]}"
  __shown=""
  __i=0
  for __run in "${ADJ_RUNS[@]}"; do
    __i=$((__i+1))
    if ! "$PY" "$ROOT/ci/statement_form.py" --audit "$__run" \
         "${#DECLS_ARR[@]}" "${DECLS_ARR[@]}" "${ROOTS_ARR[@]}" \
         >"$WORK/statement-audit.$__i" 2>"$WORK/statement-audit.err"; then
      md "- **reject** — could not read the adjudicator's report on the statement:"
      md ""
      embed_log < "$WORK/statement-audit.err" >> "$REPORT"
      md ""
      emit_and_exit 2
    fi
    if [ -z "$__shown" ] || { ! grep -qx 'VERDICT ok' "$WORK/statement-audit.$__i" \
                              && grep -qx 'VERDICT ok' "$WORK/statement-audit.$__shown"; }; then
      __shown="$__i"
    fi
  done
  cp "$WORK/statement-audit.$__shown" "$WORK/statement-audit"
  md ""
  md "| statement leg | result |"
  md "|---|---|"
  sed -n 's/^ROW //p' "$WORK/statement-audit" >> "$REPORT"
  md ""
  if ! grep -qx 'VERDICT ok' "$WORK/statement-audit"; then
    md "- **verdict: reject** — the statement is not a clean statement: a definition it depends"
    md "  on is not axiom-clean, a theorem in it is not proved by exactly \`sorry\`, or R did not"
    md "  replay."
    emit_and_exit 2
  fi
  STMT_OK=1
  STMT_SHA="$(sha256_of "$STMT_EXPORT")"
  md "- statement ok. Reference R: \`$STMT_SHA\`."

  if [ "$MODE" = "pose" ]; then
    # A posed claim stops here: there is no proof to adjudicate. R is what a later deposit
    # proving this claim will be checked against, so it is kept (MATHESIS_OUT_DIR) under its
    # content address for the ingestion step to freeze.
    STMT_TRIVIALS="$(sed -n 's/^TRIVIAL //p' "$WORK/statement-audit")"
    md ""
    if [ -n "$STMT_TRIVIALS" ]; then
      md "- **verdict: needs-review** — posed, but a target is syntactically trivial (possibly mis-stated):"
      while IFS= read -r line; do
        [ -n "$line" ] && md "  - $line"
      done <<<"$STMT_TRIVIALS"
      md ""
      md "  A maintainer decides whether the claim says what its title says. CI does not block."
      emit_and_exit 0
    fi
    md "- **verdict: posed** — the claim is well-formed; its statement export is R (\`$STMT_SHA\`)."
    emit_and_exit 0
  fi

  # Two-part: the proof builds in a directory of its own, which does not contain R.
  BUILD_DIR="$WORK/proof"
  mkdir "$BUILD_DIR" || { md "- **reject** — cannot create the proof's scratch dir."; emit_and_exit 2; }
  if ! "$PY" "$ROOT/ci/parse_deposit.py" --part proof "$SUBMISSION" \
       >"$BUILD_DIR/Submission.lean" 2>"$WORK/parse.err"; then
    md "- **reject** — could not cut the proof part out of submission.lean:"
    md ""
    embed_log < "$WORK/parse.err" >> "$REPORT"
    md ""
    emit_and_exit 2
  fi
  SUBMISSION_LABEL="the proof part of submission.lean"
  REF_EXPORT="$STMT_EXPORT"
  TARGET_DECLS_ARR=("${DECLS_ARR[@]}")
fi

# ── 2. build submission.lean UNDER ISOLATION at the pinned toolchain ─────────
# Pin the toolchain for the untrusted build to exactly the deposit @pin (which
# parse_deposit already forced == leanprover/lean4:v4.31.0). We use the same
# LEAN_SYSROOT the gate exe uses so `lean` resolves without a project toolchain.
md ""
if [ "$MODE" = "two-part" ]; then
  md "#### proof build (untrusted, isolated)"
else
  md "#### build (untrusted, isolated)"
fi
BUILD_LOG="$WORK/build.log"

# Copy the untrusted source into the build dir under a FIXED module name
# (Submission) so: (a) `lean --root=$BUILD_DIR` treats the build dir as the module
# root — the source need not live inside any lake package, and lean will not
# reject it as "not contained in root directory"; and (b) the exported module
# name is deterministic regardless of the deposit @module (which is untrusted
# and could carry path separators). The deposit's decls are root-namespaced
# inside this module, so a fixed module name is sound. (A two-part deposit's
# proof part was already written to its own dir above.)
if [ "$MODE" != "two-part" ]; then
  mkdir "$BUILD_DIR" || { md "- **reject** — cannot create the build's scratch dir."; emit_and_exit 2; }
  cp "$SUBMISSION" "$BUILD_DIR/Submission.lean"
fi
build_part "$BUILD_DIR" "$BUILD_LOG" "$SUBMISSION_LABEL"

# ── 3. export the @decls closure with lean4export → candidate.export ─────────
md ""
if [ "$MODE" = "two-part" ]; then
  md "#### proof export (lean4export)"
else
  md "#### export (lean4export)"
fi
export_part "$BUILD_DIR" "$CAND_EXPORT" "$WORK/export.log" ""

# ── 4. adjudicate ────────────────────────────────────────────────────────────
# With --reference: self-audit (replay+axioms+triviality) PLUS statement-
# identity against the frozen trusted R. The exe exits nonzero on a smuggle.
# Without: self-audit only.
md ""
md "#### adjudicate"
ADJ_OUT="$WORK/adj.json"
ADJ_ERR="$WORK/adj.err"

# The empty-reference refusal (see require_live_reference) comes before the mode line, as it
# always has, so a refused run's report reads exactly as it did before the helpers existed.
require_live_reference

if [ "$MODE" = "two-part" ]; then
  md "- mode: **two-part** (\`--reference\` statement-identity vs this deposit's own statement R)."
  run_adjudicate "$ADJ_OUT" "$ADJ_ERR" --reference "$REF_EXPORT" "$CAND_EXPORT" -- "${TARGET_DECLS_ARR[@]}"
elif [ -n "$REF_EXPORT" ]; then
  md "- mode: **discharge** (\`--reference\` statement-identity vs frozen R for \`$DISCHARGES\`)."
  run_adjudicate "$ADJ_OUT" "$ADJ_ERR" --reference "$REF_EXPORT" "$CAND_EXPORT" -- "${TARGET_DECLS_ARR[@]}"
else
  md "- mode: **self-audit** (no \`@discharges\`; replay + axioms + triviality)."
  run_adjudicate "$ADJ_OUT" "$ADJ_ERR" "$CAND_EXPORT" -- "${TARGET_DECLS_ARR[@]}"
fi
if [ "${#TRUSTED_REFS[@]}" -gt 1 ]; then
  md "- trusted references: ${#TRUSTED_REFS[@]}, each adjudicated separately; all must admit."
  for __i in "${!ADJ_RUNS[@]}"; do
    __v="$("$PY" -c 'import json,sys;print(json.load(open(sys.argv[1])).get("verdict") or "?")' "${ADJ_RUNS[$__i]}")"
    md "  - \`$(basename "${TRUSTED_REFS[$__i]}")\`: $__v (exit ${ADJ_RCS[$__i]})"
  done
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
redefs = []
for t in (d.get("targets") or []):
    decl = t.get("decl", "?")
    audit = t.get("axiom_audit", "?")
    tier = t.get("kind", "?")
    illegal = t.get("illegal_axiom")
    triv = t.get("triviality")
    # NOTE: no APOSTROPHES anywhere in this heredoc, comments included. It is a quoted heredoc
    # inside a $(...), where bash mis-parses a lone single-quote as opening a quote and fails
    # with "unexpected EOF while looking for matching" — pointing at a line far below, which
    # makes it a slow thing to diagnose. Backticks are fine.
    #
    # A redefinition is the OTHER way the axiom leg fails, and it used to render as a bare
    # "**fail**": the exe knew which constant diverged and the report dropped it, so a
    # depositor who collided with `Set` or `mul_one` had nothing to act on. `failure` is the
    # raw text, rendered when neither structured field recognises the shape, so no failure
    # mode is silently blank again.
    redef = t.get("redefined_constant")
    failure = t.get("failure")

    def clean(s, n=160):
        # These come from the candidate export, i.e. from the depositor. Lean permits
        # «quoted» identifiers containing almost anything, so strip what would break out of
        # an inline code span or forge a report row — same reasoning as the @title handling.
        #
        # chr(96) rather than a literal backtick: a LONE backtick on a line of this heredoc is
        # read by the enclosing $(...) as opening a command substitution, so every line here
        # must carry an even number of them. Writing it as a character code sidesteps that
        # entirely rather than relying on someone keeping the count even.
        s = " ".join(str(s).split())
        return s.replace(chr(96), "").replace("|", "")[:n]

    if audit == "pass":
        cell = "pass"
    elif illegal:
        cell = "**fail** (illegal axiom `%s`)" % clean(illegal)
    elif redef:
        cell = ("**fail** (redefines `%s`, which the trusted reference defines differently)"
                % clean(redef))
        redefs.append(clean(redef))
    elif failure:
        cell = "**fail** (%s)" % clean(failure)
    else:
        cell = "**fail**"
    rows.append("| axioms `%s` (%s) | %s |" % (decl, tier, cell))
    if triv:
        trivial.append("%s: %s" % (decl, triv))
# Print table rows first, then a sentinel + the trivial list, then the redefinitions.
for r in rows:
    print(r)
print("@@TRIVIAL@@")
for x in trivial:
    print(x)
print("@@REDEF@@")
for x in sorted(set(redefs)):
    print(x)
PY
)"
# Split rows from the trivial list and the redefinition list on the sentinels.
ROWS="${TRIVIAL_FLAGGED%%@@TRIVIAL@@*}"
REST="${TRIVIAL_FLAGGED#*@@TRIVIAL@@}"
TRIVIALS="${REST%%@@REDEF@@*}"
REDEFS="$(printf '%s' "${REST#*@@REDEF@@}" | sed '/^$/d')"
printf '%s\n' "$ROWS" | sed '/^$/d' >> "$REPORT"

# Name the collision and say what to do about it. A redefinition rejection is otherwise the
# most opaque verdict the gate produces: the proof is valid, the axioms are clean, and the
# deposit is refused for a reason that lives in a 12,683-constant reference the depositor
# cannot see.
if [ -n "$REDEFS" ]; then
  md ""
  md "- **redefines a constant the trusted reference already defines**, so the deposit could"
  md "  state something true only of its own version of a name the bank means something"
  md "  specific by:"
  printf '%s\n' "$REDEFS" | while IFS= read -r rd; do
    [ -n "$rd" ] && md "  - \`$rd\`"
  done
  md ""
  md "  Put the declaration in your own namespace, or rename it. A deposit defining"
  md "  \`Probe.Real\` rather than \`Real\` is admitted: the check is on the fully-qualified"
  md "  name, so namespacing is enough."
fi

# Statement-identity leg is implicit in the exe's exit code under --reference:
# a smuggle → nonzero + REJECTED. Render it explicitly for the discharge case.
#
# A two-part deposit reads the leg itself rather than inferring it from the verdict, and names
# what diverged. Here the depositor wrote BOTH sides, so "mismatch" is always their own edit —
# a definition re-stated differently in the proof, or a theorem's statement changed — and the
# exe's reason (`constant diverges between reference and candidate: 'double'`) says which.
if [ "$MODE" = "two-part" ]; then
  SI="$("$PY" -c '
import json,sys
v = json.load(open(sys.argv[1])).get("statement_identity")
v = " ".join(str(v).split()).replace(chr(96), "").replace("|", "")[:200]
print(v)' "$ADJ_OUT")"
  if [ "$SI" = "pass" ]; then
    md "| statement-identity (proof vs statement R) | pass |"
  else
    md "| statement-identity (proof vs statement R) | **fail** ($SI) |"
  fi
elif [ -n "$REF_EXPORT" ]; then
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
