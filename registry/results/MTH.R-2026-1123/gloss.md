# MTH.R-2026-1123 — result `TLT.NonIdentifiability.IsWorldModel.hasDynamics` [T0]

`theorem` in `WMSpec.NonIdentifiability.ForcingTheorem`; polarity universal. Discharges MTH.C-2026-1123. Kernel-verified (whole-theory replay); axioms ['propext', 'Classical.choice', 'Quot.sound'].

```
TLT.NonIdentifiability.IsWorldModel.hasDynamics : ∀ {S : Type u_1} {ι : Type u_2} {W : ι → Type u_3} {T : (i : ι) → S → W i} {P : S → PMF S} {Z : Type u_4} {E : S → Z},
  TLT.NonIdentifiability.IsWorldModel T P E → ∃ Q, ∀ (s : S), Q (E s) = PMF.map E (P s)
```
