# MTH.R-2026-1002 — result `WMSpec.energyOfIC_gap` [T0]

`theorem` in `WMSpec.EnergyNonRecovery`; polarity universal. Discharges MTH.C-2026-1002. Kernel-verified (whole-theory replay); axioms ['propext', 'Classical.choice', 'Quot.sound'].

```
WMSpec.energyOfIC_gap : ∀ (S : ClassicalMechanics.HarmonicOscillator) (x₀ v : EuclideanSpace ℝ (Fin 1)),
  WMSpec.energyOfIC S { x₀ := x₀, v₀ := v } - WMSpec.energyOfIC S { x₀ := x₀, v₀ := 0 } = 1 / 2 * S.m * ‖v‖ ^ 2
```
