# MTH.R-2026-1073 — result `TLT.NonIdentifiability.not_isWorldModel_const` [T0]

`theorem` in `WMSpec.NonIdentifiability.DerivedWorldModels`; polarity existential. Discharges MTH.C-2026-1073. Kernel-verified (whole-theory replay); axioms ['propext', 'Classical.choice', 'Quot.sound'].

```
TLT.NonIdentifiability.not_isWorldModel_const : ∀ {S : Type u_1} {ι : Type u_2} {W : ι → Type u_3} {T : (i : ι) → S → W i} (P : S → PMF S) {i : ι} {s₁ s₂ : S},
  T i s₁ ≠ T i s₂ → ¬TLT.NonIdentifiability.IsWorldModel T P fun x => PUnit.unit
```
