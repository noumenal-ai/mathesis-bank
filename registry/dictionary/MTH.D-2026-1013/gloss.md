# MTH.D-2026-1013 — definition `WMSpec.Flow.admissibleSubgroup_of_recurrence`

`def` in `WMSpec.Flow.FlowArchitecture`; exercisable. Author-provided; Dictionary interrogation pending.

```
WMSpec.Flow.admissibleSubgroup_of_recurrence : {T : Type u_1} →
  {S : Type u_2} →
    {Z : Type u_3} →
      [inst : AddGroup T] →
        [inst_1 : AddAction T S] →
          (E : S → Z) → (∀ t ∈ WMSpec.Flow.admissibleHorizons E, ∃ k, 0 < k ∧ ∀ (x : S), k • t +ᵥ x = x) → AddSubgroup T
```
