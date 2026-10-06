# Notes: Stet data, step 1

## Problem URS

```
PROBLEM: Read a file of IEEE-754 binary32 words at elaboration time and produce
         a value the Lean kernel evaluates, so that claims about the data close
         by `decide`/`rfl` under the three standard axioms only.
KK (checked in Lean v4.31.0 source on 2026-10-06):
  - `include_str` (Lean/Elab/BuiltinTerm.lean:451, syntax in Init/Notation.lean:728)
    is the prior art: it resolves the path against the parent dir of the current
    .lean file, reads it with IO.FS.readFile, and fails elaboration if unreadable.
    No binary counterpart exists in core.
  - `IO.FS.readBinFile : FilePath → IO ByteArray` exists (Init/System/IO.lean:1211).
  - `ToExpr` instances exist for Nat, Int, UInt32, Option α, Array α (Array emits
    `List.toArray [...]`), in Lean/ToExpr.lean.
  - The kernel computes natively (GMP): Nat.add/sub/mul/div/mod/pow/gcd/beq/ble/
    land/lor/xor/shiftLeft/shiftRight. Decode must stay on these.
  - Fixture values in §6 were checked against hardware floats via Python's exact
    Fraction(float) (an independent oracle).
KK+ (checked against the v4.31.0 toolchain on 2026-10-07):
  - Core already defines `Dyadic` (Init/Data/Dyadic/Basic.lean): `zero | ofOdd n k
    (hn : n % 2 = 1)`, meaning n · 2^(−k), deriving DecidableEq, with add, mul, neg,
    ble, blt, toRat, trailingZeros and more. A root-level `structure Dyadic` would
    clash with it. Plain `decide` on its arithmetic works; that proof depends on
    propext and Quot.sound.
  - `Array.map` goes through `Array.mapM`, whose loop uses well-founded recursion
    (Init/Data/Array/Basic.lean:754). On a `List.toArray [...]` literal, plain
    `decide` gets stuck. `decide +kernel` succeeds but its proof depends on propext.
    `arr.toList.map f` succeeds under plain `decide` with no axioms.
  - A fuel of 64 for normalisation does not cover sums of float32 data:
    2^51 + (−2^−149) + 2^−149 leaves a mantissa of 2^200 at exponent −149, which
    needs 200 trailing zeros stripped.
KU (open, numbered; each has a step that answers it):
  1. Per-word kernel cost of decode32 + normalize.               → 1g
  2. Where `decide` stops scaling (expected: low thousands).     → 1g
  3. Whether `decide` or `rfl`-on-a-Bool is the faster closing form. → 1g
  4. Path resolution inside the bank's gate container (/work mount).  → step 2
  5. Endianness and header formats (.npy, .safetensors).           → after step 1
UK (check before claiming novelty; record findings in NOTES.md):
  - An existing binary `include` or IEEE decoder for Lean 4 (Batteries, Mathlib,
    TorchLean's IEEE32Exec, Zulip "include_bytes"). If one exists, reuse or cite it;
    the contribution is then the kernel-path design, not the decoder.
UU: Whether "data as a kernel term" is the right primitive at ML scale at all,
    versus a harness-transcript route. 1g's numbers make this askable.
γ / Γ / η: update at each STOP.
```

## Prior art (UK resolved, 2026-10-07)

Neither half of step 1 is new on its own; what is new is the kernel path between them.

- **Binary include:** Verso's `include_bin` (leanprover/verso, `src/verso-util/VersoUtil/BinFiles.lean`)
  resolves its path exactly as `include_str` does and returns a `ByteArray`. That `ByteArray` is
  produced by `Z85.decode` on a string literal in compiled code, not as a term the kernel evaluates.
  Lean core v4.31.0 has no binary include, and the v4.32.0 release notes add none.
- **IEEE-754 to dyadic:** TorchLean's `toDyadic?` (lean-dojo/TorchLean,
  `NN/Floats/IEEEExec/Exec32/Dyadic.lean`; vendored in noumenal-ai/design-lab) decodes
  binary32 bits to a dyadic. It works on `UInt32` bits. Its dyadic type `{sign, mant, exp}` is not
  normalised: it keeps the sign of zero and does not strip trailing zeros, so its structural `=` is
  not value equality. Its decoding lemmas (`toDyadic?_ofBits_mkBits_fin`) and its bridge to a
  round-on-ℝ float32 model use Mathlib.
- **Other elaborators that read binary files** (Lean-zh/protobuf descriptors, strata-org/Strata-DDM,
  bv_decide's LRAT reader) read inputs to the metaprogram. None of them makes the data a term for the
  kernel to evaluate.
- **Zulip:** a web search found no thread on `include_bytes` or `include_bin`. The archive is poorly
  indexed, so this is not conclusive.

Step 1 cites Verso and TorchLean. Its contribution is the path in between: an elaborator that only
transcribes words into numerals, a decoder the kernel evaluates on `Nat`, and a target type with one
form per value (core's `Dyadic`), so that claims about the data close by `decide` under the gate's
axioms.

## Decisions (Dhruv, 2026-10-07)

- Build on core's `Dyadic`. D3, D4, D5 and D7 come from core; `StetData/Dyadic.lean` documents them.
- Decode the data as `(f32bits% "…").toList.map decode32`, so `S` is a `List` and plain `decide`
  reduces it with no axioms.

## STOP 1 (2026-10-07): steps 1a–1c

Times:
- `lake build` of the skeleton: 3.6 s.
- `lake env lean StetData/Examples.lean` (19 checks, all `decide`): 0.46 s wall, 632 MB peak resident
  memory, most of it loading Init.

```
— object axis (γ) —
KK+ core's `Dyadic.ofIntWithPrec` normalises with fuel `i.natAbs` (Int.trailingZeros.aux), by
    structural recursion, so D4 holds for every input, and plain `decide` reduces it.
KK+ core proves `Dyadic.blt_iff_toRat` and `Dyadic.ble_iff_toRat`: `<` and `≤` agree with the order
    of ℚ. D5's "agreement is future work" is already done for ℚ; for ℝ it still needs Mathlib.
KK+ `List.sum` over `Dyadic` reduces under plain `decide` (D7's sum).
KK+ every check depends on exactly [propext, Quot.sound]; a wrong expected value makes `decide`
    fail ("proved that the proposition … is false").
KK+ Lean core v4.31.0 has no binary `include` (no include_bytes or include_bin; `readBinFile` is
    used only by bv_decide's LRAT reader) and no kernel-side IEEE decoder (`Float32` is opaque).
KU  decode32 is IEEE-correct beyond the 13 table-A rows → 1f (differential test).
KU-1/2/3 now concern core's Dyadic at scale: `ofIntWithPrec` and `+` on mantissas of ~280 bits,
    and `decide` vs `decide +kernel` vs `rfl` → 1g.
UK  prior art outside core (Batteries, Mathlib, TorchLean's IEEE32Exec, Zulip "include_bytes")
    → check before 1d, where the elaborator would claim novelty.
— agent axis (Γ) —
R-move (learning route): the dyadic representation is imported from core, not built.
M-move: the data shape is a List, because `Array.map` does not reduce under `decide`.
γ  decode32 agrees with all 13 hardware-checked table-A rows and the out-of-range case; the three
   KK+ facts about core above.
Γ  "does ≤ agree with the real order?" split into ℚ (answered by core) and ℝ (open; Mathlib).
η  low on the object so far: decode32 is a textbook decoder and the checks are computations on
   concrete values. Step 1's novelty is the elaborator and kernel path (1d) and the scaling
   measurements (1g), not reached yet.
```
