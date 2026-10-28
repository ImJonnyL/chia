# Issue #2669: [FIRRTL] Bitwidth conventions for artihmetic ops

- State: open
- Author: prithayan
- Created: 2022-02-22T18:20:21Z
- Updated: 2022-02-22T19:03:00Z
- URL: https://github.com/llvm/circt/issues/2669

## Body

`firtool` bit extends each operand to the destination type. This seems to differ from `firrtl` output.
The output is semantically correct, but this might be a verilog output quality issue.
So, if a multiplication produces 3 bit result, then the input operands are extended to 3 bits.
This is the standard assumption for `HW` dialect, https://github.com/llvm/circt/blob/main/lib/Conversion/FIRRTLToHW/LowerToHW.cpp#L3005

Input `fir` 
```python 
circuit MyModule :

  module MyModule :
    input in1: UInt<1>
    input in2: UInt<2>
    output out: UInt<3>

    out <= mul(in1, in2)
```
`firtool` output
``` verilog
module MyModule( 
  input        in1,
  input  [1:0] in2,
  output [2:0] out);                                                                                                                                                                                                                        
  assign out = {2'h0, in1} * {1'h0, in2}; 
endmodule
```
`firrtl` output
```verilog
module MyModule(
  input        in1,
  input  [1:0] in2,
  output [2:0] out
);                                 
assign out = in1 * in2;
endmodule
```

