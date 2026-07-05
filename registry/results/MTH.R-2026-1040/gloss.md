# MTH.R-2026-1040 — result `WMSpec.not_factorThrough_of_invariance` [T0]

`theorem` in `WMSpec.MatchedInvariance`; polarity existential. Discharges MTH.C-2026-1040. Kernel-verified (whole-theory replay); axioms [].

```
WMSpec.not_factorThrough_of_invariance : ∀ {A : Type u_1} {Z : Type u_2} {W : Type u_3} (E : A → Z) (T : A → W) (b : A → A),
  (∀ (a : A), E (b a) = E a) → ∀ {a : A}, T a ≠ T (b a) → ¬∃ g, ∀ (x : A), T x = g (E x)
```
