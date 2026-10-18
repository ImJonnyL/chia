firrtl.circuit "Test" {
  firrtl.module @Test() {
    %w1 = firrtl.wire sym [<@sym,1,public>] : !firrtl.vector<uint<1>, 2>
    %w2 = firrtl.wire {annotations = [{class = "firrtl.transforms.DontTouchAnnotation"}]} : !firrtl.vector<uint<1>, 2>
  }
}
