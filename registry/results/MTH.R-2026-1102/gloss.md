# MTH.R-2026-1102 — result `TLT.NonIdentifiability.ker_le_bisimilarity_of_isWorldModel` [T0]

`theorem` in `WMSpec.NonIdentifiability.ForcingTheorem`; polarity universal. Discharges MTH.C-2026-1102. Kernel-verified (whole-theory replay); axioms ['propext', 'Classical.choice', 'Quot.sound'].

```
TLT.NonIdentifiability.ker_le_bisimilarity_of_isWorldModel : ∀ {S : Type u_1} {ι : Type u_2} {W : ι → Type u_3} {T : (i : ι) → S → W i} {P : S → PMF S} {Z : Type u_4} {E : S → Z},
  TLT.NonIdentifiability.IsWorldModel T P E → Setoid.ker E ≤ TLT.NonIdentifiability.bisimilarity T P
```
