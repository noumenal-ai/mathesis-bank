# MTH.R-2026-1098 — result `TLT.NonIdentifiability.isGreatest_bisimilarity` [T0]

`theorem` in `WMSpec.NonIdentifiability.ForcingTheorem`; polarity universal. Discharges MTH.C-2026-1098. Kernel-verified (whole-theory replay); axioms ['propext', 'Classical.choice', 'Quot.sound'].

```
TLT.NonIdentifiability.isGreatest_bisimilarity : ∀ {S : Type u_1} {ι : Type u_2} {W : ι → Type u_3} {T : (i : ι) → S → W i} {P : S → PMF S},
  IsGreatest {r | TLT.NonIdentifiability.IsConforming T P r} (TLT.NonIdentifiability.bisimilarity T P)
```
