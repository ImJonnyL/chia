// The scenario exactly as reported in issue #6740: an invalidated wire of
// clock type.  Adapted to this tree (firtool-1.148.0): the main module must
// be public, and the FIRRTL dialect here provides `firrtl.connect` /
// `firrtl.matchingconnect` instead of the report's `firrtl.strictconnect`
// (both fail identically; the failure happens while lowering the invalid
// value itself, before the connect is even considered).
firrtl.circuit "Foo" {
  firrtl.module @Foo() {
    %a = firrtl.wire : !firrtl.clock
    %b = firrtl.invalidvalue : !firrtl.clock
    firrtl.connect %a, %b : !firrtl.clock
  }
}
