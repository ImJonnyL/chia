# Issue #10104: [FIRRTL] ExpandWhens dominance error with multiple layerblocks and implication intrinsics

- State: open
- Author: fabianschuiki
- Created: 2026-04-02T18:40:52Z
- Updated: 2026-04-02T18:40:52Z
- Labels: FIRRTL
- URL: https://github.com/llvm/circt/issues/10104

## Body

This one feels extremely specific and peculiar:
```mlir
firrtl.circuit "Foo" {
  firrtl.layer @Bar bind attributes {sym_visibility = "private"} {
  }
  firrtl.module @Foo() {
    %c0_ui1 = firrtl.constant 0 : !firrtl.uint<1>
    firrtl.when %c0_ui1 : !firrtl.uint<1> {
      firrtl.layerblock @Bar {
        %0 = firrtl.int.ltl.implication %c0_ui1, %c0_ui1 : (!firrtl.uint<1>, !firrtl.uint<1>) -> !firrtl.uint<1>
        firrtl.int.verif.assert %0, %c0_ui1 : !firrtl.uint<1>, !firrtl.uint<1>
      }
      firrtl.layerblock @Bar {
        %0 = firrtl.int.ltl.implication %c0_ui1, %c0_ui1 : (!firrtl.uint<1>, !firrtl.uint<1>) -> !firrtl.uint<1>
        firrtl.int.verif.assert %0, %c0_ui1 : !firrtl.uint<1>, !firrtl.uint<1>
      }
    }
  }
}
```

Running this through `firtool` or `circt-opt --pass-pipeline="builtin.module(firrtl.circuit(firrtl.module(firrtl-expand-whens)))"` will produce a dominance error:
```
reduced-3.mlir:13:9: error: operand #0 does not dominate this use
        firrtl.int.verif.assert %0, %c0_ui1 : !firrtl.uint<1>, !firrtl.uint<1>
        ^
reduced-3.mlir:13:9: note: see current operation: "firrtl.int.verif.assert"(%4, %0) : (!firrtl.uint<1>, !firrtl.uint<1>) -> ()
reduced-3.mlir:8:14: note: operand defined here (op is neither in a parent nor in a child region)
        %0 = firrtl.int.ltl.implication %c0_ui1, %c0_ui1 : (!firrtl.uint<1>, !firrtl.uint<1>) -> !firrtl.uint<1>
             ^
```
This only happens if there are two separate `firrtl.laterblock`s containing that implication intrinsic. No idea what's going on there.
