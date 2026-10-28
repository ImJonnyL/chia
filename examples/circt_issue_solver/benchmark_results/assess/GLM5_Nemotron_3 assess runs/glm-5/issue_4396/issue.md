# Issue #4396: [FIRRTLFolds] Fold binary operators with one zero-width operand

- State: open
- Author: dtzSiFive
- Created: 2022-12-02T17:28:34Z
- Updated: 2022-12-06T15:14:19Z
- URL: https://github.com/llvm/circt/issues/4396

## Body

Test case, produced while working on #4395 :

```mlir
firrtl.circuit "zeroWidthOperand" {
firrtl.module @zeroWidthOperand(
  in %in0 : !firrtl.uint<0>,
  in %in1 : !firrtl.uint<1>,
  out %o_add1: !firrtl.uint<2>,
  out %o_add2: !firrtl.uint<2>,
  out %o_sub1: !firrtl.uint<2>,
  out %o_sub2: !firrtl.uint<2>,
  out %o_mul1: !firrtl.uint<1>,
  out %o_mul2: !firrtl.uint<1>,
  out %o_div1: !firrtl.uint<0>,
  out %o_div2: !firrtl.uint<1>,
  out %o_rem1: !firrtl.uint<0>,
  out %o_rem2: !firrtl.uint<0>,
  out %o_dshl1: !firrtl.uint<1>,
  out %o_dshl2: !firrtl.uint<1>,
  out %o_dshlw1: !firrtl.uint<0>,
  out %o_dshlw2: !firrtl.uint<1>,
  out %o_dshr1: !firrtl.uint<0>,
  out %o_dshr2: !firrtl.uint<1>,
  out %o_and1: !firrtl.uint<1>,
  out %o_and2: !firrtl.uint<1>,
  out %o_or1: !firrtl.uint<1>,
  out %o_or2: !firrtl.uint<1>,
  out %o_xor1: !firrtl.uint<1>,
  out %o_xor2: !firrtl.uint<1>
) {
  %add1 = firrtl.add %in0, %in1 : (!firrtl.uint<0>, !firrtl.uint<1>) -> !firrtl.uint<2>
  %add2 = firrtl.add %in1, %in0 : (!firrtl.uint<1>, !firrtl.uint<0>) -> !firrtl.uint<2>
  %sub1 = firrtl.sub %in0, %in1 : (!firrtl.uint<0>, !firrtl.uint<1>) -> !firrtl.uint<2>
  %sub2 = firrtl.sub %in1, %in0 : (!firrtl.uint<1>, !firrtl.uint<0>) -> !firrtl.uint<2>
  %mul1 = firrtl.mul %in0, %in1 : (!firrtl.uint<0>, !firrtl.uint<1>) -> !firrtl.uint<1>
  %mul2 = firrtl.mul %in1, %in0 : (!firrtl.uint<1>, !firrtl.uint<0>) -> !firrtl.uint<1>
  %div1 = firrtl.div %in0, %in1 : (!firrtl.uint<0>, !firrtl.uint<1>) -> !firrtl.uint<0>
  %div2 = firrtl.div %in1, %in0 : (!firrtl.uint<1>, !firrtl.uint<0>) -> !firrtl.uint<1>
  %rem1 = firrtl.rem %in0, %in1 : (!firrtl.uint<0>, !firrtl.uint<1>) -> !firrtl.uint<0>
  %rem2 = firrtl.rem %in1, %in0 : (!firrtl.uint<1>, !firrtl.uint<0>) -> !firrtl.uint<0>
  %dshl1 = firrtl.dshl %in0, %in1 : (!firrtl.uint<0>, !firrtl.uint<1>) -> !firrtl.uint<1>
  %dshl2 = firrtl.dshl %in1, %in0 : (!firrtl.uint<1>, !firrtl.uint<0>) -> !firrtl.uint<1>
  %dshlw1 = firrtl.dshlw %in0, %in1 : (!firrtl.uint<0>, !firrtl.uint<1>) -> !firrtl.uint<0>
  %dshlw2 = firrtl.dshlw %in1, %in0 : (!firrtl.uint<1>, !firrtl.uint<0>) -> !firrtl.uint<1>
  %dshr1 = firrtl.dshr %in0, %in1 : (!firrtl.uint<0>, !firrtl.uint<1>) -> !firrtl.uint<0>
  %dshr2 = firrtl.dshr %in1, %in0 : (!firrtl.uint<1>, !firrtl.uint<0>) -> !firrtl.uint<1>
  %and1 = firrtl.and %in0, %in1 : (!firrtl.uint<0>, !firrtl.uint<1>) -> !firrtl.uint<1>
  %and2 = firrtl.and %in1, %in0 : (!firrtl.uint<1>, !firrtl.uint<0>) -> !firrtl.uint<1>
  %or1 = firrtl.or %in0, %in1 : (!firrtl.uint<0>, !firrtl.uint<1>) -> !firrtl.uint<1>
  %or2 = firrtl.or %in1, %in0 : (!firrtl.uint<1>, !firrtl.uint<0>) -> !firrtl.uint<1>
  %xor1 = firrtl.xor %in0, %in1 : (!firrtl.uint<0>, !firrtl.uint<1>) -> !firrtl.uint<1>
  %xor2 = firrtl.xor %in1, %in0 : (!firrtl.uint<1>, !firrtl.uint<0>) -> !firrtl.uint<1>

  firrtl.strictconnect %o_add1, %add1 : !firrtl.uint<2>
  firrtl.strictconnect %o_add2, %add2 : !firrtl.uint<2>
  firrtl.strictconnect %o_sub1, %sub1: !firrtl.uint<2>
  firrtl.strictconnect %o_sub2, %sub2: !firrtl.uint<2>
  firrtl.strictconnect %o_mul1, %mul1: !firrtl.uint<1>
  firrtl.strictconnect %o_mul2, %mul2: !firrtl.uint<1>
  firrtl.strictconnect %o_div1, %div1 : !firrtl.uint<0>
  firrtl.strictconnect %o_div2, %div2 : !firrtl.uint<1>
  firrtl.strictconnect %o_rem1, %rem1 : !firrtl.uint<0>
  firrtl.strictconnect %o_rem2, %rem2 : !firrtl.uint<0>
  firrtl.strictconnect %o_dshl1, %dshl1 : !firrtl.uint<1>
  firrtl.strictconnect %o_dshl2, %dshl2 : !firrtl.uint<1>
  firrtl.strictconnect %o_dshlw1, %dshlw1 : !firrtl.uint<0>
  firrtl.strictconnect %o_dshlw2, %dshlw2 : !firrtl.uint<1>
  firrtl.strictconnect %o_dshr1, %dshr1 : !firrtl.uint<0>
  firrtl.strictconnect %o_dshr2, %dshr2 : !firrtl.uint<1>
  firrtl.strictconnect %o_and1, %and1 : !firrtl.uint<1>
  firrtl.strictconnect %o_and2, %and2 : !firrtl.uint<1>
  firrtl.strictconnect %o_or1, %or1 : !firrtl.uint<1>
  firrtl.strictconnect %o_or2, %or2 : !firrtl.uint<1>
  firrtl.strictconnect %o_xor1, %xor1 : !firrtl.uint<1>
  firrtl.strictconnect %o_xor2, %xor2 : !firrtl.uint<1>
}
}
```

With that PR, the operations with zero-width return are replaced with zero but the others are not folded/canonicalized (and at least most of them can be).

Here's the current `firtool -ir-fir` output on the above:

```mlir
module {
  firrtl.circuit "zeroWidthOperand"  {
    firrtl.module @zeroWidthOperand(in %in0: !firrtl.uint<0>, in %in1: !firrtl.uint<1>, out %o_add1: !firrtl.uint<2>, out %o_add2: !firrtl.uint<2>, out %o_sub1: !firrtl.uint<2>, out %o_sub2: !firrtl.uint<2>, out %o_mul1: !firrtl.uint<1>, out %o_mul2: !firrtl.uint<1>, out %o_div1: !firrtl.uint<0>, out %o_div2: !firrtl.uint<1>, out %o_rem1: !firrtl.uint<0>, out %o_rem2: !firrtl.uint<0>, out %o_dshl1: !firrtl.uint<1>, out %o_dshl2: !firrtl.uint<1>, out %o_dshlw1: !firrtl.uint<0>, out %o_dshlw2: !firrtl.uint<1>, out %o_dshr1: !firrtl.uint<0>, out %o_dshr2: !firrtl.uint<1>, out %o_and1: !firrtl.uint<1>, out %o_and2: !firrtl.uint<1>, out %o_or1: !firrtl.uint<1>, out %o_or2: !firrtl.uint<1>, out %o_xor1: !firrtl.uint<1>, out %o_xor2: !firrtl.uint<1>) {
      %0 = firrtl.add %in0, %in1 : (!firrtl.uint<0>, !firrtl.uint<1>) -> !firrtl.uint<2>
      %1 = firrtl.sub %in0, %in1 : (!firrtl.uint<0>, !firrtl.uint<1>) -> !firrtl.uint<2>
      %2 = firrtl.sub %in1, %in0 : (!firrtl.uint<1>, !firrtl.uint<0>) -> !firrtl.uint<2>
      %3 = firrtl.mul %in0, %in1 : (!firrtl.uint<0>, !firrtl.uint<1>) -> !firrtl.uint<1>
      %4 = firrtl.div %in0, %in1 : (!firrtl.uint<0>, !firrtl.uint<1>) -> !firrtl.uint<0>
      %5 = firrtl.div %in1, %in0 : (!firrtl.uint<1>, !firrtl.uint<0>) -> !firrtl.uint<1>
      %6 = firrtl.rem %in0, %in1 : (!firrtl.uint<0>, !firrtl.uint<1>) -> !firrtl.uint<0>
      %7 = firrtl.rem %in1, %in0 : (!firrtl.uint<1>, !firrtl.uint<0>) -> !firrtl.uint<0>
      %8 = firrtl.dshl %in0, %in1 : (!firrtl.uint<0>, !firrtl.uint<1>) -> !firrtl.uint<1>
      %9 = firrtl.dshl %in1, %in0 : (!firrtl.uint<1>, !firrtl.uint<0>) -> !firrtl.uint<1>
      %10 = firrtl.dshlw %in0, %in1 : (!firrtl.uint<0>, !firrtl.uint<1>) -> !firrtl.uint<0>
      %11 = firrtl.dshlw %in1, %in0 : (!firrtl.uint<1>, !firrtl.uint<0>) -> !firrtl.uint<1>
      %12 = firrtl.dshr %in0, %in1 : (!firrtl.uint<0>, !firrtl.uint<1>) -> !firrtl.uint<0>
      %13 = firrtl.dshr %in1, %in0 : (!firrtl.uint<1>, !firrtl.uint<0>) -> !firrtl.uint<1>
      %14 = firrtl.and %in0, %in1 : (!firrtl.uint<0>, !firrtl.uint<1>) -> !firrtl.uint<1>
      %15 = firrtl.or %in0, %in1 : (!firrtl.uint<0>, !firrtl.uint<1>) -> !firrtl.uint<1>
      %16 = firrtl.xor %in0, %in1 : (!firrtl.uint<0>, !firrtl.uint<1>) -> !firrtl.uint<1>
      firrtl.strictconnect %o_add1, %0 : !firrtl.uint<2>
      firrtl.strictconnect %o_add2, %0 : !firrtl.uint<2>
      firrtl.strictconnect %o_sub1, %1 : !firrtl.uint<2>
      firrtl.strictconnect %o_sub2, %2 : !firrtl.uint<2>
      firrtl.strictconnect %o_mul1, %3 : !firrtl.uint<1>
      firrtl.strictconnect %o_mul2, %3 : !firrtl.uint<1>
      firrtl.strictconnect %o_div1, %4 : !firrtl.uint<0>
      firrtl.strictconnect %o_div2, %5 : !firrtl.uint<1>
      firrtl.strictconnect %o_rem1, %6 : !firrtl.uint<0>
      firrtl.strictconnect %o_rem2, %7 : !firrtl.uint<0>
      firrtl.strictconnect %o_dshl1, %8 : !firrtl.uint<1>
      firrtl.strictconnect %o_dshl2, %9 : !firrtl.uint<1>
      firrtl.strictconnect %o_dshlw1, %10 : !firrtl.uint<0>
      firrtl.strictconnect %o_dshlw2, %11 : !firrtl.uint<1>
      firrtl.strictconnect %o_dshr1, %12 : !firrtl.uint<0>
      firrtl.strictconnect %o_dshr2, %13 : !firrtl.uint<1>
      firrtl.strictconnect %o_and1, %14 : !firrtl.uint<1>
      firrtl.strictconnect %o_and2, %14 : !firrtl.uint<1>
      firrtl.strictconnect %o_or1, %15 : !firrtl.uint<1>
      firrtl.strictconnect %o_or2, %15 : !firrtl.uint<1>
      firrtl.strictconnect %o_xor1, %16 : !firrtl.uint<1>
      firrtl.strictconnect %o_xor2, %16 : !firrtl.uint<1>
    }
  }
}
```


## Comments (2)

### Comment by dtzSiFive — 2022-12-02T17:34:13Z

Compare with replacing the zero-width operand with a constant zero-width operand  (`%in0 = firrtl.constant 0 : !firrtl.uint<0>` at top), and we instead produce:

```mlir
module {
  firrtl.circuit "zeroWidthOperand"  {
    firrtl.module @zeroWidthOperand(in %in1: !firrtl.uint<1>, out %o_add1: !firrtl.uint<2>, out %o_add2: !firrtl.uint<2>, out %o_sub1: !firrtl.uint<2>, out %o_sub2: !firrtl.uint<2>, out %o_mul1: !firrtl.uint<1>, out %o_mul2: !firrtl.uint<1>, out %o_div1: !firrtl.uint<0>, out %o_div2: !firrtl.uint<1>, out %o_rem1: !firrtl.uint<0>, out %o_rem2: !firrtl.uint<0>, out %o_dshl1: !firrtl.uint<1>, out %o_dshl2: !firrtl.uint<1>, out %o_dshlw1: !firrtl.uint<0>, out %o_dshlw2: !firrtl.uint<1>, out %o_dshr1: !firrtl.uint<0>, out %o_dshr2: !firrtl.uint<1>, out %o_and1: !firrtl.uint<1>, out %o_and2: !firrtl.uint<1>, out %o_or1: !firrtl.uint<1>, out %o_or2: !firrtl.uint<1>, out %o_xor1: !firrtl.uint<1>, out %o_xor2: !firrtl.uint<1>) {
      %c0_ui1 = firrtl.constant 0 : !firrtl.uint<1>
      %c0_ui0 = firrtl.constant 0 : !firrtl.uint<0>
      %0 = firrtl.pad %in1, 2 : (!firrtl.uint<1>) -> !firrtl.uint<2>
      %1 = firrtl.neg %in1 : (!firrtl.uint<1>) -> !firrtl.sint<2>
      %2 = firrtl.asUInt %1 : (!firrtl.sint<2>) -> !firrtl.uint<2>
      %3 = firrtl.pad %in1, 2 : (!firrtl.uint<1>) -> !firrtl.uint<2>
      %4 = firrtl.div %in1, %c0_ui0 : (!firrtl.uint<1>, !firrtl.uint<0>) -> !firrtl.uint<1>
      %5 = firrtl.rem %in1, %c0_ui0 : (!firrtl.uint<1>, !firrtl.uint<0>) -> !firrtl.uint<0>
      %6 = firrtl.dshl %c0_ui0, %in1 : (!firrtl.uint<0>, !firrtl.uint<1>) -> !firrtl.uint<1>
      %7 = firrtl.dshlw %c0_ui0, %in1 : (!firrtl.uint<0>, !firrtl.uint<1>) -> !firrtl.uint<0>
      %8 = firrtl.dshlw %in1, %c0_ui0 : (!firrtl.uint<1>, !firrtl.uint<0>) -> !firrtl.uint<1>
      %9 = firrtl.dshr %c0_ui0, %in1 : (!firrtl.uint<0>, !firrtl.uint<1>) -> !firrtl.uint<0>
      firrtl.strictconnect %o_add1, %0 : !firrtl.uint<2>
      firrtl.strictconnect %o_add2, %0 : !firrtl.uint<2>
      firrtl.strictconnect %o_sub1, %2 : !firrtl.uint<2>
      firrtl.strictconnect %o_sub2, %3 : !firrtl.uint<2>
      firrtl.strictconnect %o_mul1, %c0_ui1 : !firrtl.uint<1>
      firrtl.strictconnect %o_mul2, %c0_ui1 : !firrtl.uint<1>
      firrtl.strictconnect %o_div1, %c0_ui0 : !firrtl.uint<0>
      firrtl.strictconnect %o_div2, %4 : !firrtl.uint<1>
      firrtl.strictconnect %o_rem1, %c0_ui0 : !firrtl.uint<0>
      firrtl.strictconnect %o_rem2, %5 : !firrtl.uint<0>
      firrtl.strictconnect %o_dshl1, %6 : !firrtl.uint<1>
      firrtl.strictconnect %o_dshl2, %in1 : !firrtl.uint<1>
      firrtl.strictconnect %o_dshlw1, %7 : !firrtl.uint<0>
      firrtl.strictconnect %o_dshlw2, %8 : !firrtl.uint<1>
      firrtl.strictconnect %o_dshr1, %9 : !firrtl.uint<0>
      firrtl.strictconnect %o_dshr2, %in1 : !firrtl.uint<1>
      firrtl.strictconnect %o_and1, %c0_ui1 : !firrtl.uint<1>
      firrtl.strictconnect %o_and2, %c0_ui1 : !firrtl.uint<1>
      firrtl.strictconnect %o_or1, %in1 : !firrtl.uint<1>
      firrtl.strictconnect %o_or2, %in1 : !firrtl.uint<1>
      firrtl.strictconnect %o_xor1, %in1 : !firrtl.uint<1>
      firrtl.strictconnect %o_xor2, %in1 : !firrtl.uint<1>
    }
  }
}
```

If going all the way through, both produce:
```systemverilog
module zeroWidthOperand(	// zeroWidthOperand.mlir:2:1
  input        in1,
  output [1:0] o_add1,
               o_add2,
               o_sub1,
               o_sub2,
  output       o_mul1,
               o_mul2,
               o_div2,
               o_dshl1,
               o_dshl2,
               o_dshlw2,
               o_dshr2,
               o_and1,
               o_and2,
               o_or1,
               o_or2,
               o_xor1,
               o_xor2);

  wire [1:0] _GEN = {1'h0, in1};	// zeroWidthOperand.mlir:27:10, :28:11, :32:11
  assign o_add1 = _GEN;	// zeroWidthOperand.mlir:2:1, :27:10, :28:11
  assign o_add2 = _GEN;	// zeroWidthOperand.mlir:2:1, :27:10, :28:11
  assign o_sub1 = 2'h0 - _GEN;	// zeroWidthOperand.mlir:2:1, :27:10, :28:11, :30:11
  assign o_sub2 = _GEN;	// zeroWidthOperand.mlir:2:1, :27:10, :28:11
  assign o_mul1 = 1'h0;	// zeroWidthOperand.mlir:2:1, :32:11
  assign o_mul2 = 1'h0;	// zeroWidthOperand.mlir:2:1, :32:11
  assign o_div2 = in1 / 1'h0;	// zeroWidthOperand.mlir:2:1, :32:11, :35:11
  assign o_dshl1 = 1'h0 << in1;	// zeroWidthOperand.mlir:2:1, :32:11, :38:12
  assign o_dshl2 = in1;	// zeroWidthOperand.mlir:2:1
  assign o_dshlw2 = in1;	// zeroWidthOperand.mlir:2:1
  assign o_dshr2 = in1;	// zeroWidthOperand.mlir:2:1
  assign o_and1 = 1'h0;	// zeroWidthOperand.mlir:2:1, :32:11
  assign o_and2 = 1'h0;	// zeroWidthOperand.mlir:2:1, :32:11
  assign o_or1 = in1;	// zeroWidthOperand.mlir:2:1
  assign o_or2 = in1;	// zeroWidthOperand.mlir:2:1
  assign o_xor1 = in1;	// zeroWidthOperand.mlir:2:1
  assign o_xor2 = in1;	// zeroWidthOperand.mlir:2:1
endmodule
```

### Comment by dtzSiFive — 2022-12-06T15:14:19Z

We can probably more generally replace zero-width with zero constants everywhere now in FIRRTL, instead of extending/adding rules for each operation.
