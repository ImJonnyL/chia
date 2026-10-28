firrtl.circuit "Test" {
  firrtl.module @Test(out %o: !firrtl.uint<1> sym @sym) {
    %w = firrtl.wire {annotations = [{class = "firrtl.transforms.DontTouchAnnotation"}]} : !firrtl.uint<1>
    %c0 = firrtl.constant 0 : !firrtl.uint<1>
    firrtl.matchingconnect %o, %c0 : !firrtl.uint<1>
  }
}
