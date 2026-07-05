# MTH.R-2026-1019 — result `WMSpec.matched_invariance_characterization` [T0]

`theorem` in `WMSpec.MatchedObjective`; polarity universal. Discharges MTH.C-2026-1019. Kernel-verified (whole-theory replay); axioms ['propext', 'Classical.choice', 'Quot.sound'].

```
WMSpec.matched_invariance_characterization : ∀ {Θ : Type u_1} {X : Type u_2} {k : ℕ} {ι : Type u_4} {Lpred : Θ → X → List ι → ℕ} {G : Fin k → X → ℝ}
  {lam : Fin k → ℝ} {g : X → X},
  (∀ (θ : Θ) (x : X) (I₁ I₂ : List ι), Lpred θ x (I₁ ++ I₂) = Lpred θ x I₁ + Lpred θ x I₂) →
    (∀ (j : Fin k), 0 < lam j) →
      (∀ (j : Fin k) (x : X), G j x ≤ G j (g x)) →
        ∀ (θ₀ : Θ),
          WMSpec.ObjectiveInvariant (WMSpec.matchedObjective Lpred G lam) g ↔
            WMSpec.ObjectiveInvariant Lpred g ∧ ∀ (j : Fin k) (x : X), G j (g x) = G j x
```
