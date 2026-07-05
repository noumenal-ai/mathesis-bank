# MTH.D-2026-1063 — definition `WMSpec.bisimMetric`

`def` in `WMSpec.BisimMetric`; obligated. Author-provided; Dictionary interrogation pending.

```
WMSpec.bisimMetric : {S : Type u_1} →
  [inst : Fintype S] →
    {V : Type u_2} →
      (𝒯 : Set (S → V)) →
        (P : S → ProbabilityTheory.FintypePMF S) →
          Quotient (WMSpec.bisimilarity 𝒯 P) → Quotient (WMSpec.bisimilarity 𝒯 P) → ℝ
```
