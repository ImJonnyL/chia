# Issue #10571: [HWAggregateToComb] Mux of unions

- State: open
- Author: mndstrmr
- Created: 2026-06-01T14:37:45Z
- Updated: 2026-06-01T18:49:10Z
- URL: https://github.com/llvm/circt/issues/10571

## Body

Consider the following `minimal.mlir` (compiled from SV):
```
module {
  hw.module @demo(in %a : !hw.union<a: i1>, in %b : !hw.union<a: i1>, in %c : i1, out d : !hw.union<a: i1>) {
    %0 = comb.mux %c, %a, %b : !hw.union<a: i1>
    hw.output %0 : !hw.union<a: i1>
  }
}
```

`circt-opt minimal.mlir --aggregate-to-comb` fails with
```
minimal.mlir:3:10: error: failed to legalize operation 'comb.mux' that was explicitly marked illegal: %0 = "comb.mux"(%arg2, %arg0, %arg1) : (i1, !hw.union<a: i1>, !hw.union<a: i1>) -> !hw.union<a: i1>
    %0 = comb.mux %c, %a, %b : !hw.union<a: i1>
```

Muxes of `hw.struct` work fine.

If this is a bug/unimplemented feature then I'm happy to try to implement the fix myself, though some guidance on where to start would be great! If it's not a bug, advice on what I should be doing differently would be great also!

Thanks!

## Comments (1)

### Comment by uenoku — 2026-06-01T18:49:09Z

It's not simply implemented 👍 Please feel free to implement. Basically what you can do is to insert bitacst hw.union, and construct  union_extract/create based on the bit layout. 
