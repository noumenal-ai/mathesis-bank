# MTH.D-2026-1021 — definition `WMSpec.jepaMatched`

`def` in `WMSpec.MatchedObjective`; exercisable. Author-provided; Dictionary interrogation pending.

```
WMSpec.jepaMatched : {k : ℕ} →
  (n : ℕ) →
    (Context Target Pred : Type) →
      (Fin k → Context × (Fin n → Target) → ℝ) →
        (Fin k → ℝ) → (Context → Fin n → Pred) × (Target → Pred → ℕ) → Context × (Fin n → Target) → List (Fin n) → ℝ
```
