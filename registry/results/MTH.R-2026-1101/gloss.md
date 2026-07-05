# MTH.R-2026-1101 — result `TLT.NonIdentifiability.factorsThrough_of_dominated` [T0]

`theorem` in `WMSpec.NonIdentifiability.ReadoutCharacterization`; polarity universal. Discharges MTH.C-2026-1101. Kernel-verified (whole-theory replay); axioms ['propext', 'Classical.choice', 'Quot.sound'].

```
TLT.NonIdentifiability.factorsThrough_of_dominated : ∀ {S : Type u_1} {Z : Type u_2} [inst : PseudoMetricSpace Z] (E : S → Z) (T : S → ℝ) (L : NNReal),
  (∀ (s₁ s₂ : S), |T s₁ - T s₂| ≤ ↑L * dist (E s₁) (E s₂)) → Function.FactorsThrough T E
```
