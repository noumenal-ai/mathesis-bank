# MTH.R-2026-1138 — result `TLT.NonIdentifiability.IsConforming.congr` [T0]

`theorem` in `WMSpec.NonIdentifiability.ForcingTheorem`; polarity universal. Discharges MTH.C-2026-1138. Kernel-verified (whole-theory replay); axioms ['propext', 'Classical.choice', 'Quot.sound'].

```
TLT.NonIdentifiability.IsConforming.congr : ∀ {S : Type u_1} {ι : Type u_2} {W : ι → Type u_3} {T : (i : ι) → S → W i} {P : S → PMF S} {r : Setoid S},
  TLT.NonIdentifiability.IsConforming T P r →
    ∀ ⦃s₁ s₂ : S⦄, r s₁ s₂ → PMF.map (Quotient.mk r) (P s₁) = PMF.map (Quotient.mk r) (P s₂)
```
