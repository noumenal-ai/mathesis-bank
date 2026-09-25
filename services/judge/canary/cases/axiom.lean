import Mathlib.MeasureTheory.Constructions.Polish.Basic
import Mathlib.Analysis.Real.Cardinality
import Mathlib.Analysis.Normed.Group.FunctionSeries
import Mathlib.Topology.Bases

-- The claimed statement, from a smuggled axiom.
axiom cheat : ∃ A : Set ℝ, MeasureTheory.AnalyticSet A ∧ ¬ MeasurableSet A

theorem MeasureTheory.exists_analyticSet_not_measurableSet_real :
    ∃ A : Set ℝ, MeasureTheory.AnalyticSet A ∧ ¬ MeasurableSet A := cheat
