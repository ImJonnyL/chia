firrtl.circuit "Foo" {
  firrtl.module @Foo() {
    %a = firrtl.wire : !firrtl.clock
    %b = firrtl.invalidvalue : !firrtl.clock
    firrtl.connect %a, %b : !firrtl.clock, !firrtl.clock
  }
}
