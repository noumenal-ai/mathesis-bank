/-
Copyright (c) 2026 Dhruv Gupta. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Dhruv Gupta
-/
import Lean
import Export.Parse
import Mathesis.Verdict
import Mathesis.Primitive.CheckProof

/-!
# Primitive 2 — `runWitness` (the witness-execution leg; "loop closed in-kernel")

The witness leg of the adjudication gate. Its ratified shape (GATE.md): the C witness-execution
harness is a **named numeric trust boundary** ("numbers computed in C while Lean owns every
decision") — it runs the float32 artifact at native speed and *reports* its output; it is not
trusted to be right. The leg reduces to

  ω  =  checkProof(the deposit's interval-membership + binding theorems)   [Primitive 1, kernel-owned]
     ∧  transcript-binding(kernel-checked value == the value the harness actually emitted)   [NEW]

The **transcript-binding** is the anti-cheat: without it an author could kernel-prove
`membership(favorable value)` while the harness actually computed something else. The bank runs the
harness on the deposit's *declared* input and requires the kernel-checked theorem to be about that
emitted value. For the ∃-shaped witnesses that are the bank's founding genre (non-identifiability,
counterexamples), the declared input *is* the claim, so there is no cherry-pick hole.

This file owns the harness ABI, the parse, and the binding decision; the kernel work is delegated
to `Mathesis.CheckProof` (Primitive 1) — π and ω are the same type, as the derivation requires.
-/

namespace Mathesis.RunWitness

open Lean Export

/-- What the C harness reports on stdout: the raw executed bits (for transcript binding) and the
exact dyadic-rational decode it computed (the "number computed in C"). ABI line:
`"<bits_hex> <num> <den>"`. -/
structure HarnessOutput where
  bitsHex : String
  valueNum : Int
  valueDen : Nat
  deriving Repr, DecidableEq, Inhabited

/-- Parse one ABI line `"0x.... <num> <den>"`. Rejects anything malformed (fool-proofing: a
malformed emission is not silently coerced). -/
def parseHarness (s : String) : Option HarnessOutput := do
  let parts := (s.trim.splitOn " ").filter (·.length > 0)
  match parts with
  | [b, n, d] => do
    let num ← n.toInt?
    let den ← d.toNat?
    if den == 0 then none else some { bitsHex := b, valueNum := num, valueDen := den }
  | _ => none

/-- Run the (untrusted, numeric-boundary) C harness and parse its output. `none` on nonzero exit or
malformed stdout. The caller runs this under isolation (landrun/VM); the harness never decides
anything — Lean does. -/
def runHarness (cmd : String) (args : Array String := #[]) : IO (Option (HarnessOutput × String)) := do
  let out ← IO.Process.output { cmd := cmd, args := args }
  if out.exitCode != 0 then
    return none
  match parseHarness out.stdout with
  | some ho => return some (ho, out.stdout.trim)
  | none => return none

/-- The witness report: the transcript-binding decision, the kernel-owned membership proof
(Primitive 1), and a transcript hash. -/
structure WitnessReport where
  binding : LegResult
  membership : ProofReport
  transcriptHash : UInt64
  observed : Option HarnessOutput
  deriving Repr, Inhabited

/-- The witness leg ADMITS iff the harness output binds to the deposit's declared executed value
AND the kernel admits the interval-membership/binding theorems. -/
def WitnessReport.admits (w : WitnessReport) : Bool :=
  w.binding.ok && w.membership.admits

/-- **Primitive 2.** Run the harness on the deposit's declared input, bind its output to the
declared executed value (transcript-binding), and kernel-check the deposit's membership theorem via
Primitive 1. `reference`/`candidate` are the exported environments of the deposit's membership
statement and its proof (as in Primitive 1); `declared*` are the executed value the membership
theorem is stated over (bank-side, from the claim). -/
def checkWitness
    (harnessCmd : String) (harnessArgs : Array String)
    (declaredBits : String) (declaredNum : Int) (declaredDen : Nat)
    (reference candidate : ExportedEnv)
    (membershipThm : Name) (permitted primitive : Array Name)
    (kernels : Array CheckProof.KernelSpec := #[CheckProof.leanGatingKernel]) :
    IO WitnessReport := do
  match ← runHarness harnessCmd harnessArgs with
  | none =>
    return { binding := .fail "harness failed or emitted malformed output",
             membership := { statement := .fail "not evaluated", «axioms» := .fail "not evaluated", kernels := #[] },
             transcriptHash := 0, observed := none }
  | some (ho, transcript) =>
    let binding : LegResult :=
      if ho.bitsHex == declaredBits && ho.valueNum == declaredNum && ho.valueDen == declaredDen then
        .pass
      else
        .fail s!"transcript-binding: harness emitted {ho.bitsHex} {ho.valueNum}/{ho.valueDen}, \
declared {declaredBits} {declaredNum}/{declaredDen}"
    let membership ← CheckProof.checkProof reference candidate #[membershipThm] permitted primitive kernels
    return { binding, membership, transcriptHash := hash transcript, observed := some ho }

end Mathesis.RunWitness
