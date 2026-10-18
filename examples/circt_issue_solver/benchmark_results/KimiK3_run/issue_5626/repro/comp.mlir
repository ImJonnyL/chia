firrtl.circuit "Test" {
  firrtl.module @Companion() {
    %w = firrtl.wire {annotations = [{class = "firrtl.transforms.DontTouchAnnotation"}]} : !firrtl.uint<1>
  }
  firrtl.module @Test() {
    %w1 = firrtl.wire sym @sym : !firrtl.uint<1>
    firrtl.instance comp @Companion()
  }
}
