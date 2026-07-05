# MTH.R-2026-1068 — result `WMSpec.sum_objective_invariant_of_components` [T0]

`theorem` in `WMSpec.ObjectiveInvariance`; polarity universal. Discharges MTH.C-2026-1068. Kernel-verified (whole-theory replay); axioms ['propext', 'Classical.choice', 'Quot.sound'].

```
WMSpec.sum_objective_invariant_of_components : ∀ {Θ : Type u_1} {X : Type u_2} {M : Type u_3} {k : ℕ} (C : Fin k → Θ → X → M → ℝ) (lam : Fin k → ℝ) {g : X → X},
  (∀ (j : Fin k), WMSpec.ObjectiveInvariant (C j) g) → WMSpec.ObjectiveInvariant (fun θ x m => ∑ j, lam j * C j θ x m) g
```
