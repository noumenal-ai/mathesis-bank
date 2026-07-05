# MTH.D-2026-1077 — definition `WMSpec.instFintypeQuotientBisimilarity`

`def` in `WMSpec.ForcingTheorem`; obligated. Author-provided; Dictionary interrogation pending.

```
WMSpec.instFintypeQuotientBisimilarity : {S : Type u_1} →
  [inst : Fintype S] →
    {V : Type u_2} →
      (𝒯 : Set (S → V)) → (P : S → ProbabilityTheory.FintypePMF S) → Fintype (Quotient (WMSpec.bisimilarity 𝒯 P))
```
