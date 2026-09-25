/-!
# Mathesis deposit

@kind: claim
@title: every even number above two is a sum of two primes
@module: Submission
@decls: Probe.goldbach
@pin: leanprover/lean4:v4.31.0

@gloss:
  Fixture for ci/test_two_part_fixtures.sh: a claim posed without a proof.
  The gate builds and checks the statement, exports it as the reference R,
  keeps R, and stops with the verdict `posed`.
-/

/-! @statement -/

namespace Probe

/-- `p` is prime: at least two, and divisible only by one and itself. -/
def IsPrime (p : Nat) : Prop := 2 ≤ p ∧ ∀ d : Nat, d ∣ p → d = 1 ∨ d = p

theorem goldbach (n : Nat) (h : 2 < n) (he : n % 2 = 0) :
    ∃ p q : Nat, IsPrime p ∧ IsPrime q ∧ p + q = n := by
  sorry

end Probe
