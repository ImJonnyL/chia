firrtl.circuit "ForceNameTop" {
  hw.hierpath private @nla_1 [@ForceNameTop::@sym_foo, @ForceNameSubmodule]
  hw.hierpath private @nla_2 [@ForceNameTop::@sym_bar, @ForceNameSubmodule]
  firrtl.module private @ForceNameSubmodule() attributes {annotations = [
    {circt.nonlocal = @nla_1,
     class = "chisel3.util.experimental.ForceNameAnnotation", name = "Foo"},
    {circt.nonlocal = @nla_2,
     class = "chisel3.util.experimental.ForceNameAnnotation", name = "Foo"}
  ]} {}
  firrtl.module @ForceNameTop() {
    firrtl.instance foo sym @sym_foo @ForceNameSubmodule()
    firrtl.instance bar sym @sym_bar @ForceNameSubmodule()
  }
}
