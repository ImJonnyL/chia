module {
  hw.module @demo(in %a : !hw.union<a: i1>, in %b : !hw.union<a: i1>, in %c : i1, out d : !hw.union<a: i1>) {
    %0 = comb.mux %c, %a, %b : !hw.union<a: i1>
    hw.output %0 : !hw.union<a: i1>
  }
}
