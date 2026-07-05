# MTH.D-2026-1027 — definition `WMSpec.jepaFamily`

`def` in `WMSpec.MaskIndexedInvariance`; exercisable. Author-provided; Dictionary interrogation pending.

```
WMSpec.jepaFamily : (n : ℕ) →
  (Context Target Pred : Type) →
    (Context → Fin n → Pred) × (Target → Pred → ℕ) → Context × (Fin n → Target) → List (Fin n) → ℕ
```
