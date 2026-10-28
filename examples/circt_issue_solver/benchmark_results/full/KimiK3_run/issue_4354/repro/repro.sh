#!/bin/sh
# Reproduction for CIRCT issue #4354:
# "[LowerToHW] An Error Should Be Generated if ForceNameAnnotation Would Not
# Be Unique"
#
# Two ForceNameAnnotations force two different instances inside ForceNameTop
# to the same Verilog name "Foo". LowerToHW silently assigns
# hw.verilogName = "Foo" to both instances (and a third instance is already
# literally named "Foo"), so ExportVerilog later has to silently unique the
# names. The expected behavior is that LowerToHW emits an error instead.
#
# Exit 0 iff the bug is FIXED (LowerToHW rejects the input with an error).
# Exit 1 while the bug is still present (LowerToHW silently accepts it).

CIRCT_OPT=/workspace/circt/build/bin/circt-opt
INPUT=/workspace/circt/.circtissues/forcename.mlir

OUTPUT=$("$CIRCT_OPT" --lower-firrtl-to-hw "$INPUT" 2>&1)
STATUS=$?

if [ $STATUS -ne 0 ]; then
  # LowerToHW errored: the bug is fixed (an error is the desired behavior).
  echo "PASS: LowerToHW rejected non-unique ForceNameAnnotations:"
  echo "$OUTPUT"
  exit 0
fi

# LowerToHW succeeded. Check whether both instances got the same verilogName,
# which is the buggy behavior.
NUM_FOO=$(printf '%s\n' "$OUTPUT" | grep -c 'hw.verilogName = "Foo"')
if [ "$NUM_FOO" -ge 2 ]; then
  echo "FAIL: bug present: LowerToHW silently assigned the same verilogName \"Foo\" to multiple instances:"
  printf '%s\n' "$OUTPUT" | grep -n 'hw.instance\|verilogName'
  exit 1
fi

# Succeeded without duplicating the forced name: also acceptable (fixed).
echo "PASS: no duplicate verilogName produced."
exit 0
