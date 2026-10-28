firrtl.circuit "Test" {
  firrtl.module @Test() {
    %w1 = firrtl.wire sym @sym : !firrtl.uint<1>
    %w2 = firrtl.wire {annotations = [{class = "firrtl.transforms.DontTouchAnnotation"}]} : !firrtl.uint<1>
  }
}
