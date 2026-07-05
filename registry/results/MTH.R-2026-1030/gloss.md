# MTH.R-2026-1030 — result `WMSpec.not_factorThrough_loss_of_invariance` [T0]

`theorem` in `WMSpec.ObjectiveInvariance`; polarity existential. Discharges MTH.C-2026-1030. Kernel-verified (whole-theory replay); axioms [].

```
WMSpec.not_factorThrough_loss_of_invariance : ∀ {Θ : Type u_1} {X : Type u_2} {M : Type u_3} {V : Type u_4} {W : Type u_5} {L : Θ → X → M → V} {g : X → X},
  WMSpec.ObjectiveInvariant L g →
    ∀ (T : X → W) {x : X}, T x ≠ T (g x) → ∀ (θ : Θ) (m : M), ¬∃ r, ∀ (y : X), T y = r (L θ y m)
```
