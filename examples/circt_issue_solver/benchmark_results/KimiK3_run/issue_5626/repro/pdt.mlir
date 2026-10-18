firrtl.circuit "Test" {
  firrtl.module @Test(in %a: !firrtl.uint<1> sym @__Test__DONTTOUCH__1__b, in %b: !firrtl.uint<1>) {
    %c0 = firrtl.constant 0 : !firrtl.uint<1>
  }
}
