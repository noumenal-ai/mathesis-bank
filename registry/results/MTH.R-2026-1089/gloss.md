# MTH.R-2026-1089 — result `WMSpec.witness_matched_detects` [T0]

`theorem` in `WMSpec.MatchedObjective`; polarity existential. Discharges MTH.C-2026-1089. Kernel-verified (whole-theory replay); axioms ['propext', 'Classical.choice', 'Quot.sound'].

```
WMSpec.witness_matched_detects : ¬WMSpec.ObjectiveInvariant
    (WMSpec.matchedObjective (WMSpec.jepaFamily 2 Unit Bool Bool) (fun x x_1 => if x_1.2 0 = true then 1 else 0)
      fun x => 1)
    fun x => (x.1, fun x => true)
```
