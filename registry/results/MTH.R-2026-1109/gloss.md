# MTH.R-2026-1109 — result `WMSpec.guards_invariant_of_matched` [T0]

`theorem` in `WMSpec.MatchedObjective`; polarity universal. Discharges MTH.C-2026-1109. Kernel-verified (whole-theory replay); axioms ['propext', 'Classical.choice', 'Quot.sound'].

```
WMSpec.guards_invariant_of_matched : ∀ {Θ : Type u_1} {X : Type u_2} {k : ℕ} {ι : Type u_4} {Lpred : Θ → X → List ι → ℕ} {G : Fin k → X → ℝ}
  {lam : Fin k → ℝ} {g : X → X},
  (∀ (θ : Θ) (x : X) (I₁ I₂ : List ι), Lpred θ x (I₁ ++ I₂) = Lpred θ x I₁ + Lpred θ x I₂) →
    (∀ (j : Fin k), 0 < lam j) →
      (∀ (j : Fin k) (x : X), G j x ≤ G j (g x)) →
        WMSpec.ObjectiveInvariant (WMSpec.matchedObjective Lpred G lam) g →
          ∀ (θ₀ : Θ) (j : Fin k) (x : X), G j (g x) = G j x
```
