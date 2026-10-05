# Issue #4649: [FIRRTL] ProbeOp + LowerTypes crash on non-passive type

- State: open
- Author: dtzSiFive
- Created: 2023-02-10T19:30:29Z
- Updated: 2023-02-10T19:30:29Z
- URL: https://github.com/llvm/circt/issues/4649

## Body

LowerTypes crashes with ProbeOp and probably for any unhandled operation that uses non-passive types:

```
$ firtool probe_flips.mlir --mlir-print-ir-before=firrtl-lower-types --mlir-print-ir-after-failure                                                                                                                                                                                                                                            
// -----// IR Dump Before LowerFIRRTLTypes (firrtl-lower-types) //----- //
firrtl.circuit "ProbeFlips" {
  firrtl.module @ProbeFlips(in %bundle: !firrtl.bundle<a: uint<1>, b flip: uint<2>>) {
    firrtl.probe @baz, %bundle : !firrtl.bundle<a: uint<1>, b flip: uint<2>>
    %0 = firrtl.subfield %bundle[b] : !firrtl.bundle<a: uint<1>, b flip: uint<2>>
    %c0_ui2 = firrtl.constant 0 : !firrtl.uint<2>
    firrtl.strictconnect %0, %c0_ui2 : !firrtl.uint<2>
  }
}

probe_flips.mlir:3:5: error: bitwidth cannot be determined for result type '!firrtl.bundle<a: uint<1>, b flip: uint<2>>'
    firrtl.probe @baz, %bundle: !firrtl.bundle<a: uint<1>, b flip: uint<2>>
    ^
probe_flips.mlir:3:5: note: see current operation: %1 = "firrtl.bitcast"(%0) : (!firrtl.uint<3>) -> !firrtl.bundle<a: uint<1>, b flip: uint<2>>
// -----// IR Dump After LowerFIRRTLTypes Failed (firrtl-lower-types) //----- //
"firrtl.circuit"() ({
  "firrtl.module"() ({
  ^bb0(%arg0: !firrtl.uint<1>, %arg1: !firrtl.uint<2>):
    %0 = "firrtl.cat"(%arg0, %arg1) : (!firrtl.uint<1>, !firrtl.uint<2>) -> !firrtl.uint<3>
    %1 = "firrtl.bitcast"(%0) : (!firrtl.uint<3>) -> !firrtl.bundle<a: uint<1>, b flip: uint<2>>
    "firrtl.probe"(%1) {inner_sym = "baz"} : (!firrtl.bundle<a: uint<1>, b flip: uint<2>>) -> ()
    %2 = "firrtl.constant"() {value = 0 : ui2} : () -> !firrtl.uint<2>
    "firrtl.strictconnect"(%arg1, %2) : (!firrtl.uint<2>, !firrtl.uint<2>) -> ()
  }) {annotations = [], parameters = [], portAnnotations = [[], []], portDirections = -2 : i2, portLocations = [loc("probe_flips.mlir":2:32), loc("probe_flips.mlir":2:32)], portNames = ["bundle_a", "bundle_b"], portSyms = [], portTypes = [!firrtl.uint<1>, !firrtl.uint<2>], sym_name = "ProbeFlips"} : () -> ()
}) {annotations = [], name = "ProbeFlips"} : () -> ()
```

cc #4648 re:cast to non-passive type (with that PR, error changes to complaining about cast result type not being passive).

Depending what we want ProbeOp for, it can be thought of as naming a set of values (for use as source-flow, in say a bind), in which case converting to passive seems reasonable -- perhaps so much so we change probe to take only passive inputs regardless of aggregates/type-lowering.

Regardless of what we want to do with ProbeOp (which is presently entirely not used from user input), this should be handled with a nicer error if we can't handle it in `LowerTypes`.
(e.g., foreign operations we can't rewrite to passive or expand to the scalar elements of the aggregate).
