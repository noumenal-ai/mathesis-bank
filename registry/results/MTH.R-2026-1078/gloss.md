# MTH.R-2026-1078 — result `WMSpec.witness_executedGuard_matched_detects` [T1]

`theorem` in `WMSpec.ExecutableGuard`; polarity existential. Discharges MTH.C-2026-1078. Kernel-verified (whole-theory replay); axioms ['propext', 'Classical.choice', 'Quot.sound'].

```
WMSpec.witness_executedGuard_matched_detects : WMSpec.matchedObjective (WMSpec.jepaFamily 2 Unit TorchLean.Floats.IEEE754.IEEE32Exec Unit)
    (fun x => WMSpec.spreadGuard) (fun x => 1) (fun x x_1 => (), fun x x_1 => 0) (WMSpec.collapse WMSpec.w) [0] ≠
  WMSpec.matchedObjective (WMSpec.jepaFamily 2 Unit TorchLean.Floats.IEEE754.IEEE32Exec Unit)
    (fun x => WMSpec.spreadGuard) (fun x => 1) (fun x x_1 => (), fun x x_1 => 0) WMSpec.w [0]
```
