# MTH.R-2026-1122 — result `WMSpec.constant_guard_invariant` [T0]

`theorem` in `WMSpec.MaskIndexedInvariance`; polarity universal. Discharges MTH.C-2026-1122. Kernel-verified (whole-theory replay); axioms [].

```
WMSpec.constant_guard_invariant : ∀ {Θ : Type u_1} {X : Type u_2} {M : Type u_3} {V : Type u_4} (c : V) (g : X → X),
  WMSpec.ObjectiveInvariant (fun x x_1 x_2 => c) g
```
