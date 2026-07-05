# MTH.R-2026-1096 — result `TLT.NonIdentifiability.latentMap_iff_congruence` [T0]

`theorem` in `WMSpec.NonIdentifiability.KernelLumpability`; polarity universal. Discharges MTH.C-2026-1096. Kernel-verified (whole-theory replay); axioms ['propext', 'Classical.choice', 'Quot.sound'].

```
TLT.NonIdentifiability.latentMap_iff_congruence : ∀ {S : Type u_1} {Z : Type u_2} (E : S → Z) (f : S → S),
  (∃ g, ∀ (s : S), g (E s) = E (f s)) ↔ ∀ (s₁ s₂ : S), E s₁ = E s₂ → E (f s₁) = E (f s₂)
```
