# MTH.R-2026-1135 — result `WMSpec.positionEncoder_collapse` [T0]

`theorem` in `WMSpec.EnergyNonRecovery`; polarity universal. Discharges MTH.C-2026-1135. Kernel-verified (whole-theory replay); axioms ['propext', 'Classical.choice', 'Quot.sound'].

```
WMSpec.positionEncoder_collapse : ∀ (x₀ v : EuclideanSpace ℝ (Fin 1)),
  WMSpec.positionEncoder { x₀ := x₀, v₀ := 0 } = WMSpec.positionEncoder { x₀ := x₀, v₀ := v }
```
