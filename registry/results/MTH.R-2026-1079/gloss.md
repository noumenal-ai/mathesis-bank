# MTH.R-2026-1079 — result `WMSpec.CharacterizedGuard.zero_iff` [T0]

`theorem` in `WMSpec.GuardFamilies`; polarity universal. Discharges MTH.C-2026-1079. Kernel-verified (whole-theory replay); axioms ['propext', 'Classical.choice', 'Quot.sound'].

```
WMSpec.CharacterizedGuard.zero_iff : ∀ {X' : Type u_1} (self : WMSpec.CharacterizedGuard X') (x : X'), self.val x = 0 ↔ self.Pr x
```
