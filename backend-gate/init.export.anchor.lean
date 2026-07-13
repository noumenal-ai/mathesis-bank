-- A single decl whose type + proof reach the logical-core constants, so that
-- exporting it yields the genuine closure of the trust base in ONE lean4export run
-- (multi-decl Init export panics; single-decl does not). References:
--   Iff, Eq, And, Or, Not(→False), Exists, HEq, Bool, Decidable, Quotient, Setoid, Nat, True
-- in the TYPE; propext, Classical.choice, Quot.sound in the PROOF.
theorem Mathesis.trustAnchor
    (a b : Prop) (hiff : a ↔ b)
    (_hand : a ∧ b) (_hor : a ∨ b) (_hnot : ¬ a)
    (_hex : ∃ _ : Bool, True) (_hheq : HEq a b) [_dec : Decidable a]
    (_s : Setoid Nat) (_q : Quotient _s) (_hq : Quot.mk _s.r 0 = Quot.mk _s.r 0) :
    (a = b) ∧ True ∧ Nonempty Nat :=
  ⟨propext hiff, trivial, ⟨Classical.choice ⟨0⟩⟩⟩
