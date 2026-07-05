# MTH.R-2026-1035 — result `WMSpec.jepa_is_zero_geometry_predictive_view` [T0]

`theorem` in `WMSpec.DraftWrappers`; polarity universal. Discharges MTH.C-2026-1035. Kernel-verified (whole-theory replay); axioms ['propext'].

```
WMSpec.jepa_is_zero_geometry_predictive_view : ∀ {n : ℕ} {Context Target Pred : Type} (targetIdxs : List (Fin n)) (context : Context) (target : Fin n → Target)
  (predict : Context → Fin n → Pred) (repLoss : Target → Pred → ℕ),
  NN.MLTheory.SelfSupervised.predictiveViewObjective
      (NN.MLTheory.SelfSupervised.jepaAsPredictiveViewContract targetIdxs context target predict repLoss) =
    NN.MLTheory.SelfSupervised.jepaLoss targetIdxs context target predict repLoss
```
