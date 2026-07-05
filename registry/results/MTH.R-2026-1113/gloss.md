# MTH.R-2026-1113 — result `TLT.NonIdentifiability.isConforming_sSup` [T0]

`theorem` in `WMSpec.NonIdentifiability.ForcingTheorem`; polarity universal. Discharges MTH.C-2026-1113. Kernel-verified (whole-theory replay); axioms ['propext', 'Classical.choice', 'Quot.sound'].

```
TLT.NonIdentifiability.isConforming_sSup : ∀ {S : Type u_1} {ι : Type u_2} {W : ι → Type u_3} {T : (i : ι) → S → W i} {P : S → PMF S} {R : Set (Setoid S)},
  (∀ r ∈ R, TLT.NonIdentifiability.IsConforming T P r) → TLT.NonIdentifiability.IsConforming T P (sSup R)
```
