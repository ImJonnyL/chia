firrtl.circuit "Test" {
  firrtl.module @Test(in %clock: !firrtl.clock, in %d: !firrtl.uint<1>) {
    %w1 = firrtl.wire sym @sym : !firrtl.uint<1>
    %r = firrtl.reg sym @sym %clock {annotations = [{class = "firrtl.transforms.DontTouchAnnotation"}]} : !firrtl.clock, !firrtl.uint<1>
  }
}
