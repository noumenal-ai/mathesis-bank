# MTH.R-2026-1160 — result `TLT.NonIdentifiability.Executed.no_lipschitz_reading_of_executed_encoder` [T0]

`theorem` in `WMSpec.NonIdentifiability.ExecutedWitness`; polarity existential. Discharges MTH.C-2026-1160. Kernel-verified (whole-theory replay); axioms ['propext', 'Classical.choice', 'Quot.sound'].

```
TLT.NonIdentifiability.Executed.no_lipschitz_reading_of_executed_encoder : ¬∃ g,
    LipschitzWith 1 g ∧
      ∀ (s : TLT.NonIdentifiability.Executed.S),
        TLT.NonIdentifiability.Executed.T s = g (TLT.NonIdentifiability.Executed.E s)
```
