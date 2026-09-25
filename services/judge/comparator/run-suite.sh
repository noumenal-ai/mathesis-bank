#!/bin/bash
# Rebuild the patched comparator and run its whole test suite; results in ~/suite.log.
set -u
export PATH=/home/judge/tools/bin:$PATH
cd /home/judge/tools/comparator
# The patched comparator is already built by provision-judge.sh.
{
  echo "=== build"
  lake build 2>&1 | tail -15
  echo "BUILD_RC=${PIPESTATUS[0]}"
  echo "=== tests"
  lean --run runtests.lean 2>&1
  echo "TESTS_RC=$?"
} > /home/judge/suite.log 2>&1
echo SUITE_DONE >> /home/judge/suite.log
