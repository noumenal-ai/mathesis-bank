/-
Copyright (c) 2026 Dhruv Gupta. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Dhruv Gupta
-/

/-!
# Verdict — the structured result of the adjudication gate

Primitive 1 (`Mathesis.CheckProof`) emits a `ProofReport`: a full account of every leg rather than
a first-failure abort, so the bank records *why* a deposit did or did not admit. `KernelRole`
partitions the kernel set `K`: gating kernels must accept; shadow kernels (e.g. nanoda) run
silently and non-gatingly, and a shadow disagreeing with the gating consensus is a
kernel-soundness event that FREEZES the deposit (it is not an acceptance and not an ordinary
rejection).
-/

namespace Mathesis

/-- A kernel's role in `K`. Gating kernels decide admission; shadow kernels run silently for
soundness cross-checking and never gate. -/
inductive KernelRole where
  | gating
  | shadow
  deriving Repr, BEq, DecidableEq, Inhabited

/-- The result of a single leg check: pass, or fail with the precise reason (a Pl-kill is content). -/
inductive LegResult where
  | pass
  | fail (reason : String)
  deriving Repr, Inhabited

def LegResult.ok : LegResult → Bool
  | .pass => true
  | .fail _ => false

/-- The outcome of replaying the candidate through one kernel. `ran = false` records a shadow
kernel that was unavailable (e.g. the nanoda binary is not installed): unavailable shadows are
skipped, not counted as divergence. -/
structure KernelOutcome where
  kernel : String
  role : KernelRole
  ran : Bool
  accepted : Bool
  detail : String := ""
  deriving Repr, Inhabited

/-- The report of Primitive 1 over one candidate against its reference statement. -/
structure ProofReport where
  statement : LegResult
  «axioms» : LegResult
  kernels : Array KernelOutcome
  deriving Repr, Inhabited

/-- Every gating kernel that ran accepted. -/
def ProofReport.gatingAccepts (r : ProofReport) : Bool :=
  r.kernels.all fun o => o.role != KernelRole.gating || !o.ran || o.accepted

/-- A shadow kernel that ran and disagreed with the gating consensus: a kernel-soundness event. -/
def ProofReport.shadowDivergence (r : ProofReport) : Bool :=
  let gating := r.gatingAccepts
  r.kernels.any fun o => o.role == KernelRole.shadow && o.ran && o.accepted != gating

/-- The gate ADMITS the proof leg iff statement identity holds, the axiom closure is permitted,
every gating kernel accepts, and no shadow kernel diverged. A divergence freezes rather than
admits. -/
def ProofReport.admits (r : ProofReport) : Bool :=
  r.statement.ok && r.«axioms».ok && r.gatingAccepts && !r.shadowDivergence

/-- Human-readable one-line status. -/
def ProofReport.status (r : ProofReport) : String :=
  if r.shadowDivergence then "FROZEN (kernel-soundness event: shadow divergence)"
  else if r.admits then "ADMITTED"
  else "REJECTED"

/-- Three-valued admission of a demonstration deposit (the O3 oscillation). `blocked` is NOT
`rejected`: `rejected` means a mechanical leg failed (the math/claim is wrong); `blocked` means a
*precondition or completeness* condition is unmet (toolchain pin mismatch, or a witnessed-tier
claim submitted without its witness) — resubmittable, the deposit is not yet adjudicable, and no
statement about its correctness is made. `admitted` means every required leg passed at the pinned
toolchain. -/
inductive Admission where
  | admitted
  | rejected
  | blocked
  deriving Repr, BEq, DecidableEq, Inhabited

def Admission.toString : Admission → String
  | .admitted => "ADMITTED"
  | .rejected => "REJECTED"
  | .blocked => "BLOCKED (precondition/completeness unmet; resubmittable)"

end Mathesis
