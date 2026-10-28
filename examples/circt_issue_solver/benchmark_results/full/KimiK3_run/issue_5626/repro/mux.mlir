firrtl.circuit "Test" {
  firrtl.module @Test(in %sel: !firrtl.uint<1>, in %a: !firrtl.uint<8>, in %b: !firrtl.uint<8>, out %o: !firrtl.uint<8>) {
    %w1 = firrtl.wire sym @sym : !firrtl.uint<1>
    %m = firrtl.mux(%sel, %a, %b) : (!firrtl.uint<1>, !firrtl.uint<8>, !firrtl.uint<8>) -> !firrtl.uint<8>
    firrtl.matchingconnect %o, %m : !firrtl.uint<8>
  }
}
