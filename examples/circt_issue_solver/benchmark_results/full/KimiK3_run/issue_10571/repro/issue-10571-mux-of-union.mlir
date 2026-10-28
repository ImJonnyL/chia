// RUN: circt-opt %s --hw-aggregate-to-comb | FileCheck %s

// Regression test for https://github.com/llvm/circt/issues/10571
// HWAggregateToComb must legalize comb.mux over !hw.union types (it already
// handles !hw.struct and !hw.array).

// CHECK-LABEL: @demo
hw.module @demo(in %a : !hw.union<a: i1>, in %b : !hw.union<a: i1>, in %c : i1, out d : !hw.union<a: i1>) {
  // The pass should lower the union mux via hw.bitcast (or per-field
  // union_extract/union_create) and must not leave any comb.mux on a
  // !hw.union behind.
  // CHECK-NOT: comb.mux {{.*}}: !hw.union
  // CHECK: hw.output
  %0 = comb.mux %c, %a, %b : !hw.union<a: i1>
  hw.output %0 : !hw.union<a: i1>
}
