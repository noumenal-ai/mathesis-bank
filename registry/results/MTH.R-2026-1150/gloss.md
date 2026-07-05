# MTH.R-2026-1150 — result `WMSpec.energy_not_recoverable_from_position` [T0]

`theorem` in `WMSpec.EnergyNonRecovery`; polarity existential. Discharges MTH.C-2026-1150. Kernel-verified (whole-theory replay); axioms ['propext', 'Classical.choice', 'Quot.sound'].

```
WMSpec.energy_not_recoverable_from_position : ∀ (S : ClassicalMechanics.HarmonicOscillator) (x₀ v : EuclideanSpace ℝ (Fin 1)),
  v ≠ 0 →
    ¬∃ g,
        ∀ (IC : ClassicalMechanics.HarmonicOscillator.InitialConditions),
          WMSpec.energyOfIC S IC = g (WMSpec.positionEncoder IC)
```
