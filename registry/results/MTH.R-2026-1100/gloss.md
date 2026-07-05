# MTH.R-2026-1100 — result `TLT.NonIdentifiability.latentKernel_iff_congruence` [T0]

`theorem` in `WMSpec.NonIdentifiability.KernelLumpability`; polarity universal. Discharges MTH.C-2026-1100. Kernel-verified (whole-theory replay); axioms ['propext', 'Classical.choice', 'Quot.sound'].

```
TLT.NonIdentifiability.latentKernel_iff_congruence : ∀ {S : Type u_1} {Z : Type u_2} (E : S → Z) (P : S → PMF S),
  (∃ Q, ∀ (s : S), Q (E s) = PMF.map E (P s)) ↔ ∀ (s₁ s₂ : S), E s₁ = E s₂ → PMF.map E (P s₁) = PMF.map E (P s₂)
```
