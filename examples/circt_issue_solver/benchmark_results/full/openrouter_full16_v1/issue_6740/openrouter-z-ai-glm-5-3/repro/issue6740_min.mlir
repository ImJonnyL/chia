// Minimal trigger for issue #6740:
// [FIRRTLToHW] Conversion failure of invalidated wire of clock type.
//
// Lowering `firrtl.invalidvalue` of clock type to HW builds an `hw.bitcast`
// from an `i1` zero constant to `!seq.clock`, which the `hw.bitcast` verifier
// rejects ("result #0 must be Type wherein the bitwidth in hardware is known").
// Neither the wire nor the connect from the original report are needed: the
// bare invalid value is what produces the illegal op.
firrtl.circuit "Foo" {
  firrtl.module @Foo() {
    %invalid = firrtl.invalidvalue : !firrtl.clock
  }
}
