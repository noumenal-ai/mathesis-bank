#!/usr/bin/env bash
# The differential test of step 1f: decode32, compiled (`lake exe decodecheck`), against the C
# oracle in oracle.c, which shares no logic with it.
#
#   bash tests/diff/run.sh                case classes (a), (b) and (c); see cases.py
#   bash tests/diff/run.sh --all          also every one of the 2^32 words, streamed: nothing is written
#   bash tests/diff/run.sh --range LO HI  only the words LO <= w < HI, so a sweep can run in slices
#
# Prints the words and mismatches per class, with the first mismatching lines if there are any, and
# exits nonzero on any mismatch.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

cc -O2 -ffp-contract=off -fno-fast-math "$here/oracle.c" -lm -o "$work/oracle"
(cd "$root" && lake build decodecheck >/dev/null)
decodecheck="$root/.lake/build/bin/decodecheck"
# sweep LO HI: compare the two programs on every word in [LO, HI), streamed through cmp. Two empty
# outputs compare equal, so a range passes only if the oracle also produced HI - LO lines.
sweep() {
  local lo=$1 hi=$2 count="$work/count.$1"
  if cmp <("$work/oracle" --range "$lo" "$hi" | tee >(wc -l | tr -d ' ' > "$count")) \
         <("$decodecheck" --range "$lo" "$hi"); then
    while [ ! -s "$count" ]; do sleep 0.2; done
    if [ "$(cat "$count")" -eq $((hi - lo)) ]; then
      echo "words [$lo, $hi): $((hi - lo)) compared, 0 mismatches"
      return 0
    fi
    echo "words [$lo, $hi): expected $((hi - lo)) lines, got $(cat "$count")"
  else
    echo "words [$lo, $hi): mismatch"
  fi
  return 1
}

if [ "${1:-}" = "--range" ]; then
  sweep "$2" "$3"
  exit
fi

python3 "$here/cases.py" "$work"

total=0
for c in a b c; do
  "$work/oracle" < "$work/$c.hex" > "$work/$c.oracle"
  "$decodecheck" < "$work/$c.hex" > "$work/$c.lean"
  words=$(wc -l < "$work/$c.hex" | tr -d ' ')
  paste -d '|' "$work/$c.hex" "$work/$c.oracle" "$work/$c.lean" | awk -F '|' '$2 != $3' > "$work/$c.bad"
  bad=$(wc -l < "$work/$c.bad" | tr -d ' ')
  echo "class ($c): $words words, $bad mismatches"
  [ "$bad" -eq 0 ] || head -5 "$work/$c.bad" | sed 's/^/    word|oracle|decode32: /'
  total=$((total + bad))
done

if [ "${1:-}" = "--all" ]; then
  sweep 0 4294967296 || total=$((total + 1))
fi

[ "$total" -eq 0 ]
