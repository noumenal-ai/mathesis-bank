# MTH.R-2026-1127 — result `WMSpec.witness_reverse_executed` [T0]

`theorem` in `WMSpec.MaskIndexedInvariance`; polarity universal. Discharges MTH.C-2026-1127. Kernel-verified (whole-theory replay); axioms ['propext'].

```
WMSpec.witness_reverse_executed : (NN.MLTheory.SelfSupervised.jepaLoss [1, 0] () (fun x => false) (fun x x_1 => true) fun t p => if t = p then 0 else 1) =
  NN.MLTheory.SelfSupervised.jepaLoss [0, 1] () (fun x => false) (fun x x_1 => true) fun t p => if t = p then 0 else 1
```
