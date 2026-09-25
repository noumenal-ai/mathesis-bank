import Init.Data.List.Basic

/-!
# Mathesis deposit

@kind: result
@title: doubling is multiplying by two, and reversing twice is the identity
@module: Submission
@decls: Probe.double_eq, Probe.rev_rev
@pin: leanprover/lean4:v4.31.0

@gloss:
  Fixture for ci/test_two_part_fixtures.sh: a well-formed two-part deposit
  that the gate admits. The statement defines `double` and states two
  theorems, each proved by exactly `sorry`; the proof re-states the
  definition, adds a lemma of its own, and proves both.
-/

/-! @statement -/

namespace Probe

/-- Twice `n`. (A docstring may say sorry without being one.) -/
def double (n : Nat) : Nat := n + n

theorem double_eq (n : Nat) : double n = 2 * n := sorry

theorem rev_rev (l : List Nat) : l.reverse.reverse = l := by
  sorry

end Probe

/-! @proof -/

namespace Probe

/-- Twice `n`. (A docstring may say sorry without being one.) -/
def double (n : Nat) : Nat := n + n

theorem two_mul' (n : Nat) : 2 * n = n + n := by omega

theorem double_eq (n : Nat) : double n = 2 * n := by
  rw [two_mul']; rfl

theorem rev_rev (l : List Nat) : l.reverse.reverse = l := List.reverse_reverse l

end Probe
