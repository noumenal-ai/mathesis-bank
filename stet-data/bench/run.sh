#!/usr/bin/env bash
# Measure the benchmark files in bench/ (the plan's section 8). For each file: wall time, peak memory
# and the outcome, which is `ok`, the cap, or the first error line verbatim. For each Bench_*_S.lean,
# also the size of the .olean the data compiles to.
#
#   bash bench/run.sh [CAP] [FILE...]      CAP seconds per run (default 120); default every bench file
#
# Runs are sequential, so they do not compete for the CPU. No Lean limit is raised.
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/.." && pwd)"
cap="${1:-120}"
[ $# -gt 0 ] && shift
cd "$root"
lake build >/dev/null || { echo "lake build failed" >&2; exit 1; }
# Run `lean` itself, not `lake env lean`: the cap must stop the process doing the work.
LEAN="$(lake env which lean)"
LEAN_PATH="$(lake env printenv LEAN_PATH)"
export LEAN_PATH

if [ $# -gt 0 ]; then files=("$@"); else files=("$here"/Bench_base.lean "$here"/Bench_*_*.lean); fi
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

printf 'file\twall_s\tpeak_MB\tolean_bytes\toutcome\n'
for f in "${files[@]}"; do
  name="$(basename "$f" .lean)"
  olean=""
  [[ "$name" == *_S ]] && olean="-o $work/$name.olean"
  # shellcheck disable=SC2086
  /usr/bin/time -l perl -e 'alarm shift; exec @ARGV' "$cap" "$LEAN" $olean "$f" \
    > "$work/out" 2> "$work/time"
  rc=$?
  wall="$(awk '$2 == "real" {print $1}' "$work/time")"
  peak="$(awk '/maximum resident set size/ {printf "%.0f", $1 / 1048576}' "$work/time")"
  size="-"
  [ -n "$olean" ] && [ -f "$work/$name.olean" ] && size="$(stat -f %z "$work/$name.olean")"
  if [ "$rc" -eq 0 ] && ! grep -q 'error' "$work/out"; then
    outcome="ok"
  elif [ "$rc" -eq 142 ]; then
    outcome="stopped at the ${cap} s cap"
  else
    outcome="$(grep -m1 'error' "$work/out" "$work/time" | sed -E 's#^.*\.lean:[0-9]+:[0-9]+: ##' | cut -c1-200)"
    [ -n "$outcome" ] || outcome="exit $rc"
  fi
  printf '%s\t%s\t%s\t%s\t%s\n' "$name" "$wall" "$peak" "$size" "$outcome"
done
