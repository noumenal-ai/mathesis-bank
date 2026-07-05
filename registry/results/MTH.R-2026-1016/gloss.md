# MTH.R-2026-1016 — result `WMSpec.invarianceMonoid_eq_iInf` [T0]

`theorem` in `WMSpec.MixedFamilies`; polarity universal. Discharges MTH.C-2026-1016. Kernel-verified (whole-theory replay); axioms ['propext', 'Quot.sound'].

```
WMSpec.invarianceMonoid_eq_iInf : ∀ {Θ : Type u_1} {X : Type u_2} {M : Type u_3} {V : Type u_4} (L : Θ → X → M → V),
  WMSpec.invarianceMonoid L = ⨅ m, WMSpec.invarianceMonoidAt L m
```
