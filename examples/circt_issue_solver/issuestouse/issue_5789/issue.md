# Issue #5789: [FIRRTL][HW] Verify inner symbols on ports

- State: open
- Author: dtzSiFive
- Created: 2023-08-07T13:38:44Z
- Updated: 2023-12-04T19:26:02Z
- Labels: FIRRTL, HW
- URL: https://github.com/llvm/circt/issues/5789

## Body

InnerSymAttr verification (sanity checking the symbols) is performed for operations (InnerSymOpInterface's verify) defining inner symbols, but symbols on ports are not checked.

They are checked to not be duplicates as part of IST/IRN verification, but the attribute may just be wrong for the port, such as:

```mlir
firrtl.circuit "InvalidPortFieldSym" {
  firrtl.module @InvalidPortFieldSym(in %x : !firrtl.uint<1> sym [<@invalid,5,public>]) {
  }
}
```

Where `5` is not a valid fieldID for the port type.

This can cause crashes or other problems when passes attempt to reason about the target field within a type it doesn't make sense for.

## Comments (2)

### Comment by dtzSiFive — 2023-08-07T13:42:13Z

Not sure how to best tackle this.

This could be a verification on the IST trait, since that's the only non-InnerSymbolOpInterface entity defining inner symbols.  Possibly further lean on HWModuleLike for inner-symbols-on-ports support (providing mechanism to get the port type to check against).

A rework of "extra" symbols an IST op "has" (that aren't discoverable via walk) could be useful, abstract out these are reported/accessed/updated/resolved (including InnerSymTarget having the ability to represent the resolution of one of these).  For now just focusing on ports and HWModuleLike (or a more narrow interface) should work for now.

### Comment by dtzSiFive — 2023-12-04T19:26:01Z

Not colliding with other inner symbol names in the IST already works, but what's lacking is verifying the inner symbols are supported + make sense for the given port type (the sort of verification done by `InnerSymbolOpInterface::verify`), such as whether the per-field inner symbol is supported or reasonable.
