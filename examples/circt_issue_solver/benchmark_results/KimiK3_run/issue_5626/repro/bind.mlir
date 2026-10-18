firrtl.circuit "Test" {
  firrtl.module @Sub() attributes {annotations = [{class = "firrtl.passes.LowerToBindAnnotation"}]} {}
  firrtl.module @Test() {
    %w1 = firrtl.wire sym @sym : !firrtl.uint<1>
    firrtl.instance sub @Sub()
  }
}
