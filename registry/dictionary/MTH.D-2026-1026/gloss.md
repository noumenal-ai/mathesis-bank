# MTH.D-2026-1026 — definition `WMSpec.quotientTarget`

`def` in `WMSpec.ForcingTheorem`; exercisable. Author-provided; Dictionary interrogation pending.

```
WMSpec.quotientTarget : {S : Type u_1} →
  [inst : Fintype S] →
    {V : Type u_2} →
      (𝒯 : Set (S → V)) →
        (P : S → ProbabilityTheory.FintypePMF S) → {T : S → V} → T ∈ 𝒯 → Quotient (WMSpec.bisimilarity 𝒯 P) → V
```
