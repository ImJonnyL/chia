# Issue #7127: [FIRRTL][DropConst] Preserve alias?

- State: open
- Author: dtzSiFive
- Created: 2024-06-04T19:30:04Z
- Updated: 2024-06-04T19:30:05Z
- Labels: FIRRTL
- URL: https://github.com/llvm/circt/issues/7127

## Body

Consider:
```
FIRRTL version 4.0.0

circuit ConstAlias:
  type X = { a: const UInt<1> }
  public module ConstAlias:
    input x : X
    output y : X
    connect y, x
```

Run like:
`firtool const_alias.fir -preserve-aggregate=all --scalarize-public-modules=false`

Dropping "const" from the example above (modify the FIRRTL's text) and the type alias makes it to the output.

Arguably the type name shouldn't be preserved if mutating it (dropping const), but since that's unrepresentable thereafter (as well as in the lowered/output) there seems to be a reasonable case for keeping the type alias but without the const bits.

Low-priority as I don't think `const` is used but FYI.
