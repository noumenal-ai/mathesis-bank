# MTH.R-2026-1104 — result `WMSpec.velocityBoost_breaks_flow` [T0]

`theorem` in `WMSpec.MatchedInvariance`; polarity existential. Discharges MTH.C-2026-1104. Kernel-verified (whole-theory replay); axioms ['propext', 'Classical.choice', 'Quot.sound'].

```
WMSpec.velocityBoost_breaks_flow : ∀ (S : ClassicalMechanics.HarmonicOscillator) (t : Time),
  Real.sin (S.ω * t.val) ≠ 0 →
    ∀ {v : EuclideanSpace ℝ (Fin 1)},
      v ≠ 0 →
        WMSpec.positionEncoder (WMSpec.flow S t { x₀ := 0, v₀ := 0 }) ≠
          WMSpec.positionEncoder (WMSpec.flow S t (WMSpec.velocityBoost v { x₀ := 0, v₀ := 0 }))
```
