# MTH.R-2026-1139 — result `WMSpec.ObjectiveInvariant.comp` [T0]

`theorem` in `WMSpec.ObjectiveInvariance`; polarity universal. Discharges MTH.C-2026-1139. Kernel-verified (whole-theory replay); axioms [].

```
WMSpec.ObjectiveInvariant.comp : ∀ {Θ : Type u_1} {X : Type u_2} {M : Type u_3} {V : Type u_4} {L : Θ → X → M → V} {g h : X → X},
  WMSpec.ObjectiveInvariant L g → WMSpec.ObjectiveInvariant L h → WMSpec.ObjectiveInvariant L (g ∘ h)
```
