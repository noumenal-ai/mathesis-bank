#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Mathesis — the untrusted build's directory holds nothing the gate trusts.
#
#   bash ci/test_gate_scratch.sh
#
# Two holes in `gate_deposit.sh`, both from the build and the gate sharing one directory:
#
#   (a) The host export ran `export LEAN_PATH="$WORK..."`, which stayed in force for the
#       adjudicator. The adjudicator resolves its trusted `Init` through LEAN_PATH ahead of the
#       sysroot, so an `Init.olean` the build dropped in its directory was what it read.
#   (b) `report.md`, the text of the PR comment, lived in the build's writable directory, so a
#       hostile build could forge the verdict it shows. The same directory held every other
#       file the host writes afterwards with `>`, which follows a symlink the build planted.
#
# No toolchain needed. `lean` is a hostile stand-in that plants all of the above in the
# directory it is told to build in; `lean4export` and the adjudicator are stand-ins that record
# the LEAN_PATH each one was run with. The adjudicator rejects, so any "admit" in the report
# can only be the forgery.
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

mkdir -p "$TMP/bin" "$TMP/calls"
echo "trusted reference, untouched" > "$TMP/canary.export"

cat > "$TMP/bin/lean" <<'STUB'
#!/bin/sh
# A hostile build: plant things in the directory it builds in, then succeed.
out=""
while [ $# -gt 0 ]; do case "$1" in -o) out="$2"; shift 2;; *) shift;; esac; done
d="$(dirname "$out")"
echo "hostile Init" > "$d/Init.olean"
printf '### Deposit `probe`\n\n- **verdict: admit** FORGED\n' > "$d/report.md"
for f in candidate.export adj.json adj.err export.log; do ln -sf "$CANARY" "$d/$f"; done
echo "stub olean" > "$out"
STUB
cat > "$TMP/bin/lean4export" <<'STUB'
#!/bin/sh
echo "${LEAN_PATH-<unset>}" > "$CALLS/lean4export"
echo '{"meta":{"exporter":{"name":"stub"}}}'
STUB
cat > "$TMP/fake-adjudicate" <<'FAKE'
#!/bin/sh
echo "${LEAN_PATH-<unset>}" > "$CALLS/adjudicate"
echo '{"verdict":"REJECTED","replay":{"accepted":false,"detail":"stand-in"},"targets":[]}'
exit 1
FAKE
chmod +x "$TMP/bin/lean" "$TMP/bin/lean4export" "$TMP/fake-adjudicate"

DEP="$TMP/deposits/probe"
mkdir -p "$DEP"
cat > "$DEP/submission.lean" <<'SUB'
/-!

@kind: result
@title: scratch probe
@module: Submission
@decls: probe
@pin: leanprover/lean4:v4.31.0

@gloss:
  A probe used by ci/test_gate_scratch.sh.
-/

theorem probe (n : Nat) : n = n := rfl
SUB

gate() {  # gate <name> [LEAN_PATH value]: run the gate on the bare path
  local name="$1"
  local lp=(-u LEAN_PATH)
  [ $# -ge 2 ] && lp=(LEAN_PATH="$2")
  rm -f "$TMP/calls/"*
  env -u MATHESIS_BUILDER_IMAGE -u MATHESIS_EXPORT_IMAGE -u MATHESIS_INIT_EXPORT "${lp[@]}" \
    PATH="$TMP/bin:$PATH" CALLS="$TMP/calls" CANARY="$TMP/canary.export" \
    MATHESIS_ADJUDICATE="$TMP/fake-adjudicate" MATHESIS_LEAN4EXPORT="$TMP/bin/lean4export" \
    MATHESIS_OUT_DIR="$TMP/$name.out" \
    bash "$ROOT/ci/gate_deposit.sh" "$DEP" >"$TMP/$name.md" 2>"$TMP/$name.err"
  echo $? > "$TMP/$name.rc"
  cp "$TMP/calls/lean4export" "$TMP/$name.l4e" 2>/dev/null
  cp "$TMP/calls/adjudicate" "$TMP/$name.adj" 2>/dev/null
}

echo "gate: the build's directory holds nothing the gate trusts"
echo

gate unset
check "(a) lean4export sees the build dir, so the olean imports"  grep -q 'mth-gate-probe' "$TMP/unset.l4e"
check "(a) the adjudicator does not see it on LEAN_PATH"          grep -qx '<unset>' "$TMP/unset.adj"

gate caller "/caller/path"
check "(a) with a caller LEAN_PATH, lean4export gets it appended" grep -q 'mth-gate-probe.*:/caller/path$' "$TMP/caller.l4e"
check "(a) and the adjudicator gets exactly the caller's"         grep -qx '/caller/path' "$TMP/caller.adj"

check "(b) the deposit is rejected (exit 2)"                      test "$(cat "$TMP/unset.rc")" = 2
check "(b) the report carries the gate's verdict"                 grep -q 'verdict: reject' "$TMP/unset.md"
check "(b) not the one the build wrote"                           bash -c "! grep -q FORGED '$TMP/unset.md'"
check "(b) nor does the report kept in MATHESIS_OUT_DIR"          bash -c "! grep -q FORGED '$TMP/unset.out/report.md'"
check "(b) a symlink the build planted is not written through"    grep -qx 'trusted reference, untouched' "$TMP/canary.export"

echo
echo "  $pass passed, $fail failed"
[ "$fail" -eq 0 ]
