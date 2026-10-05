# Issue #6740: [FIRRTLToHW] Conversion failure of invalidated wire of clock type

- State: open
- Author: seldridge
- Created: 2024-02-24T01:25:25Z
- Updated: 2024-02-24T01:57:46Z
- Labels: good first issue, FIRRTL, HW
- URL: https://github.com/llvm/circt/issues/6740

## Body

The following fails verification after `circt-opt -lower-firrtl-to-hw`:

``` mlir
firrtl.circuit "Foo" {
  firrtl.module private @Foo() {
    %a = firrtl.wire : !firrtl.clock
    %b = firrtl.invalidvalue : !firrtl.clock
    firrtl.strictconnect %a, %b : !firrtl.clock
  }
}
```

This fails with:

```
Titan.mlir:4:10: error: 'hw.bitcast' op result #0 must be Type wherein the bitwidth in hardware is known, but got '!seq.clock'
    %b = firrtl.invalidvalue : !firrtl.clock
         ^
Titan.mlir:4:10: note: see current operation: %2 = "hw.bitcast"(%0) : (i1) -> !seq.clock
```

The illegal MLIR being produced is:

``` mlir
"builtin.module"() ({
  "hw.module"() ({
    %0 = "hw.constant"() {value = false} : () -> i1
    %1 = "hw.wire"(%2) {name = "a"} : (!seq.clock) -> !seq.clock
    %2 = "hw.bitcast"(%0) : (i1) -> !seq.clock
    "hw.output"() : () -> ()
  }) {comment = "", module_type = !hw.modty<>, parameters = [], per_port_attrs = [], result_locs = [], sym_name = "Foo", sym_visibility = "private"} : () -> ()
}) : () -> ()
```

## Comments (1)

### Comment by seldridge — 2024-02-24T01:28:51Z

While LowerToHW shouldn't fail, it is also unexpected to see an invalid value at LowerToHW. This should have been converted to a special constant zero during SFCCompat, but it was not. 🤔 
