firrtl.circuit "Test" {
  firrtl.module @Sub(out %o: !firrtl.uint<1>) {
    %c0 = firrtl.constant 0 : !firrtl.uint<1>
    firrtl.matchingconnect %o, %c0 : !firrtl.uint<1>
  }
  firrtl.module @Test(out %o: !firrtl.uint<1> sym @sym) {
    %inst_o = firrtl.instance sub @Sub(out o: !firrtl.uint<1>)
    firrtl.matchingconnect %o, %inst_o : !firrtl.uint<1>
    %w = firrtl.wire {annotations = [{class = "firrtl.transforms.DontTouchAnnotation"}]} : !firrtl.uint<1>
  }
}
