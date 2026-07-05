# MTH.R-2026-1159 — result `TLT.NonIdentifiability.no_lipschitz_readout_iff` [T0]

`theorem` in `WMSpec.NonIdentifiability.ReadoutCharacterization`; polarity existential. Discharges MTH.C-2026-1159. Kernel-verified (whole-theory replay); axioms ['propext', 'Classical.choice', 'Quot.sound'].

```
TLT.NonIdentifiability.no_lipschitz_readout_iff : ∀ {S : Type u_1} {Z : Type u_2} [inst : PseudoMetricSpace Z] (E : S → Z) (T : S → ℝ) (L : NNReal),
  (¬∃ g, LipschitzWith L g ∧ ∀ (s : S), T s = g (E s)) ↔ ∃ s₁ s₂, ↑L * dist (E s₁) (E s₂) < |T s₁ - T s₂|
```
