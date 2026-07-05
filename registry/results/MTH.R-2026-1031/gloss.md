# MTH.R-2026-1031 — result `WMSpec.Flow.FlowWorldModel.mk.sizeOf_spec` [T0]

`theorem` in `WMSpec.Flow.FlowArchitecture`; polarity universal. Discharges MTH.C-2026-1031. Kernel-verified (whole-theory replay); axioms [].

```
WMSpec.Flow.FlowWorldModel.mk.sizeOf_spec : ∀ {T : Type u_1} {S : Type u_2} {Z : Type u_3} [inst : AddMonoid T] [inst_1 : AddAction T S] [inst_2 : SizeOf T]
  [inst_3 : SizeOf S] [inst_4 : SizeOf Z] (encode : S → Z) (horizons : AddSubmonoid T) (step : T → Z → Z)
  (commutes : ∀ t ∈ horizons, ∀ (s : S), step t (encode s) = encode (t +ᵥ s)),
  sizeOf { encode := encode, horizons := horizons, step := step, commutes := commutes } = 1 + sizeOf horizons
```
