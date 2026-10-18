#!/usr/bin/env bash
# Reproduction for https://github.com/llvm/circt/issues/4354
#
# Two `chisel3.util.experimental.ForceNameAnnotation`s target two DIFFERENT
# instances inside the SAME parent module and force them to the SAME Verilog
# name ("Foo").  LowerToHW currently accepts this silently and emits two
# `hw.instance` ops carrying colliding `hw.verilogName = "Foo"` attributes;
# the collision is only papered over later by PrepareForEmission/ExportVerilog
# name uniquing (Foo -> Foo_0/Foo_1), silently defeating the user's forced
# naming.  The bug is FIXED when LowerToHW instead diagnoses the collision
# with an error.
#
# Contract: exit 0 iff the bug is fixed, non-zero while the bug is present.
set -u

CIRCT_OPT=/workspace/circt/build/bin/circt-opt
INPUT=/workspace/circt/.circtissues/force-name-collision.mlir

out=$("$CIRCT_OPT" -pass-pipeline="builtin.module(lower-firrtl-to-hw)" \
        "$INPUT" 2>&1)
status=$?
printf '%s\n' "$out"

if [ $status -ne 0 ]; then
  # The pass rejected the input.  Only count it as fixed if the rejection is
  # actually the ForceNameAnnotation collision diagnostic (some unrelated
  # error would indicate a broken repro, not a fix).
  if grep -qi 'ForceNameAnnotation' <<<"$out"; then
    echo "PASS: LowerToHW errors on non-unique ForceNameAnnotation names."
    exit 0
  fi
  echo "FAIL: LowerToHW failed, but not with the expected diagnostic."
  exit 1
fi

# The pass succeeded.  The bug is present iff two instances in the same
# module ended up with the same forced name.
if [ "$(grep -c 'hw.verilogName = "Foo"' <<<"$out")" -ge 2 ]; then
  echo "FAIL: multiple instances in one module got the same hw.verilogName" \
       "without any diagnostic (issue #4354)."
  exit 1
fi

echo "PASS: no colliding forced names emitted."
exit 0
