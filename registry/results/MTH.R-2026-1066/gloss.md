# MTH.R-2026-1066 — result `WMSpec.jepa_two_component_mask_decomposition` [T0]

`theorem` in `WMSpec.DraftWrappers`; polarity universal. Discharges MTH.C-2026-1066. Kernel-verified (whole-theory replay); axioms ['propext'].

```
WMSpec.jepa_two_component_mask_decomposition : ∀ {n : ℕ} {Context Target Pred : Type} (xs ys : List (Fin n)) (context : Context) (target : Fin n → Target)
  (predict : Context → Fin n → Pred) (repLoss : Target → Pred → ℕ),
  NN.MLTheory.SelfSupervised.jepaLoss (xs ++ ys) context target predict repLoss =
    NN.MLTheory.SelfSupervised.jepaLoss xs context target predict repLoss +
      NN.MLTheory.SelfSupervised.jepaLoss ys context target predict repLoss
```
