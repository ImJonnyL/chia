FIRRTL version 5.1.0
circuit Foo: %[[
  {
    "class": "sifive.enterprise.firrtl.MarkDUTAnnotation",
    "target": "~|Bar"
  },
  {
    "class": "sifive.enterprise.firrtl.InjectDUTHierarchyAnnotation",
    "name": "logic"
  }
]]

  extmodule Bar:
    output a: UInt<1>

    defname = Bar

  public module Foo:
    output a: UInt<1>

    inst bar of Bar
    connect a, bar.a
