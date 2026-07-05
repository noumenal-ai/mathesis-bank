# MTH.D-2026-1020 — definition `WMSpec.quotientDynamics`

`def` in `WMSpec.ForcingTheorem`; obligated. Author-provided; Dictionary interrogation pending.

```
WMSpec.quotientDynamics : {S : Type u_1} →
  [inst : Fintype S] →
    {V : Type u_2} →
      (𝒯 : Set (S → V)) →
        (P : S → ProbabilityTheory.FintypePMF S) →
          Quotient (WMSpec.bisimilarity 𝒯 P) → ProbabilityTheory.FintypePMF (Quotient (WMSpec.bisimilarity 𝒯 P))
```
