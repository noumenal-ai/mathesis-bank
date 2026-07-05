# MTH.R-2026-1070 — result `TLT.NonIdentifiability.isWorldModel_quotientMk_bisimilarity` [T0]

`theorem` in `WMSpec.NonIdentifiability.ForcingTheorem`; polarity universal. Discharges MTH.C-2026-1070. Kernel-verified (whole-theory replay); axioms ['propext', 'Classical.choice', 'Quot.sound'].

```
TLT.NonIdentifiability.isWorldModel_quotientMk_bisimilarity : ∀ {S : Type u_1} {ι : Type u_2} {W : ι → Type u_3} {T : (i : ι) → S → W i} {P : S → PMF S},
  TLT.NonIdentifiability.IsWorldModel T P (Quotient.mk (TLT.NonIdentifiability.bisimilarity T P))
```
