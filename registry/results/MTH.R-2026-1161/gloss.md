# MTH.R-2026-1161 — result `WMSpec.CharacterizedGuard.transport` [T0]

`theorem` in `WMSpec.GuardFamilies`; polarity universal. Discharges MTH.C-2026-1161. Kernel-verified (whole-theory replay); axioms ['propext', 'Classical.choice', 'Quot.sound'].

```
WMSpec.CharacterizedGuard.transport : ∀ {X' : Type u_1} (Gc : WMSpec.CharacterizedGuard X') {g : X' → X'},
  (∀ (x : X'), Gc.val (g x) = Gc.val x) → ∀ (x : X'), Gc.Pr (g x) ↔ Gc.Pr x
```
