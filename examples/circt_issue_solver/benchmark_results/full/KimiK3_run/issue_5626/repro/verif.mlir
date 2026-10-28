firrtl.circuit "Test" {
  firrtl.module @Test(in %clock: !firrtl.clock, in %a: !firrtl.uint<1>) {
    %w1 = firrtl.wire sym @sym : !firrtl.uint<1>
    firrtl.assert %clock, %a, %a, "msg" : !firrtl.clock, !firrtl.uint<1>, !firrtl.uint<1> {annotations = [{class = "firrtl.transforms.DontTouchAnnotation"}]}
  }
}
