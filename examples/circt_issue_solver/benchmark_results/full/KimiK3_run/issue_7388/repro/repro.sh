#!/usr/bin/env bash
# Repro for CIRCT issue #7388: [FIRRTL][LowerToHW] crash lowering enum code.
#
# Lowering `firrtl.enumcreate` for a zero-width tag of a multi-variant enum
# segfaults in LowerToHW (visitExpr(FEnumCreateOp) passes a null lowered Value
# for the zero-width input to hw::UnionCreateOp).
#
# Contract: exit 0 iff the bug is FIXED; non-zero while the bug is present.
set -u
cd "$(dirname "$0")"
/workspace/circt/build/bin/circt-opt --lower-firrtl-to-hw issue-7388.mlir > /dev/null 2>&1
rc=$?
if [ $rc -ne 0 ]; then
  echo "BUG PRESENT: circt-opt --lower-firrtl-to-hw exited with $rc" >&2
  exit 1
fi
echo "OK: lowering completed without crashing"
exit 0
