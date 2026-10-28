#!/usr/bin/env bash
#
# Reproduction script for CIRCT issue #6740:
#   [FIRRTLToHW] Conversion failure of invalidated wire of clock type
#   https://github.com/llvm/circt/issues/6740
#
# Running `circt-opt -lower-firrtl-to-hw` on a FIRRTL invalid value of clock
# type fails verification: the lowering of `firrtl.invalidvalue` creates an
# `hw.bitcast` from an `i1` zero constant to `!seq.clock`
# (lib/Conversion/FIRRTLToHW/LowerToHW.cpp, FIRRTLLowering::visitExpr(
# InvalidValueOp)), and `hw.bitcast` requires a result type whose hardware
# bitwidth is known, which `!seq.clock` is not:
#
#   error: 'hw.bitcast' op result #0 must be Type wherein the bitwidth in
#   hardware is known, but got '!seq.clock'
#   note: see current operation: %2 = "hw.bitcast"(%0) : (i1) -> !seq.clock
#
# Contract: exit 0 if and only if the bug is FIXED, i.e. both inputs below
# lower cleanly (circt-opt exit code 0).  While the bug is present, circt-opt
# exits non-zero on the verifier error and this script propagates it.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CIRCT_OPT="$SCRIPT_DIR/../build/bin/circt-opt"

if [[ ! -x "$CIRCT_OPT" ]]; then
  echo "error: $CIRCT_OPT not found or not executable" >&2
  exit 2
fi

status=0

# Input 1: the issue's scenario -- an invalidated wire of clock type.
if "$CIRCT_OPT" "$SCRIPT_DIR/issue6740_wire.mlir" -lower-firrtl-to-hw \
    -o /dev/null; then
  echo "PASS: invalidated clock wire lowered cleanly"
else
  echo "FAIL: invalidated clock wire failed to lower (issue #6740)" >&2
  status=1
fi

# Input 2: reduced minimal trigger -- a bare invalid value of clock type.
if "$CIRCT_OPT" "$SCRIPT_DIR/issue6740_min.mlir" -lower-firrtl-to-hw \
    -o /dev/null; then
  echo "PASS: bare invalid clock value lowered cleanly"
else
  echo "FAIL: bare invalid clock value failed to lower (issue #6740)" >&2
  status=1
fi

exit $status
