# MTH.D-2026-1019 — definition `WMSpec.mapPMF`

`def` in `WMSpec.MixedFamilies`; exercisable. Author-provided; Dictionary interrogation pending.

```
WMSpec.mapPMF : {α : Type u_1} →
  {β : Type u_2} →
    [inst : Fintype α] →
      [inst_1 : Fintype β] → [DecidableEq β] → (α → β) → ProbabilityTheory.FintypePMF α → ProbabilityTheory.FintypePMF β
```
