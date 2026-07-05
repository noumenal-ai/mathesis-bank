# MTH.R-2026-1093 — result `WMSpec.CharacterizedGuard.mk.sizeOf_spec` [T0]

`theorem` in `WMSpec.GuardFamilies`; polarity universal. Discharges MTH.C-2026-1093. Kernel-verified (whole-theory replay); axioms ['propext', 'Classical.choice', 'Quot.sound'].

```
WMSpec.CharacterizedGuard.mk.sizeOf_spec : ∀ {X' : Type u_1} [inst : SizeOf X'] (val : X' → ℝ) (Pr : X' → Prop) (zero_iff : ∀ (x : X'), val x = 0 ↔ Pr x),
  sizeOf { val := val, Pr := Pr, zero_iff := zero_iff } = 1
```
