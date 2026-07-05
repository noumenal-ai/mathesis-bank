# MTH.R-2026-1009 — result `TLT.NonIdentifiability.IsConforming.refines` [T0]

`theorem` in `WMSpec.NonIdentifiability.ForcingTheorem`; polarity universal. Discharges MTH.C-2026-1009. Kernel-verified (whole-theory replay); axioms ['propext', 'Classical.choice', 'Quot.sound'].

```
TLT.NonIdentifiability.IsConforming.refines : ∀ {S : Type u_1} {ι : Type u_2} {W : ι → Type u_3} {T : (i : ι) → S → W i} {P : S → PMF S} {r : Setoid S},
  TLT.NonIdentifiability.IsConforming T P r → ∀ (i : ι) ⦃s₁ s₂ : S⦄, r s₁ s₂ → T i s₁ = T i s₂
```
