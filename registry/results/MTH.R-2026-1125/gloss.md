# MTH.R-2026-1125 — result `TLT.NonIdentifiability.isConforming_bisimilarity` [T0]

`theorem` in `WMSpec.NonIdentifiability.ForcingTheorem`; polarity universal. Discharges MTH.C-2026-1125. Kernel-verified (whole-theory replay); axioms ['propext', 'Classical.choice', 'Quot.sound'].

```
TLT.NonIdentifiability.isConforming_bisimilarity : ∀ {S : Type u_1} {ι : Type u_2} {W : ι → Type u_3} {T : (i : ι) → S → W i} {P : S → PMF S},
  TLT.NonIdentifiability.IsConforming T P (TLT.NonIdentifiability.bisimilarity T P)
```
