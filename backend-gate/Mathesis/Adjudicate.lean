/-
Copyright (c) 2026 Dhruv Gupta. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Dhruv Gupta
-/
import Lean
import Export.Parse
import Mathesis.Verdict
import Mathesis.Primitive.CheckProof
import Mathesis.Primitive.RunWitness
import Mathesis.Manifest

/-!
# Adjudicate — the orchestrator

Turns the two verified primitives into a deposit-gating pipeline, composing the legs into the
three-valued `Verdict` under the derived preconditions:

* **O1 (frozen R).** `referenceR` is the immutable reference loaded from the accession (frozen by
  `Manifest` at claim time). `adjudicate` NEVER rebuilds it — that is the security boundary.
* **O2 (pin precondition).** A toolchain-pin mismatch short-circuits to `blocked` *before* the
  kernel runs; comparing exports across kernels is semantically hollow.
* **O3 (three-valued verdict).** Preconditions (pin) and completeness (a witnessed-tier claim
  submitted without its witness) `block`; a failed mechanical leg `reject`s; otherwise `admitted`.

The real pipeline runs the untrusted build + `lean4export` under isolation (landrun on the bank VM,
FLT-solved) to produce `candidateS`; that IO boundary is upstream of this pure composition.
-/

namespace Mathesis.Adjudicate

open Lean Export Mathesis Mathesis.CheckProof Mathesis.RunWitness

/-- A demonstration deposit presented to the gate. -/
structure Deposit where
  accession : String
  accessionPin : String
  depositPin : String
  /-- The FROZEN reference statement, loaded from the accession (never rebuilt here). -/
  referenceR : ExportedEnv
  /-- The untrusted deposit's exported environment (built under isolation upstream). -/
  candidateS : ExportedEnv
  targets : Array Name
  permitted : Array Name
  primitive : Array Name := #[]
  /-- Claim tier ≥ T1 ⇒ a witness is required for admission. -/
  requiresWitness : Bool := false
  /-- The witness-leg result, if the deposit carries one (`Mathesis.RunWitness`). -/
  witness : Option WitnessReport := none
  kernels : Array KernelSpec := #[leanGatingKernel]

/-- The aggregate verdict on a deposit. -/
structure Verdict where
  accession : String
  pinMatch : Bool
  requiredWitnessMissing : Bool
  proof : ProofReport
  witness : Option WitnessReport
  deriving Inhabited

/-- Fold legs + preconditions into the three-valued `Admission`. -/
def Verdict.admission (v : Verdict) : Admission :=
  if !v.pinMatch then .blocked
  else if v.requiredWitnessMissing then .blocked
  else if !v.proof.admits then .rejected
  else match v.witness with
    | some w => if w.admits then .admitted else .rejected
    | none => .admitted

/-- **The orchestrator.** Pin precondition (O2) → Primitive 1 over the frozen `R` and untrusted `S`
(O1: Σ + π) → witness completeness (O3). Returns the full `Verdict`; `Verdict.admission` gives the
three-valued result. -/
def adjudicate (d : Deposit) : IO Verdict := do
  if d.depositPin != d.accessionPin then
    return { accession := d.accession, pinMatch := false, requiredWitnessMissing := false,
             proof := { statement := .fail s!"toolchain pin mismatch: deposit '{d.depositPin}' ≠ accession '{d.accessionPin}'",
                        «axioms» := .fail "not evaluated (pin mismatch)", kernels := #[] },
             witness := d.witness }
  let proof ← checkProof d.referenceR d.candidateS d.targets d.permitted d.primitive d.kernels
  let missing := d.requiresWitness && d.witness.isNone
  return { accession := d.accession, pinMatch := true, requiredWitnessMissing := missing,
           proof, witness := d.witness }

end Mathesis.Adjudicate
