#!/usr/bin/env bash
# Reproduction for llvm/circt issue #7388
# "[FIRRTL][LowerToHW] crash lowering enum code"
#
# Running `circt-opt --lower-firrtl-to-hw` on issue7388.mlir segfaults in
# `FIRRTLLowering::visitExpr(FEnumCreateOp)` (lib/Conversion/FIRRTLToHW/
# LowerToHW.cpp) while creating a `hw::UnionCreateOp` whose input is the null
# Value produced by lowering a zero-width payload.
#
# Contract: this script exits 0 if and only if the bug is FIXED.  While the
# bug is present the tool dies with SIGSEGV (exit 139) or otherwise fails, so
# the script exits non-zero.
set -u

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
CIRCT_OPT="${CIRCT_OPT:-/workspace/circt/build/bin/circt-opt}"

"$CIRCT_OPT" --lower-firrtl-to-hw "$REPO_DIR/issue7388.mlir" -o /dev/null
status=$?

if [ "$status" -eq 0 ]; then
  echo "PASS: lower-firrtl-to-hw completed without crashing (issue #7388 appears fixed)"
  exit 0
fi
echo "FAIL: lower-firrtl-to-hw exited with $status (issue #7388 still reproduces)"
exit "$status"
