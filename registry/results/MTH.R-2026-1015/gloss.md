# MTH.R-2026-1015 — result `WMSpec.approx_lipschitz_ineq` [T0]

`theorem` in `WMSpec.EnergyNonRecovery`; polarity universal. Discharges MTH.C-2026-1015. Kernel-verified (whole-theory replay); axioms ['propext', 'Classical.choice', 'Quot.sound'].

```
WMSpec.approx_lipschitz_ineq : ∀ {S : Type u_1} {Z : Type u_2} [inst : PseudoMetricSpace Z] (E : S → Z) (T : S → ℝ) (L : NNReal) (g : Z → ℝ),
  LipschitzWith L g → (∀ (s : S), T s = g (E s)) → ∀ (s₁ s₂ : S), |T s₁ - T s₂| ≤ ↑L * dist (E s₁) (E s₂)
```
