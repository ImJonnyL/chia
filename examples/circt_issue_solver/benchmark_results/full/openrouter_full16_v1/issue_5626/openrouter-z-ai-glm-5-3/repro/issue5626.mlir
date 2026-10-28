// Issue #5626: dontTouch'd port gets inner sym __Test__DONTTOUCH__0__x,
// chosen without consulting the module namespace, colliding with the
// explicitly-named wire in the body.
firrtl.circuit "Test" {
  firrtl.module @Test(in %x : !firrtl.uint<1> [{class = "firrtl.transforms.DontTouchAnnotation"}]) {
    %0 = firrtl.wire sym @__Test__DONTTOUCH__0__x : !firrtl.uint<1>
    firrtl.connect %0, %x : !firrtl.uint<1>, !firrtl.uint<1>
  }
}
