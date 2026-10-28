#!/usr/bin/env bash
# Reproduction for CIRCT issue #7949: [DCToHW] Pass creates invalid ESI
# connections.
#
# `circt-opt --lower-dc-to-hw` fails on a fully fork/sink-materialized DC
# module whenever a `dc.pack` result is unpacked again and its token is
# forked.  The DCToHW lowering emits an `esi.wrap.vr` whose channel then has
# two consumers, which the ESI verifier rejects:
#
#   error: 'esi.wrap.vr' op channels must have at most one consumer
#
# (In the issue report the same bug surfaced as "'esi.wrap.vr' op only
# supports zero or one use" on older builds; the message has been reworded,
# the root cause is the same.)
#
# The script exits 0 if and only if the bug is FIXED, i.e. the lowering
# succeeds.  While the bug is present, circt-opt exits non-zero on the
# verification error below, which we propagate.
set -u
cd "$(dirname "$0")"

CIRCT_OPT=${CIRCT_OPT:-/workspace/circt/build/bin/circt-opt}

"$CIRCT_OPT" repro.mlir --lower-dc-to-hw > /dev/null
status=$?

if [ "$status" -eq 0 ]; then
  echo "PASS: lower-dc-to-hw succeeded (bug is fixed)"
  exit 0
else
  echo "FAIL: lower-dc-to-hw failed with exit $status (bug is present)"
  exit "$status"
fi
