[Thinking]
Write the PR description.

[Response]
[HW] Support hw.union in the aggregate-to-comb conversion

## Root cause

The `--aggregate-to-comb` pass converts aggregate (`hw.struct`/`hw.array`) operands of `comb` operations into flat integers by installing a type converter with a conversion for `hw::StructType` (and arrays, via other conversions). `hw::UnionType` was simply never given a conversion, so a `comb.mux` over union-typed operands failed to legalize, producing the reported error:

```
error: failed to legalize operation 'comb.mux' that was explicitly marked illegal
```

Muxes of `hw.struct` worked only because the struct case was handled.

## Fix

Add a conversion for `hw::UnionType` in the pass's type converter, mapping a union to an `IntegerType` of the union's full bit width (`hw::getBitWidth`). With this in place, the existing conversion machinery bitcasts union-typed operands to an integer covering the whole union bit pattern (including padding), performs the `comb` operation on that integer, and bitcasts the result back to the union type. `hw.union_extract`/`hw.union_create` operations remain legal around the mux since the bit layout is preserved by the bitcasts.

This is a two-line change mirroring the adjacent `StructType` conversion; no other behavior of the pass is affected.

## Testing

Repro from the issue (`comb.mux` over `!hw.union<a: i1>` operands) now converts cleanly to bitcast → `comb.mux` over `i1` → bitcast.

Added two new cases to `test/Dialect/HW/hw-aggregate-to-comb.mlir`:

- `@mux_union` — the minimal repro from the issue, a mux over single-field unions.
- `@mux_union_extract` — a mux over `!hw.union<foo: i3, bar: i16>` followed by `hw.union_extract`, verifying that the entire union bit pattern (i16, including padding) is muxed and that surrounding union ops stay legal.

Full lit suite across all CIRCT test directories: **1022 passed, 0 failed**.

No remaining risk known; the change is a strict superset of previous behavior (unions previously always failed to legalize under this pass).

## Existing-test changes

No existing tests were modified. Only new test cases were appended to `test/Dialect/HW/hw-aggregate-to-comb.mlir`.

Fixes #10571

[Usage]
{"total": 3963, "input": 2155, "output": 527, "reasoning": 1, "cache": {"write": 0, "read": 1280}, "cost_usd": 0.0009780265, "reason": "stop"}

[Result]
{"num_turns": 1, "input_tokens": 2155, "output_tokens": 527, "reasoning_tokens": 1, "cache_read": 1280, "cache_write": 0, "cost_usd": 0.0009780265}

