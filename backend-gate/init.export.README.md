# `init.export` — the trusted logical-core reference

`init.export` is a bank-owned, version-controlled reference environment holding the genuine
definitions of the logical-core constants (`Iff`, `Eq`, `False`, `And`, `Or`, `Not`, `Exists`,
`HEq`, `propext`, `Classical.choice`, `Decidable`, `Bool`, quotient primitives, …). The gate
(`mathesis-adjudicate`) loads it when `MATHESIS_INIT_EXPORT` points here and **rejects any candidate
that redefines one of these constants** — the "fake-connective" soundness attack, where a `prelude`
deposit keeps a genuine-typed `propext` but fakes the connectives its type names (`Iff`/`Eq`) to
derive `True = False`. The name-only axiom whitelist and the axiom type-binding do not catch that;
comparing every reached constant that also exists here does (`CheckProof.trustedMatches`).

## Why it works (and why the obvious alternative does not)

Both sides of the comparison are **lean4export representation, parsed the same way** (`loadFrozenText`).
lean4export is deterministic: the same genuine constant exports to a byte-identical parsed
`ConstantInfo` in any run, so a genuine deposit's `Iff` matches this file's `Iff` exactly, and only a
*real* redefinition diverges. Comparing against a freshly `importModules`-loaded `Init` env does **not**
work — that representation differs from lean4export's, so it falsely rejected ~90% of the genuine
corpus. This like-with-like comparison keeps the full corpus clean while rejecting the fakes.

## How it was generated (reproducible / auditable)

The multi-decl `Init` export panics in this lean4export, so the closure is pulled through a single
anchor declaration whose type + proof reach every logical-core constant. See
[`init.export.anchor.lean`](init.export.anchor.lean). To regenerate:

```
# in a checkout with Eidometry.Thesis (or any Mathlib-rich module) built at leanprover/lean4:v4.31.0
lean --root=<dir> init.export.anchor.lean -o <dir>/TrustAnchor.olean
env LEAN_PATH=<dir> lean4export TrustAnchor -- Mathesis.trustAnchor > init.export
```

Content is 59 constants. Audit it by parsing and checking the genuine primitives are present with
their expected types (`Iff`, `Eq`, `False`, `propext`, …).

Note: `Quot.sound` is not in this file's closure; it is an axiom already covered by the gate's axiom
name→type binding, so a spoofed `Quot.sound` is rejected there.
