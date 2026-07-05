# MTH.R-2026-1007 — result `WMSpec.oscillator_latentStep_iff_int_multiple` [T0]

`theorem` in `WMSpec.Flow.OscillatorBinding`; polarity universal. Discharges MTH.C-2026-1007. Kernel-verified (whole-theory replay); axioms ['propext', 'Classical.choice', 'Quot.sound'].

```
WMSpec.oscillator_latentStep_iff_int_multiple : ∀ (S : ClassicalMechanics.HarmonicOscillator) (t : Time),
  WMSpec.LatentStepAt (WMSpec.flow S t) WMSpec.positionEncoder ↔ ∃ n, ↑n * Real.pi = S.ω * t.val
```
