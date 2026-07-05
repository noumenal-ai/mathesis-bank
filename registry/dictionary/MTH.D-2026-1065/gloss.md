# MTH.D-2026-1065 — definition `WMSpec.mixedObjective`

`def` in `WMSpec.MixedFamilies`; exercisable. Author-provided; Dictionary interrogation pending.

```
WMSpec.mixedObjective : {Θ : Type u_1} →
  {Xd : Type u_2} →
    {Yl : Type u_3} →
      {ι : Type u_4} →
        {k r : ℕ} →
          (Θ → Xd → List ι → ℕ) →
            (Fin k → Xd → ℝ) → (Fin r → Yl → ℝ) → (Fin k → ℝ) → (Fin r → ℝ) → Θ → Xd × Yl → List ι → ℝ
```
