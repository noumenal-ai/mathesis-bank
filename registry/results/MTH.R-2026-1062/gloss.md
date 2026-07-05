# MTH.R-2026-1062 — result `WMSpec.jepaMatched_invariance_characterization` [T0]

`theorem` in `WMSpec.MatchedObjective`; polarity universal. Discharges MTH.C-2026-1062. Kernel-verified (whole-theory replay); axioms ['propext', 'Classical.choice', 'Quot.sound'].

```
WMSpec.jepaMatched_invariance_characterization : ∀ {k n : ℕ} {Context Target Pred : Type} {G : Fin k → Context × (Fin n → Target) → ℝ} {lam : Fin k → ℝ}
  {g : Context × (Fin n → Target) → Context × (Fin n → Target)},
  (∀ (j : Fin k), 0 < lam j) →
    (∀ (j : Fin k) (x : Context × (Fin n → Target)), G j x ≤ G j (g x)) →
      ∀ (θ₀ : (Context → Fin n → Pred) × (Target → Pred → ℕ)),
        WMSpec.ObjectiveInvariant (WMSpec.jepaMatched n Context Target Pred G lam) g ↔
          WMSpec.ObjectiveInvariant (WMSpec.jepaFamily n Context Target Pred) g ∧
            ∀ (j : Fin k) (x : Context × (Fin n → Target)), G j (g x) = G j x
```
