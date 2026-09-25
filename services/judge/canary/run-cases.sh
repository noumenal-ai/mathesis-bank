#!/usr/bin/env bash
# The canary: judge each solution in a fresh copy of the template, under
# comparator (landrun inside) wrapped in systemd-run with AF_UNIX restricted.
set -uo pipefail
export PATH="$HOME/.elan/bin:$HOME/tools/bin:$PATH"
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
cd "$HOME/canary"
mkdir -p results runs
: > results/summary.txt
{ echo "kernel $(uname -r)"; (cd template && lean --version); landrun --version 2>&1 | head -1
  mkdir -p "$HOME/canary/probe"; rm -f "$HOME/canary/probe/inside" "$HOME/landrun-probe"
  landrun --best-effort --ro / --rw /dev --rox /usr --rwx "$HOME/canary/probe" -ldd -add-exec -- /usr/bin/sh -c "touch $HOME/canary/probe/inside; touch $HOME/landrun-probe" 2>&1 | tail -1
  echo "landrun inside write: $([ -e "$HOME/canary/probe/inside" ] && echo made || echo MISSING) (must be made: proves the sandbox ran)"
  echo "landrun outside write: $([ -e "$HOME/landrun-probe" ] && echo WRITTEN || echo denied) (must be denied)"
  echo "sockets in the judged unit: $(systemd-run --user --wait --pipe --quiet -p RestrictAddressFamilies=AF_PACKET -- sh -c 'getent ahosts example.com >/dev/null 2>&1 && echo DNS-RESOLVED || echo dns-blocked; systemd-run --user --wait --quiet true 2>/dev/null && echo BUS-OPEN || echo bus-blocked' | tr '\n' ' ') (must be dns-blocked bus-blocked)"
} >> results/summary.txt
for c in good weaker axiom sorry escape escape2; do
  # A fresh project per case: the trusted files, Mathlib by symlink to the
  # template's read-only packages, and the solution, never compiled before.
  d="runs/$c"; mkdir -p "$d/.lake"
  cp template/lakefile.toml template/lean-toolchain template/lake-manifest.json template/Challenge.lean template/config.json "$d/"
  ln -s "$HOME/canary/template/.lake/packages" "$d/.lake/packages"
  cp "cases/$c.lean" "$d/Solution.lean"
  rm -f "$HOME/ESCAPED"; s=$(date +%s)
  systemd-run --user --wait --collect --pipe --quiet \
    -p RestrictAddressFamilies=AF_PACKET -E PATH="$PATH" --working-directory="$HOME/canary/$d" \
    -- bash -c 'lake env comparator config.json' > "results/$c.log" 2>&1
  rc=$?
  echo "$c rc=$rc secs=$(( $(date +%s) - s )) escaped=$([ -e "$HOME/ESCAPED" ] && echo YES || echo no)" >> results/summary.txt
done
echo DONE >> results/summary.txt
