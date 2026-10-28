// Minimal reproduction for https://github.com/llvm/circt/issues/7388
//
// Lowering a `firrtl.enumcreate` of a field with a zero-width payload crashes
// in LowerToHW: the enum is a "data enum" (it has a non-zero-width field), so
// it lowers to `!hw.struct<tag, body: !hw.union<...>>`.  The zero-width input
// value lowers to *nothing* (a null Value), which is then passed straight into
// `hw::UnionCreateOp::create` and dereferenced while building the op's
// operands -> segfault.
firrtl.circuit "MatchInline" {
  firrtl.module @MatchInline(out %o: !firrtl.enum<Some: uint<8>, None: uint<0>>) {
    %c0_ui0 = firrtl.constant 0 : !firrtl.uint<0>
    %1 = firrtl.enumcreate None(%c0_ui0) : (!firrtl.uint<0>) -> !firrtl.enum<Some: uint<8>, None: uint<0>>
    firrtl.matchingconnect %o, %1 : !firrtl.enum<Some: uint<8>, None: uint<0>>
  }
}
