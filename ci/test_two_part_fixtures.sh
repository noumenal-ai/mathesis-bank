#!/usr/bin/env bash
# ---------------------------------------------------------------------------------------------
# Two-part deposits through the REAL gate: real Lean, real lean4export, real adjudicator.
#
#   bash ci/test_two_part_fixtures.sh
#
# Needs `lean` (v4.31.0) on PATH and the two gate binaries. They default to where
# .github/workflows/deposit.yml builds them —
#   backend-gate/.lake/build/bin/mathesis-adjudicate                (lake build mathesis-adjudicate)
#   backend-gate/.lake/packages/lean4export/.lake/build/bin/lean4export
# — and MATHESIS_ADJUDICATE / MATHESIS_LEAN4EXPORT override them. Without them this SKIPS rather
# than fails: ci/test_two_part_format.sh covers everything that needs no toolchain.
#
# WHY REAL LEAN AND NOT STUBS
# ---------------------------
# ci/test_gate_reference.sh stubs the toolchain because what it tests is the gate's refusal
# logic. What is under test HERE is the soundness argument for two-part deposits (written out in
# ci/gate_deposit.sh at step 2s), and every link of it lives in a real artifact: that `sorry`
# elaborates to the exact shape statement_form.py accepts, that a sorry hidden from the lexer is
# still caught in the export, that a re-stated definition which differs by one numeral diverges
# in the adjudicator's statement-identity leg. A stub would only test that the stub agrees.
#
# The fixtures are ci/fixtures/two-part/<case>/submission.lean; each one's @gloss says what it
# is for. The build runs on whatever path the gate picks — MATHESIS_BUILDER_IMAGE if set,
# otherwise bare — and MATHESIS_INIT_EXPORT defaults to backend-gate/init.export, as in CI.
# ---------------------------------------------------------------------------------------------
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIX="$ROOT/ci/fixtures/two-part"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0

check() { # check <name> <cond-cmd...>
  local name="$1"; shift
  if "$@" >/dev/null 2>&1; then printf '  PASS  %s\n' "$name"; pass=$((pass+1))
  else printf '  FAIL  %s\n' "$name"; fail=$((fail+1)); fi
}

ADJ="${MATHESIS_ADJUDICATE:-$ROOT/backend-gate/.lake/build/bin/mathesis-adjudicate}"
L4E="${MATHESIS_LEAN4EXPORT:-$ROOT/backend-gate/.lake/packages/lean4export/.lake/build/bin/lean4export}"
INIT="${MATHESIS_INIT_EXPORT-$ROOT/backend-gate/init.export}"
for need in "$ADJ" "$L4E"; do
  [ -x "$need" ] || { echo "SKIPPED — $need not built (see this file's header)"; exit 0; }
done
command -v lean >/dev/null 2>&1 || { echo "SKIPPED — no \`lean\` on PATH"; exit 0; }

echo "two-part deposits through the real gate"
echo

run() { # run <case>: gate the fixture; report in $TMP/<case>.md, artifacts in $TMP/<case>.out
  mkdir -p "$TMP/$1.out"
  env MATHESIS_ADJUDICATE="$ADJ" MATHESIS_LEAN4EXPORT="$L4E" \
      MATHESIS_OUT_DIR="$TMP/$1.out" ${INIT:+MATHESIS_INIT_EXPORT="$INIT"} \
      bash "$ROOT/ci/gate_deposit.sh" "$FIX/$1" >"$TMP/$1.md" 2>"$TMP/$1.err"
  echo $?
}
has()  { grep -qF -- "$2" "$TMP/$1.md"; }        # has <case> <literal text in the report>
hasnt() { ! grep -qF -- "$2" "$TMP/$1.md"; }
sha_ok() { # the kept R is named by its own content
  local d="$TMP/$1.out"
  local got
  got="$( (sha256sum "$d/statement.export" 2>/dev/null || shasum -a 256 "$d/statement.export") | cut -d' ' -f1)"
  [ -s "$d/statement.export" ] && [ "$got" = "$(cat "$d/statement.sha256")" ]
}

# ---- admit: a statement, and a proof that proves it ------------------------------------------
RC="$(run admit)"
check "admit: exit 0"                                 test "$RC" = 0
check "admit: the statement passes its form check"    has admit "statement ok."
check "admit: both theorems are exactly sorry in R"   has admit '`Probe.rev_rev` proved by exactly `sorry` | pass'
check "admit: definitions are axiom-clean"            has admit "| definitions axiom-clean ("
check "admit: both parts are built"                   has admit "#### proof build (untrusted, isolated)"
check "admit: identity holds against its own R"       has admit "| statement-identity (proof vs statement R) | pass |"
check "admit: verdict admit"                          has admit "verdict: admit"
check "admit: keeps R under its sha256"               sha_ok admit
check "admit: keeps the candidate as before"          test -s "$TMP/admit.out/candidate.export"

# ---- smuggles: the proof part changes what the statement says --------------------------------
# The proof re-states `bound` as 1000 where the statement said 10. Everything else is clean —
# the proof is kernel-valid and axiom-free about ITS bound — so only identity can catch it.
RC="$(run smuggle-definition)"
check "smuggled definition: rejected (exit 2)"        test "$RC" = 2
check "  the statement itself was fine"               has smuggle-definition "statement ok."
check "  the proof's own axioms were clean"           has smuggle-definition '| axioms `Probe.bound_big` (theorem) | pass |'
check "  identity names the diverging definition"     has smuggle-definition "constant diverges between reference and candidate: 'Probe.bound'"
RC="$(run smuggle-statement)"
check "smuggled statement: rejected (exit 2)"         test "$RC" = 2
check "  identity names the changed theorem"          has smuggle-statement "target statement differs between reference and candidate: 'Probe.all_small'"

# ---- a proof that is sorry: identity holds, the axiom audit refuses --------------------------
RC="$(run proof-sorry)"
check "sorry proof: rejected (exit 2)"                test "$RC" = 2
check "  on sorryAx, in the candidate"                has proof-sorry '| axioms `Probe.hard` (theorem) | **fail** (illegal axiom `sorryAx`) |'
check "  while identity itself held"                  has proof-sorry "| statement-identity (proof vs statement R) | pass |"

# ---- statements that are not statements ------------------------------------------------------
# A plain `sorry` definition never reaches a build: the parser refuses it and names the line.
RC="$(run statement-sorry-definition)"
check "sorry definition: rejected (exit 2)"           test "$RC" = 2
check "  by the parser, naming the line"              has statement-sorry-definition 'on line 20 of the `@statement` section'
check "  before anything was built"                   hasnt statement-sorry-definition "build ok."
# `by stop exact 3` elaborates to sorry with no `sorry` in the source. The lexer passes it; the
# export does not: `threshold` is a root, and its audit over R reaches sorryAx.
RC="$(run statement-hidden-sorry)"
check "hidden sorry definition: rejected (exit 2)"    test "$RC" = 2
check "  the source check let it through"             has statement-hidden-sorry "#### statement form"
check "  the export check names the definition"       has statement-hidden-sorry '| definitions: axioms `Probe.threshold` (definition) | **fail** (illegal axiom `sorryAx`) |'
check "  and R is NOT kept for freezing"              test ! -e "$TMP/statement-hidden-sorry.out/statement.export"
# The converse: a theorem PROVED by something spelled `sorry` (a high-priority notation whose own
# spelling sits in a string the lexer blanks). Source says `:= sorry`; the export says
# `True.intro`, and statement_form.py reads the export.
RC="$(run statement-fake-sorry)"
check "fake sorry: rejected (exit 2)"                 test "$RC" = 2
check "  it built — the lexer saw \`:= sorry\`"        has statement-fake-sorry "build ok."
check "  the export check sees a proof"               has statement-fake-sorry "'Probe.easy': its proof is not \`sorry\`"

# ---- pose: a statement alone ------------------------------------------------------------------
RC="$(run pose)"
check "pose: exit 0"                                  test "$RC" = 0
check "pose: verdict posed"                           has pose "verdict: posed"
check "pose: nothing but the statement is built"      hasnt pose "#### proof build"
check "pose: keeps R under its sha256"                sha_ok pose
check "pose: and the report names that sha"           has pose "$(cat "$TMP/pose.out/statement.sha256" 2>/dev/null || echo MISSING)"
check "pose: produces no candidate"                   test ! -e "$TMP/pose.out/candidate.export"

# ---- a statement's R is a reference a later discharge can use ---------------------------------
# The point of keeping R: freeze it as a registry claim, and a deposit discharging that claim is
# checked against it by the unchanged @discharges path. Built here in a scratch registry, from
# the R the proof-sorry fixture's statement produced.
SHA="$(cat "$TMP/proof-sorry.out/statement.sha256" 2>/dev/null)"
mkdir -p "$TMP/reg/registry/claims/MTH.C-2026-0001" "$TMP/reg/exports" "$TMP/dep"
ln -s "$ROOT/ci" "$TMP/reg/ci"
cp "$TMP/proof-sorry.out/statement.export" "$TMP/reg/exports/$SHA.export" 2>/dev/null
printf '{"statement":{"decl_names":["Probe.hard"]},"frozen_export":{"sha256":"%s"}}\n' "$SHA" \
  > "$TMP/reg/registry/claims/MTH.C-2026-0001/manifest.json"
cat > "$TMP/dep/submission.lean" <<'EOF'
/-!
# Mathesis deposit

@kind: result
@title: discharging a claim whose R came from a two-part statement
@module: Submission
@decls: Probe.hard
@pin: leanprover/lean4:v4.31.0
@discharges: MTH.C-2026-0001

@gloss:
  g
-/

namespace Probe
theorem hard (n : Nat) : n + 0 = n := rfl
end Probe
EOF
env MATHESIS_ADJUDICATE="$ADJ" MATHESIS_LEAN4EXPORT="$L4E" ${INIT:+MATHESIS_INIT_EXPORT="$INIT"} \
    VERIFY_ROOT="$TMP/reg" MATHESIS_EXPORTS_DIR="$TMP/reg/exports" \
    bash "$ROOT/ci/gate_deposit.sh" "$TMP/dep" >"$TMP/disch.md" 2>&1
RC=$?
check "a statement's R serves as a discharge reference" test "$RC" = 0
check "  through the unchanged discharge mode"        grep -qF "mode: **discharge**" "$TMP/disch.md"

echo
echo "  $pass passed, $fail failed"
[ "$fail" -eq 0 ] || exit 1
