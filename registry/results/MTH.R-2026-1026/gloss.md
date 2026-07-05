# MTH.R-2026-1026 — result `TLT.NonIdentifiability.isWorldModel_iff_ker_isConforming` [T0]

`theorem` in `WMSpec.NonIdentifiability.ForcingTheorem`; polarity universal. Discharges MTH.C-2026-1026. Kernel-verified (whole-theory replay); axioms ['propext', 'Classical.choice', 'Quot.sound'].

```
TLT.NonIdentifiability.isWorldModel_iff_ker_isConforming : ∀ {S : Type u_1} {ι : Type u_2} {W : ι → Type u_3} {T : (i : ι) → S → W i} {P : S → PMF S} {Z : Type u_4} (E : S → Z),
  TLT.NonIdentifiability.IsWorldModel T P E ↔ TLT.NonIdentifiability.IsConforming T P (Setoid.ker E)
```
