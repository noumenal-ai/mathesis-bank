#!/usr/bin/env bash
set -euxo pipefail
cd "$HOME"
[ -x "$HOME/.elan/bin/elan" ] || curl -sSf https://raw.githubusercontent.com/leanprover/elan/master/elan-init.sh | sh -s -- -y --default-toolchain none
export PATH="$HOME/.elan/bin:$HOME/tools/bin:$PATH"
mkdir -p tools/bin
[ -d tools/landrun-src ] || git clone -q https://github.com/Zouuup/landrun tools/landrun-src
(cd tools/landrun-src && git checkout -q 811cfff51c && /snap/bin/go build -o "$HOME/tools/bin/landrun" ./cmd/landrun)
[ -d tools/comparator ] || git clone -q https://github.com/leanprover/comparator tools/comparator
# Our fixes on top of v4.31 (services/judge/comparator/mathesis-v4.31.patch); without them the
# judge has the holes the canary and the comparator's own tests exercise.
(cd tools/comparator && git checkout -q fd2e25de15 && git -c user.name=judge -c user.email=judge@localhost am -q /tmp/payload/mathesis-v4.31.patch && lake build)
(cd tools/comparator/.lake/packages/lean4export && git rev-parse --short=10 HEAD && lake build)
ln -sf "$HOME/tools/comparator/.lake/build/bin/comparator" tools/bin/comparator
ln -sf "$HOME/tools/comparator/.lake/packages/lean4export/.lake/build/bin/lean4export" tools/bin/lean4export
cd "$HOME/canary/template"
lake exe cache get
# The challenge must build before any solution is judged; its build is then
# discarded so every case starts from the same untouched tree.
lake build Challenge
rm -rf .lake/build
chmod -R a-w .lake/packages
