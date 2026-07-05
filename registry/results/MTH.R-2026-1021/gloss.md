# MTH.R-2026-1021 — result `TLT.NonIdentifiability.quotientKernel_iff_congruence` [T0]

`theorem` in `WMSpec.NonIdentifiability.KernelLumpability`; polarity universal. Discharges MTH.C-2026-1021. Kernel-verified (whole-theory replay); axioms ['propext', 'Classical.choice', 'Quot.sound'].

```
TLT.NonIdentifiability.quotientKernel_iff_congruence : ∀ {S : Type u_1} (r : Setoid S) (P : S → PMF S),
  (∃ Q, ∀ (s : S), Q ⟦s⟧ = PMF.map (Quotient.mk r) (P s)) ↔
    ∀ (s₁ s₂ : S), r s₁ s₂ → PMF.map (Quotient.mk r) (P s₁) = PMF.map (Quotient.mk r) (P s₂)
```
