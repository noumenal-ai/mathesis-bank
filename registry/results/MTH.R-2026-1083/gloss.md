# MTH.R-2026-1083 — result `WMSpec.reverse_maskInvariant` [T0]

`theorem` in `WMSpec.MaskIndexedInvariance`; polarity universal. Discharges MTH.C-2026-1083. Kernel-verified (whole-theory replay); axioms ['propext'].

```
WMSpec.reverse_maskInvariant : ∀ {n : ℕ} {Context Target Pred : Type}, WMSpec.MaskInvariant (WMSpec.jepaFamily n Context Target Pred) List.reverse
```
