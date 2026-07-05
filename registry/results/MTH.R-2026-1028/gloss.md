# MTH.R-2026-1028 — result `TLT.NonIdentifiability.IsWorldModel.separates` [T0]

`theorem` in `WMSpec.NonIdentifiability.ForcingTheorem`; polarity universal. Discharges MTH.C-2026-1028. Kernel-verified (whole-theory replay); axioms ['propext', 'Classical.choice', 'Quot.sound'].

```
TLT.NonIdentifiability.IsWorldModel.separates : ∀ {S : Type u_1} {ι : Type u_2} {W : ι → Type u_3} {T : (i : ι) → S → W i} {P : S → PMF S} {Z : Type u_4} {E : S → Z},
  TLT.NonIdentifiability.IsWorldModel T P E → ∀ (i : ι) ⦃s₁ s₂ : S⦄, E s₁ = E s₂ → T i s₁ = T i s₂
```
