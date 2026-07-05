# MTH.R-2026-1105 — result `WMSpec.witness_unselected_rewrite_executed` [T0]

`theorem` in `WMSpec.MaskIndexedInvariance`; polarity universal. Discharges MTH.C-2026-1105. Kernel-verified (whole-theory replay); axioms ['propext'].

```
WMSpec.witness_unselected_rewrite_executed : (NN.MLTheory.SelfSupervised.jepaLoss [0] () (fun x => false) (fun x x_1 => true) fun t p => if t = p then 0 else 1) =
  NN.MLTheory.SelfSupervised.jepaLoss [0] () (fun i => if i = 1 then true else false) (fun x x_1 => true) fun t p =>
    if t = p then 0 else 1
```
