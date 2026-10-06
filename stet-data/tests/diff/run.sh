#!/usr/bin/env bash
# The differential test of step 1f: decode32, compiled (`lake exe decodecheck`), against the C
# oracle in oracle.c, which shares no logic with it.
#
#   bash tests/diff/run.sh         case classes (a), (b) and (c); see cases.py
#   bash tests/diff/run.sh --all   also every one of the 2^32 words, streamed: nothing is written
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
  if out=$(cmp <("$work/oracle" --all) <("$decodecheck" --all) 2>&1); then
    echo "all 2^32 words: 0 mismatches"
  else
    echo "all 2^32 words: mismatch: $out"
    total=$((total + 1))
  fi
fi

[ "$total" -eq 0 ]
