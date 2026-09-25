#!/usr/bin/env bash
# Provision the Mathesis judge on a fresh Ubuntu 24.04 VM (run as root, once).
# An unprivileged `judge` user gets Lean v4.31.0 (elan), comparator fd2e25de15
# patched for v4.31 (mathesis-v4.31.patch), with its own lean4export 8554815c2d, landrun 811cfff51c, and the canary
# project with Mathlib fabf563a from Mathlib's cache.
set -euxo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y git curl build-essential ca-certificates
snap install go --classic --channel=1.24/stable
id judge >/dev/null 2>&1 || useradd -m -s /bin/bash judge
loginctl enable-linger judge
install -d -o judge -g judge /home/judge/canary
cp -r /tmp/payload/template /tmp/payload/cases /tmp/payload/run-cases.sh /home/judge/canary/
chown -R judge:judge /home/judge/canary
sudo -u judge -H bash /tmp/payload/provision-judge.sh
echo PROVISIONED
