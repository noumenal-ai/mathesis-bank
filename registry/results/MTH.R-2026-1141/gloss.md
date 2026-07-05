# MTH.R-2026-1141 — result `WMSpec.components_invariant_of_sum_objective` [T0]

`theorem` in `WMSpec.ObjectiveInvariance`; polarity universal. Discharges MTH.C-2026-1141. Kernel-verified (whole-theory replay); axioms ['propext', 'Classical.choice', 'Quot.sound'].

```
WMSpec.components_invariant_of_sum_objective : ∀ {Θ : Type u_1} {X : Type u_2} {M : Type u_3} {k : ℕ} (C : Fin k → Θ → X → M → ℝ) (lam : Fin k → ℝ) {g : X → X},
  (∀ (j : Fin k), 0 < lam j) →
    WMSpec.MonotoneDeviation C g →
      WMSpec.ObjectiveInvariant (fun θ x m => ∑ j, lam j * C j θ x m) g →
        ∀ (j : Fin k), WMSpec.ObjectiveInvariant (C j) g
```
