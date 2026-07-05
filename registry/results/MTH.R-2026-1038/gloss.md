# MTH.R-2026-1038 — result `WMSpec.matchedObjective_invariant_of_components` [T0]

`theorem` in `WMSpec.MatchedObjective`; polarity universal. Discharges MTH.C-2026-1038. Kernel-verified (whole-theory replay); axioms ['propext', 'Classical.choice', 'Quot.sound'].

```
WMSpec.matchedObjective_invariant_of_components : ∀ {Θ : Type u_1} {X : Type u_2} {M : Type u_3} {k : ℕ} {Lpred : Θ → X → M → ℕ} {G : Fin k → X → ℝ} {lam : Fin k → ℝ}
  {g : X → X},
  WMSpec.ObjectiveInvariant Lpred g →
    (∀ (j : Fin k) (x : X), G j (g x) = G j x) → WMSpec.ObjectiveInvariant (WMSpec.matchedObjective Lpred G lam) g
```
