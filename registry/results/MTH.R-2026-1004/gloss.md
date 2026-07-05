# MTH.R-2026-1004 — result `TLT.NonIdentifiability.lipschitz_readout_iff` [T0]

`theorem` in `WMSpec.NonIdentifiability.ReadoutCharacterization`; polarity universal. Discharges MTH.C-2026-1004. Kernel-verified (whole-theory replay); axioms ['propext', 'Classical.choice', 'Quot.sound'].

```
TLT.NonIdentifiability.lipschitz_readout_iff : ∀ {S : Type u_1} {Z : Type u_2} [inst : PseudoMetricSpace Z] (E : S → Z) (T : S → ℝ) (L : NNReal),
  (∃ g, LipschitzWith L g ∧ ∀ (s : S), T s = g (E s)) ↔ ∀ (s₁ s₂ : S), |T s₁ - T s₂| ≤ ↑L * dist (E s₁) (E s₂)
```
