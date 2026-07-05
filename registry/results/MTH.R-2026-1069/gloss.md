# MTH.R-2026-1069 — result `TLT.NonIdentifiability.JEPA.witness_jepaLoss_computes` [T0]

`theorem` in `WMSpec.NonIdentifiability.JepaBoundary`; polarity universal. Discharges MTH.C-2026-1069. Kernel-verified (whole-theory replay); axioms ['propext'].

```
TLT.NonIdentifiability.JEPA.witness_jepaLoss_computes : (NN.MLTheory.SelfSupervised.jepaLoss [0] (TLT.NonIdentifiability.JEPA.witnessE 0)
    TLT.NonIdentifiability.JEPA.witnessTargetAtIdx TLT.NonIdentifiability.JEPA.witnessPredict fun t p =>
    if t = p then 0 else 1) =
  1
```
