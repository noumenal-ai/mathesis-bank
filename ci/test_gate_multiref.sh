#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Mathesis — the gate adjudicates against EVERY trusted reference it is given.
#
#   bash ci/test_gate_multiref.sh
#
# A Mathlib deposit is checked against two references: `init.export` (the logical core and the
# kernel built-ins) and the pinned `mathlib.export` (the Mathlib vocabulary claims are stated in).
# Neither covers the other, so `gate_deposit.sh` takes MATHESIS_INIT_EXPORT as a `:`-separated
# list and runs the adjudicator once per entry. This asserts the contract that makes that sound:
#
#   * a reject under ANY one reference rejects the deposit, whichever position it is in;
#   * the rendered verdict is the rejecting run's, not an admitting one's;
#   * an empty entry, or one reference loading 0 constants, refuses rather than admits;
#   * a single reference (the Lean-core path) behaves exactly as before.
#
# No toolchain needed: `lean` and `lean4export` are stand-ins on PATH, and the adjudicator is a
# stand-in that rejects when the reference it is handed is named `*spoofed*` — standing for the
# reference that holds the genuine copy of a constant the candidate redefines.
# ---------------------------------------------------------------------------
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0

check() {  # check <name> <condition-cmd...>
  local name="$1"; shift
  if "$@" >/dev/null 2>&1; then
    printf '  PASS  %s\n' "$name"; pass=$((pass+1))
  else
    printf '  FAIL  %s\n' "$name"; fail=$((fail+1))
  fi
}

mkdir -p "$TMP/bin"
cat > "$TMP/bin/lean" <<'STUB'
#!/bin/sh
out=""
while [ $# -gt 0 ]; do case "$1" in -o) out="$2"; shift 2;; *) shift;; esac; done
[ -n "$out" ] && echo "stub olean" > "$out"
exit 0
STUB
cat > "$TMP/bin/lean4export" <<'STUB'
#!/bin/sh
echo '{"meta":{"exporter":{"name":"stub"}}}'
STUB
cat > "$TMP/fake-adjudicate" <<'FAKE'
#!/bin/sh
# Records which reference each run saw, then rejects under the one holding the genuine copy.
echo "${MATHESIS_INIT_EXPORT:-<unset>}" >> "$CALLS"
if [ -n "${MATHESIS_INIT_EXPORT:-}" ]; then
  if grep -q '^empty-load' "$MATHESIS_INIT_EXPORT"; then
    echo "trusted init.export loaded: 0 constants" >&2
  else
    echo "trusted init.export loaded: 42 constants" >&2
  fi
fi
case "${MATHESIS_INIT_EXPORT:-}" in
  *spoofed*)
    echo '{"verdict":"REJECTED","replay":{"accepted":true},"targets":[{"decl":"probe","axiom_audit":"fail","kind":"theorem","redefined_constant":"Real"}]}'
    exit 1 ;;
esac
echo '{"verdict":"ADMITTED","replay":{"accepted":true},"targets":[{"decl":"probe","axiom_audit":"pass","kind":"theorem"}]}'
exit 0
FAKE
chmod +x "$TMP/bin/lean" "$TMP/bin/lean4export" "$TMP/fake-adjudicate"

echo "stand-in reference" > "$TMP/init.export"
echo "stand-in reference" > "$TMP/mathlib.export"
echo "stand-in reference" > "$TMP/spoofed.export"
echo "empty-load" > "$TMP/hollow.export"

DEP="$TMP/deposits/probe"
mkdir -p "$DEP"
cat > "$DEP/submission.lean" <<'SUB'
/-!

@kind: result
@title: multi-reference probe
@module: Submission
@decls: probe
@pin: leanprover/lean4:v4.31.0

@gloss:
  A probe used by ci/test_gate_multiref.sh.
-/

theorem probe (n : Nat) : n = n := rfl
SUB

gate() {  # gate <name> <MATHESIS_INIT_EXPORT value or --unset>
  local name="$1" refs="$2"
  : > "$TMP/$name.calls"
  if [ "$refs" = "--unset" ]; then
    env -u MATHESIS_INIT_EXPORT -u MATHESIS_BUILDER_IMAGE -u MATHESIS_EXPORT_IMAGE \
      PATH="$TMP/bin:$PATH" CALLS="$TMP/$name.calls" \
      MATHESIS_ADJUDICATE="$TMP/fake-adjudicate" MATHESIS_LEAN4EXPORT="$TMP/bin/lean4export" \
      bash "$ROOT/ci/gate_deposit.sh" "$DEP" >"$TMP/$name.out" 2>&1
  else
    env -u MATHESIS_BUILDER_IMAGE -u MATHESIS_EXPORT_IMAGE \
      PATH="$TMP/bin:$PATH" CALLS="$TMP/$name.calls" MATHESIS_INIT_EXPORT="$refs" \
      MATHESIS_ADJUDICATE="$TMP/fake-adjudicate" MATHESIS_LEAN4EXPORT="$TMP/bin/lean4export" \
      bash "$ROOT/ci/gate_deposit.sh" "$DEP" >"$TMP/$name.out" 2>&1
  fi
  echo $? > "$TMP/$name.rc"
}
rc() { cat "$TMP/$1.rc"; }
calls() { wc -l < "$TMP/$1.calls" | tr -d ' '; }

echo "gate: every trusted reference must admit"
echo

gate single "$TMP/init.export"
check "one reference: admitted (exit 0)"                  test "$(rc single)" = 0
check "one reference: one adjudication"                   test "$(calls single)" = 1
check "one reference: no per-reference list rendered"     bash -c "! grep -q 'trusted references:' '$TMP/single.out'"

gate both "$TMP/init.export:$TMP/mathlib.export"
check "two admitting references: admitted (exit 0)"       test "$(rc both)" = 0
check "two admitting references: two adjudications"       test "$(calls both)" = 2
check "two admitting references: verdict admit"           grep -q 'verdict: admit' "$TMP/both.out"

gate second "$TMP/init.export:$TMP/spoofed.export"
check "reject under the SECOND reference: rejected (2)"   test "$(rc second)" = 2
check "  the rejecting run's verdict is rendered"         grep -q 'adjudicate verdict: \*\*REJECTED\*\*' "$TMP/second.out"
check "  the redefined constant is named"                 grep -q 'redefines `Real`' "$TMP/second.out"

gate first "$TMP/spoofed.export:$TMP/mathlib.export"
check "reject under the FIRST reference: rejected (2)"    test "$(rc first)" = 2
check "  a later admitting run does not overwrite it"     grep -q 'adjudicate verdict: \*\*REJECTED\*\*' "$TMP/first.out"

gate emptyentry "$TMP/init.export::$TMP/mathlib.export"
check "empty list entry: refused (2)"                     test "$(rc emptyentry)" = 2
check "  before any adjudication"                         test "$(calls emptyentry)" = 0

gate trailing "$TMP/init.export:"
check "trailing separator: refused (2)"                   test "$(rc trailing)" = 2

gate missing "$TMP/init.export:$TMP/nope.export"
check "missing reference file: refused (2)"               test "$(rc missing)" = 2

gate hollow "$TMP/init.export:$TMP/hollow.export"
check "a reference loading 0 constants: refused (2)"      test "$(rc hollow)" = 2
check "  and says so"                                     grep -q 'loaded \*\*0 constants\*\*' "$TMP/hollow.out"

gate unset --unset
check "unset: adjudicated once with no reference"         test "$(calls unset)" = 1
check "  the stand-in saw MATHESIS_INIT_EXPORT unset"     grep -qx '<unset>' "$TMP/unset.calls"

echo
echo "  $pass passed, $fail failed"
[ "$fail" -eq 0 ]
