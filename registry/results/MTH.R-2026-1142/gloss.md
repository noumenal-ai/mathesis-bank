# MTH.R-2026-1142 — result `WMSpec.Saturated.of_mem` [T0]

`theorem` in `WMSpec.ForcingTheorem`; polarity universal. Discharges MTH.C-2026-1142. Kernel-verified (whole-theory replay); axioms ['propext', 'Quot.sound'].

```
WMSpec.Saturated.of_mem : ∀ {S : Type u_1} {F : Set (Setoid S)} {r : Setoid S},
  r ∈ F → ∀ {C : Finset S}, WMSpec.Saturated (sSup F) C → WMSpec.Saturated r C
```
