# MTH.R-2026-1164 — result `WMSpec.pred_invariant_of_matched` [T0]

`theorem` in `WMSpec.MatchedObjective`; polarity universal. Discharges MTH.C-2026-1164. Kernel-verified (whole-theory replay); axioms ['propext', 'Classical.choice', 'Quot.sound'].

```
WMSpec.pred_invariant_of_matched : ∀ {Θ : Type u_1} {X : Type u_2} {k : ℕ} {ι : Type u_4} {Lpred : Θ → X → List ι → ℕ} {G : Fin k → X → ℝ}
  {lam : Fin k → ℝ} {g : X → X},
  (∀ (θ : Θ) (x : X) (I₁ I₂ : List ι), Lpred θ x (I₁ ++ I₂) = Lpred θ x I₁ + Lpred θ x I₂) →
    WMSpec.ObjectiveInvariant (WMSpec.matchedObjective Lpred G lam) g → WMSpec.ObjectiveInvariant Lpred g
```
