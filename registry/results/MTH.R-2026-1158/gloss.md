# MTH.R-2026-1158 — result `WMSpec.objectiveInvariant_iff_forall_at` [T0]

`theorem` in `WMSpec.MaskIndexedInvariance`; polarity universal. Discharges MTH.C-2026-1158. Kernel-verified (whole-theory replay); axioms [].

```
WMSpec.objectiveInvariant_iff_forall_at : ∀ {Θ : Type u_1} {X : Type u_2} {M : Type u_3} {V : Type u_4} (L : Θ → X → M → V) (g : X → X),
  WMSpec.ObjectiveInvariant L g ↔ ∀ (m : M), WMSpec.ObjectiveInvariantAt L m g
```
