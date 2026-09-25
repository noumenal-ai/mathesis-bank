/-
Copyright (c) 2026 Dhruv Gupta. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Dhruv Gupta
-/
import Mathlib.MeasureTheory.Constructions.Polish.Basic
import Mathlib.Analysis.Real.Cardinality
import Mathlib.Analysis.Normed.Group.FunctionSeries
import Mathlib.Topology.Bases

/-!
# An analytic non-Borel set, constructed

The classical diagonalization witness (Cohn, *Measure Theory*, Corollary 8.2.17; Kechris,
*Classical Descriptive Set Theory*, §22, §26): a closed set universal for the closed subsets
of a second-countable space is built from an enumerated basis, and diagonalizing its sections
over Baire space produces an analytic set that is not Borel. The construction is a
diagonalization, not a choice argument — the set is exhibited, and classical axioms enter
only through the ambient plumbing.

Composing with an explicit continuous injection of Baire space into `ℝ` (marker sequences
into a base-3 expansion with digits `0, 1`) lands the witness in the real line.

## Main results

- `MeasureTheory.exists_closed_universal_sections`: every second-countable space carries a
  closed subset of `X × (ℕ → ℕ)` whose sections exhaust the closed subsets of `X`.
- `MeasureTheory.exists_closed_proj_not_measurableSet`: a closed subset of
  `(ℕ → ℕ) × (ℕ → ℕ)` whose first-coordinate projection is not Borel.
- `MeasureTheory.exists_analyticSet_not_measurableSet`: an analytic non-Borel subset of
  Baire space.
- `MeasureTheory.exists_analyticSet_not_measurableSet_real`: an analytic non-Borel subset
  of `ℝ`.
-/

open MeasureTheory Set

namespace MeasureTheory

/-! ### A closed set universal for closed sections -/

/-- **A universal closed set.** Every second-countable space `X` carries a closed subset of
`X × (ℕ → ℕ)` whose sections run through all closed subsets of `X`: enumerate a countable
basis together with `∅`, and let the parameter select which basis elements to exclude. -/
theorem exists_closed_universal_sections (X : Type*) [TopologicalSpace X]
    [SecondCountableTopology X] :
    ∃ S : Set (X × (ℕ → ℕ)), IsClosed S ∧
      ∀ C : Set X, IsClosed C → ∃ y : ℕ → ℕ, {x : X | (x, y) ∈ S} = C := by
  have hcb : (insert (∅ : Set X) (TopologicalSpace.countableBasis X)).Countable :=
    (TopologicalSpace.countable_countableBasis X).insert ∅
  obtain ⟨u, hu⟩ := hcb.exists_eq_range ⟨∅, Set.mem_insert _ _⟩
  have hu_open : ∀ n, IsOpen (u n) := by
    intro n
    have hmem : u n ∈ insert (∅ : Set X) (TopologicalSpace.countableBasis X) := by
      rw [hu]; exact Set.mem_range_self n
    rcases Set.mem_insert_iff.mp hmem with h | h
    · rw [h]; exact isOpen_empty
    · exact (TopologicalSpace.isBasis_countableBasis X).isOpen h
  refine ⟨{p : X × (ℕ → ℕ) | ∀ n, p.1 ∉ u (p.2 n)}, ?_, ?_⟩
  · rw [← isOpen_compl_iff]
    have hcompl : {p : X × (ℕ → ℕ) | ∀ n, p.1 ∉ u (p.2 n)}ᶜ
        = ⋃ n, ⋃ k, (u k) ×ˢ {y : ℕ → ℕ | y n = k} := by
      ext ⟨x, y⟩
      simp only [Set.mem_compl_iff, Set.mem_setOf_eq, not_forall, not_not, Set.mem_iUnion,
        Set.mem_prod]
      constructor
      · rintro ⟨n, hn⟩
        exact ⟨n, y n, hn, rfl⟩
      · rintro ⟨n, k, hx, hk⟩
        exact ⟨n, hk ▸ hx⟩
    rw [hcompl]
    refine isOpen_iUnion fun n => isOpen_iUnion fun k => (hu_open k).prod ?_
    show IsOpen ((fun y : ℕ → ℕ => y n) ⁻¹' {k})
    exact (isOpen_discrete _).preimage (continuous_apply n)
  · intro C hC
    set I : Set ℕ := {n | u n ⊆ Cᶜ} with hI
    have hIne : I.Nonempty := by
      have hmem : (∅ : Set X) ∈ Set.range u := by
        rw [← hu]; exact Set.mem_insert _ _
      obtain ⟨n₀, hn₀⟩ := hmem
      refine ⟨n₀, ?_⟩
      rw [hI, Set.mem_setOf_eq, hn₀]
      exact Set.empty_subset _
    obtain ⟨y, hy⟩ := (Set.to_countable I).exists_eq_range hIne
    refine ⟨y, ?_⟩
    have hunion : (⋃ n, u (y n)) = Cᶜ := by
      apply Set.Subset.antisymm
      · refine Set.iUnion_subset fun n => ?_
        have hmem : y n ∈ I := by rw [hy]; exact Set.mem_range_self n
        exact hmem
      · intro x hx
        obtain ⟨t, ht_mem, hxt, htsub⟩ :=
          (TopologicalSpace.isBasis_countableBasis X).exists_subset_of_mem_open hx
            hC.isOpen_compl
        have hrange : t ∈ Set.range u := by
          rw [← hu]; exact Set.mem_insert_of_mem _ ht_mem
        obtain ⟨m, hm⟩ := hrange
        have hmI : m ∈ I := by rw [hI, Set.mem_setOf_eq, hm]; exact htsub
        rw [hy] at hmI
        obtain ⟨n, hn⟩ := hmI
        exact Set.mem_iUnion.mpr ⟨n, by rw [hn, hm]; exact hxt⟩
    ext x
    simp only [Set.mem_setOf_eq]
    constructor
    · intro h
      by_contra hxC
      have hxCc : x ∈ Cᶜ := hxC
      rw [← hunion] at hxCc
      obtain ⟨n, hn⟩ := Set.mem_iUnion.mp hxCc
      exact h n hn
    · intro hxC n hn
      have hmem : x ∈ Cᶜ := hunion ▸ Set.mem_iUnion.mpr ⟨n, hn⟩
      exact hmem hxC

/-! ### The diagonal witness in Baire space -/

/-- **A closed set with a non-Borel projection.** Diagonalize the universal closed set of
`(ℕ → ℕ) × (ℕ → ℕ)`: were the projection Borel, its complement would be analytic, hence the
projection of a closed set, hence a section of the universal set — and evaluating that
section at its own parameter is contradictory. -/
theorem exists_closed_proj_not_measurableSet :
    ∃ D : Set ((ℕ → ℕ) × (ℕ → ℕ)),
      IsClosed D ∧ ¬ MeasurableSet {x : ℕ → ℕ | ∃ y, (x, y) ∈ D} := by
  obtain ⟨S, hS_closed, hS_univ⟩ := exists_closed_universal_sections ((ℕ → ℕ) × (ℕ → ℕ))
  set D : Set ((ℕ → ℕ) × (ℕ → ℕ)) := {p | ((p.1, p.2), p.1) ∈ S} with hD
  have hD_closed : IsClosed D := by
    have hcont : Continuous fun p : (ℕ → ℕ) × (ℕ → ℕ) => ((p.1, p.2), p.1) :=
      (continuous_fst.prodMk continuous_snd).prodMk continuous_fst
    exact hS_closed.preimage hcont
  set A : Set (ℕ → ℕ) := {x | ∃ y, (x, y) ∈ D} with hA
  refine ⟨D, hD_closed, ?_⟩
  intro hA_meas
  have hAc_an : MeasureTheory.AnalyticSet Aᶜ := hA_meas.compl.analyticSet
  obtain ⟨B, hB_closed, hB_proj⟩ :
      ∃ B : Set ((ℕ → ℕ) × (ℕ → ℕ)),
        IsClosed B ∧ {x : ℕ → ℕ | ∃ y, (x, y) ∈ B} = Aᶜ := by
    rw [MeasureTheory.AnalyticSet] at hAc_an
    rcases hAc_an with h | ⟨f, hf_cont, hf_range⟩
    · refine ⟨∅, isClosed_empty, ?_⟩
      ext x
      simp [h]
    · refine ⟨{p : (ℕ → ℕ) × (ℕ → ℕ) | f p.2 = p.1},
        isClosed_eq (hf_cont.comp continuous_snd) continuous_fst, ?_⟩
      rw [← hf_range]
      ext x
      simp only [Set.mem_setOf_eq, Set.mem_range]
  obtain ⟨y₀, hy₀⟩ := hS_univ B hB_closed
  have hkey : ∀ x : ℕ → ℕ, (∃ y, (x, y) ∈ B) ↔ ∃ y, ((x, y), y₀) ∈ S := by
    intro x
    constructor
    · rintro ⟨y, hy⟩
      have hmem : (x, y) ∈ {p : (ℕ → ℕ) × (ℕ → ℕ) | (p, y₀) ∈ S} := by
        rw [hy₀]; exact hy
      exact ⟨y, hmem⟩
    · rintro ⟨y, hy⟩
      have hmem : (x, y) ∈ {p : (ℕ → ℕ) × (ℕ → ℕ) | (p, y₀) ∈ S} := hy
      rw [hy₀] at hmem
      exact ⟨y, hmem⟩
  have hdiag : y₀ ∈ A ↔ ∃ y, ((y₀, y), y₀) ∈ S := Iff.rfl
  have hAc_iff : y₀ ∈ Aᶜ ↔ ∃ y, ((y₀, y), y₀) ∈ S := by
    have hmem : y₀ ∈ Aᶜ ↔ y₀ ∈ {x : ℕ → ℕ | ∃ y, (x, y) ∈ B} := by rw [hB_proj]
    rw [hmem]
    exact hkey y₀
  by_cases hy₀A : y₀ ∈ A
  · exact (hAc_iff.mpr (hdiag.mp hy₀A)) hy₀A
  · exact hy₀A (hdiag.mpr (hAc_iff.mp hy₀A))

/-- **An analytic non-Borel subset of Baire space**: the projection of the diagonal witness. -/
theorem exists_analyticSet_not_measurableSet :
    ∃ A : Set (ℕ → ℕ), MeasureTheory.AnalyticSet A ∧ ¬ MeasurableSet A := by
  obtain ⟨D, hD_closed, hD_proj⟩ := exists_closed_proj_not_measurableSet
  refine ⟨{x | ∃ y, (x, y) ∈ D}, ?_, hD_proj⟩
  haveI : PolishSpace D := hD_closed.polishSpace
  have hcont : Continuous fun d : D => (d : (ℕ → ℕ) × (ℕ → ℕ)).1 :=
    continuous_fst.comp continuous_subtype_val
  have hrange : Set.range (fun d : D => (d : (ℕ → ℕ) × (ℕ → ℕ)).1)
      = {x | ∃ y, (x, y) ∈ D} := by
    ext x
    constructor
    · rintro ⟨⟨⟨a, b⟩, hab⟩, rfl⟩
      exact ⟨b, hab⟩
    · rintro ⟨y, hy⟩
      exact ⟨⟨(x, y), hy⟩, rfl⟩
  rw [← hrange]
  exact MeasureTheory.analyticSet_range_of_polishSpace hcont

/-! ### A continuous injection of Baire space into the real line -/

/-- The marker sequence of `x : ℕ → ℕ`: the strictly increasing sequence
`n + 1 + ∑_{k ≤ n} x k`, whose successive gaps encode `x`. -/
def baireMarkers (x : ℕ → ℕ) (n : ℕ) : ℕ :=
  n + 1 + ∑ k ∈ Finset.range (n + 1), x k

theorem baireMarkers_strictMono (x : ℕ → ℕ) : StrictMono (baireMarkers x) := by
  refine strictMono_nat_of_lt_succ fun n => ?_
  show n + 1 + ∑ k ∈ Finset.range (n + 1), x k
      < n + 1 + 1 + ∑ k ∈ Finset.range (n + 1 + 1), x k
  have hsum : ∑ k ∈ Finset.range (n + 1), x k ≤ ∑ k ∈ Finset.range (n + 1 + 1), x k :=
    Finset.sum_le_sum_of_subset fun j hj =>
      Finset.mem_range.mpr (by have := Finset.mem_range.mp hj; omega)
  omega

/-- The marker bits: the indicator stream of the marker set. -/
def baireMarkerBits (x : ℕ → ℕ) : ℕ → Bool :=
  fun m => decide ((Finset.range (m + 1)).filter (fun j => baireMarkers x j = m)).Nonempty

theorem baireMarkerBits_injective : Function.Injective baireMarkerBits := by
  intro x y hxy
  by_contra hne
  have hex : ∃ n, x n ≠ y n := Function.ne_iff.mp hne
  set n₀ := Nat.find hex with hn₀_def
  have hn₀ : x n₀ ≠ y n₀ := Nat.find_spec hex
  have hbelow : ∀ k, k < n₀ → x k = y k := fun k hk => not_not.mp (Nat.find_min hex hk)
  have hmark_below : ∀ j, j < n₀ → baireMarkers x j = baireMarkers y j := by
    intro j hj
    unfold baireMarkers
    congr 1
    exact Finset.sum_congr rfl fun k hk => hbelow k (by
      have := Finset.mem_range.mp hk
      omega)
  have hmark_ne : baireMarkers x n₀ ≠ baireMarkers y n₀ := by
    unfold baireMarkers
    intro h
    apply hn₀
    have hx : ∑ k ∈ Finset.range (n₀ + 1), x k
        = ∑ k ∈ Finset.range n₀, x k + x n₀ := Finset.sum_range_succ x n₀
    have hy : ∑ k ∈ Finset.range (n₀ + 1), y k
        = ∑ k ∈ Finset.range n₀, y k + y n₀ := Finset.sum_range_succ y n₀
    have hsums : ∑ k ∈ Finset.range n₀, x k = ∑ k ∈ Finset.range n₀, y k :=
      Finset.sum_congr rfl fun k hk => hbelow k (Finset.mem_range.mp hk)
    omega

  -- the bit at the smaller of the two diverging markers differs
  have hcontra : ∀ a b : ℕ → ℕ, (∀ j, j < n₀ → baireMarkers a j = baireMarkers b j) →
      baireMarkers a n₀ < baireMarkers b n₀ →
      baireMarkerBits a ≠ baireMarkerBits b := by
    intro a b hbelow' hlt hbits
    have hbit := congrFun hbits (baireMarkers a n₀)
    unfold baireMarkerBits at hbit
    rw [decide_eq_decide] at hbit
    have hn₀lt : n₀ < baireMarkers a n₀ := by
      unfold baireMarkers
      omega
    have hleft : ((Finset.range (baireMarkers a n₀ + 1)).filter
        (fun j => baireMarkers a j = baireMarkers a n₀)).Nonempty :=
      ⟨n₀, Finset.mem_filter.mpr ⟨Finset.mem_range.mpr (by omega), rfl⟩⟩
    obtain ⟨j, hj⟩ := hbit.mp hleft
    obtain ⟨-, hj_eq⟩ := Finset.mem_filter.mp hj
    rcases lt_trichotomy j n₀ with hjlt | hjeq | hjgt
    · have heq : baireMarkers b j = baireMarkers a j := (hbelow' j hjlt).symm
      rw [heq] at hj_eq
      have hmono : baireMarkers a j < baireMarkers a n₀ := baireMarkers_strictMono a hjlt
      omega
    · subst hjeq
      omega
    · have h1 : baireMarkers b n₀ < baireMarkers b j := baireMarkers_strictMono b hjgt
      omega
  rcases lt_or_gt_of_ne hmark_ne with hlt | hgt
  · exact hcontra x y hmark_below hlt hxy
  · exact hcontra y x (fun j hj => (hmark_below j hj).symm) hgt (hxy.symm)

theorem continuous_baireMarkerBits : Continuous baireMarkerBits := by
  refine continuous_pi fun m => ?_
  have hlc : ∀ x y : ℕ → ℕ, (∀ k, k ≤ m → x k = y k) →
      baireMarkerBits x m = baireMarkerBits y m := by
    intro x y h
    unfold baireMarkerBits
    rw [decide_eq_decide]
    have hmk : ∀ j, j ≤ m → baireMarkers x j = baireMarkers y j := by
      intro j hj
      unfold baireMarkers
      congr 1
      refine Finset.sum_congr rfl fun k hk => ?_
      have hk' := Finset.mem_range.mp hk
      exact h k (by omega)
    constructor
    · rintro ⟨j, hj⟩
      obtain ⟨hj_mem, hj_eq⟩ := Finset.mem_filter.mp hj
      have hj' := Finset.mem_range.mp hj_mem
      exact ⟨j, Finset.mem_filter.mpr ⟨hj_mem, by rw [← hmk j (by omega)]; exact hj_eq⟩⟩
    · rintro ⟨j, hj⟩
      obtain ⟨hj_mem, hj_eq⟩ := Finset.mem_filter.mp hj
      have hj' := Finset.mem_range.mp hj_mem
      exact ⟨j, Finset.mem_filter.mpr ⟨hj_mem, by rw [hmk j (by omega)]; exact hj_eq⟩⟩
  let π : (ℕ → ℕ) → (Fin (m + 1) → ℕ) := fun x i => x i
  let ext : (Fin (m + 1) → ℕ) → (ℕ → ℕ) := fun v k => if h : k < m + 1 then v ⟨k, h⟩ else 0
  have hfactor : (fun x => baireMarkerBits x m) = (fun v => baireMarkerBits (ext v) m) ∘ π := by
    funext x
    exact hlc x (ext (π x)) (fun k hk => by
      simp only [ext, π, dif_pos (Nat.lt_succ_of_le hk)])
  rw [hfactor]
  exact (continuous_of_discreteTopology).comp (continuous_pi fun i => continuous_apply (i : ℕ))

/-- The embedding of Baire space into `ℝ`: marker bits into the base-3 expansion. -/
noncomputable def embedBaireReal : (ℕ → ℕ) → ℝ :=
  fun x => Cardinal.cantorFunction (1 / 3) (baireMarkerBits x)

theorem continuous_cantorFunction_oneThird :
    Continuous (Cardinal.cantorFunction (1 / 3)) := by
  unfold Cardinal.cantorFunction
  refine continuous_tsum (fun n => ?_)
    (summable_geometric_of_lt_one (r := (1 : ℝ) / 3) (by norm_num) (by norm_num))
    (fun n f => ?_)
  · have hfac : (fun f : ℕ → Bool => Cardinal.cantorFunctionAux (1 / 3) f n)
        = (fun b : Bool => bif b then ((1 : ℝ) / 3) ^ n else 0) ∘ (fun f => f n) := rfl
    rw [hfac]
    exact continuous_of_discreteTopology.comp (continuous_apply n)
  · cases hb : f n
    · simp only [Cardinal.cantorFunctionAux, hb, Bool.cond_false, norm_zero]
      positivity
    · simp only [Cardinal.cantorFunctionAux, hb, Bool.cond_true, Real.norm_eq_abs]
      rw [abs_of_nonneg (by positivity : (0 : ℝ) ≤ (1 / 3) ^ n)]

theorem embedBaireReal_injective : Function.Injective embedBaireReal := by
  intro x y h
  exact baireMarkerBits_injective
    (Cardinal.cantorFunction_injective (by norm_num) (by norm_num) h)

theorem continuous_embedBaireReal : Continuous embedBaireReal :=
  continuous_cantorFunction_oneThird.comp continuous_baireMarkerBits

/-! ### The witness in the real line -/

/-- **An analytic non-Borel subset of `ℝ`**: the image of the Baire-space witness under the
continuous injection. Analyticity transfers along the continuous image; non-Borelness
transfers back along the injective preimage. -/
theorem exists_analyticSet_not_measurableSet_real :
    ∃ A : Set ℝ, MeasureTheory.AnalyticSet A ∧ ¬ MeasurableSet A := by
  obtain ⟨A₀, hA₀_an, hA₀_non⟩ := exists_analyticSet_not_measurableSet
  refine ⟨embedBaireReal '' A₀, hA₀_an.image_of_continuous continuous_embedBaireReal, ?_⟩
  intro hmeas
  apply hA₀_non
  have hpre : A₀ = embedBaireReal ⁻¹' (embedBaireReal '' A₀) :=
    (Set.preimage_image_eq A₀ embedBaireReal_injective).symm
  rw [hpre]
  exact continuous_embedBaireReal.measurable hmeas

end MeasureTheory
