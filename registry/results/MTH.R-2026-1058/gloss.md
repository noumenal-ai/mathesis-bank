# MTH.R-2026-1058 — result `WMSpec.objectiveInvariantAt_nil_of_additive` [T0]

`theorem` in `WMSpec.MaskIndexedInvariance`; polarity universal. Discharges MTH.C-2026-1058. Kernel-verified (whole-theory replay); axioms ['propext', 'Quot.sound'].

```
WMSpec.objectiveInvariantAt_nil_of_additive : ∀ {Θ : Type u_1} {X : Type u_2} {ι : Type u_5} (L : Θ → X → List ι → ℕ),
  (∀ (θ : Θ) (x : X) (I₁ I₂ : List ι), L θ x (I₁ ++ I₂) = L θ x I₁ + L θ x I₂) →
    ∀ (g : X → X), WMSpec.ObjectiveInvariantAt L [] g
```
