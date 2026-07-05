# MTH.R-2026-1041 — result `TLT.NonIdentifiability.eqvGen_factorsThrough` [T0]

`theorem` in `WMSpec.NonIdentifiability.ForcingTheorem`; polarity universal. Discharges MTH.C-2026-1041. Kernel-verified (whole-theory replay); axioms [].

```
TLT.NonIdentifiability.eqvGen_factorsThrough : ∀ {α : Sort u_1} {γ : Sort u_2} {rel : α → α → Prop} {g : α → γ},
  (∀ (a b : α), rel a b → g a = g b) → ∀ {a b : α}, Relation.EqvGen rel a b → g a = g b
```
