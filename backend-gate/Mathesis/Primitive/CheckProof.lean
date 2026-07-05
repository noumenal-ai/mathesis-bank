/-
Copyright (c) 2026 Dhruv Gupta. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Dhruv Gupta

The statement-identity and axiom-closure algorithms are adapted, in generalized form, from
leanprover/Comparator (Apache-2.0, Lean FRO, LLC; author Henrik Böving): `Comparator.Compare`,
`Comparator.Axioms`, `Comparator.Util`, and the kernel-replay of `Comparator.Main`.
-/
import Lean
import Export.Parse
import Lean4Checker.Replay
import Mathesis.Verdict

/-!
# Primitive 1 — `checkProof` (constraint-admission)

The general form of the adjudication gate's proof primitive. Given

* a reference environment `R` — the frozen statement of a banked accession, exported once, bank-owned;
* a candidate environment `S` — the untrusted deposit, built and exported under isolation;
* target names, permitted axioms, and the kernel's built-in primitive constants;
* a kernel set `K` partitioned `gating | shadow`,

it decides three things and reports them as a `ProofReport`:

1. **statement identity** — the candidate's target declarations prove *the same statement* as the
   reference (environment-based comparison closed over every constant the statement mentions);
   defeats statement-substitution;
2. **axiom closure** — no axiom outside `permitted` is reached from any target's proof value;
3. **kernel replay** — every gating kernel accepts the candidate; every shadow kernel runs
   silently, and disagreement is surfaced as a soundness event.

This is Comparator's core generalized in three ways that make it the bank's gate rather than a CI
script: `R` is an arbitrary exported environment (a banked accession, not a local `Challenge`
module rebuilt each run); `K` is a *set* with a gating/shadow partition (nanoda demoted to silent
shadow); and the result is a structured `ProofReport`, not a first-failure `Except`.
-/

namespace Mathesis.CheckProof

open Lean Export

/-! ### Constant traversal (generalized `Comparator.runForUsedConsts`) -/

/-- Run `f` on every constant referenced by `info`: the constants in its type, its own name, the
constants in its value, and the structural children of inductives/constructors/recursors.

`deep` controls whether a value that `ConstantInfo.value?` hides by default is walked:
`value?` defaults to `allowOpaque := false`, which returns `none` for a `.thmInfo` (a theorem's
PROOF) and for `.opaqueInfo`. So:
* `deep := false` — statement identity. Walks types and DEFINITION bodies (a smuggled `def` body is
  still caught) but NOT a theorem's proof (two different proofs of the same statement are the same
  statement).
* `deep := true` — axiom closure. Walks the proof/opaque body too. This is MANDATORY for the axiom
  audit: a `sorry` or any illegal axiom reached only through a theorem's proof is otherwise invisible
  (the earlier F4 generalization routed the axiom audit through this traversal with the shallow
  default and thereby silently stopped auditing theorem proofs — a proof-side soundness hole). -/
def runForUsedConsts {m : Type → Type} [Monad m] (info : ConstantInfo) (deep : Bool)
    (f : Name → m Unit) : m Unit := do
  info.type.getUsedConstants.forM f
  f info.name
  if let some val := info.value? (allowOpaque := deep) then
    val.getUsedConstants.forM f
  match info with
  | .axiomInfo .. | .quotInfo .. | .defnInfo .. | .thmInfo .. | .opaqueInfo .. => pure ()
  | .inductInfo iv => iv.ctors.forM f; iv.all.forM f
  | .ctorInfo cv => f cv.induct
  | .recInfo rv => rv.rules.forM fun rule => do f rule.ctor; rule.rhs.getUsedConstants.forM f

deriving instance BEq for QuotKind
deriving instance BEq for QuotVal
deriving instance BEq for InductiveVal
deriving instance BEq for ConstantInfo

/-! ### Leg 1a — statement identity (generalized `Comparator.compareAt`) -/

namespace Statement

structure Ctx where
  reference : ExportedEnv
  candidate : ExportedEnv

structure St where
  worklist : Array Name
  checked : Std.HashSet Name

abbrev M := ReaderT Ctx <| StateT St <| Except String

/-- Close over the statement's constant graph, requiring the reference and candidate to agree on
every reached constant. Any divergence in a definition the statement depends on is caught here. -/
partial def loop : M Unit := do
  if (← get).worklist.isEmpty then
    return ()
  let target ← modifyGet fun s => (s.worklist.back!, { s with worklist := s.worklist.pop })
  if (← get).checked.contains target then
    loop
  else
    let some refConst := (← read).reference.constMap[target]?
      | throw s!"constant absent from reference: '{target}'"
    let some candConst := (← read).candidate.constMap[target]?
      | throw s!"constant absent from candidate: '{target}'"
    if refConst != candConst then
      throw s!"constant diverges between reference and candidate: '{target}'"
    -- shallow: statement identity is about types + definition bodies, never proof terms.
    runForUsedConsts candConst (deep := false) fun n => do
      if !(← get).checked.contains n then
        modify fun s => { s with worklist := s.worklist.push n }
    modify fun s => { s with checked := s.checked.insert target }
    loop

end Statement

/-- **Statement identity.** Each target must exist in both environments as the same kind
(theorem/axiom) with the same `ConstantVal` (type), and every constant its type transitively
mentions must agree. `primitive` seeds the worklist with the kernel's built-in constants. -/
def checkStatement (reference candidate : ExportedEnv) (targets primitive : Array Name) :
    Except String Unit := do
  let mut worklist := primitive
  for target in targets do
    let some refConst := reference.constMap[target]?
      | throw s!"target absent from reference: '{target}'"
    let some candConst := candidate.constMap[target]?
      | throw s!"target absent from candidate: '{target}'"
    let (refVal, candVal) ←
      match refConst, candConst with
      | .thmInfo r, .thmInfo c => pure (r.toConstantVal, c.toConstantVal)
      | .axiomInfo r, .axiomInfo c => pure (r.toConstantVal, c.toConstantVal)
      | _, _ => throw s!"target kind differs between reference and candidate: '{target}'"
    if refVal != candVal then
      throw s!"target statement differs between reference and candidate: '{target}'"
    worklist := worklist ++ refVal.type.getUsedConstants
  Statement.loop.run { reference, candidate } |>.run' { worklist, checked := {} }

/-! ### Leg 1b — axiom closure (generalized `Comparator.checkAxioms`) -/

namespace Axioms

structure Ctx where
  candidate : ExportedEnv
  permitted : Std.HashSet Name

structure St where
  worklist : Array Name
  checked : Std.HashSet Name

abbrev M := ReaderT Ctx <| StateT St <| Except String

partial def loop : M Unit := do
  if (← get).worklist.isEmpty then
    return ()
  let target ← modifyGet fun s => (s.worklist.back!, { s with worklist := s.worklist.pop })
  if (← get).checked.contains target then
    loop
  else
    let some info := (← read).candidate.constMap[target]?
      | throw s!"constant absent from candidate: '{target}'"
    -- deep: the axiom audit MUST walk theorem proofs + opaque bodies (or a proof-side sorry hides).
    runForUsedConsts info (deep := true) validateConst
    modify fun s => { s with checked := s.checked.insert target }
    loop
where
  validateConst (n : Name) : M Unit := do
    let some info := (← read).candidate.constMap[n]?
      | throw s!"constant absent from candidate: '{n}'"
    if let .axiomInfo ax := info then
      if !(← read).permitted.contains ax.name then
        throw s!"illegal axiom reached: '{ax.name}'"
    if !(← get).checked.contains n then
      modify fun s => { s with worklist := s.worklist.push n }

end Axioms

/-- **Axiom closure.** Every axiom transitively reached from any target's FULL dependency graph
(its type, its value, and its structural children) must lie in `permitted`.

Kind-agnostic (finding F4): the target may be a `thmInfo` (audits the proof), a `defnInfo`/
`opaqueInfo` (audits the body — so a poisoned `def` whose body reaches `sorryAx` is caught, not
only theorems), or even an `axiomInfo` (audited against `permitted` directly). Seeding the worklist
with the target itself makes `Axioms.loop` close over `runForUsedConsts`, which visits type + name +
value + children — this also audits a theorem's TYPE-side constants (matching `#print axioms`
closure), which the previous proof-value-only seeding missed. -/
def checkAxioms (candidate : ExportedEnv) (targets permitted : Array Name) :
    Except String Unit := do
  let mut worklist := #[]
  for target in targets do
    if !candidate.constMap.contains target then
      throw s!"target absent from candidate: '{target}'"
    worklist := worklist.push target
  Axioms.loop.run { candidate, permitted := Std.HashSet.ofArray permitted }
    |>.run' { worklist, checked := {} }

/-! ### Leg 1c — kernel replay -/

/-- Replay the candidate's constant map through the built-in Lean kernel (the gating kernel), from
source, via `Lean4Checker`'s `Environment.replay'`. Adding `Quot` primitives is done by the kernel
when it processes them, so they are erased from the replay map (as in `Comparator.Main.runKernel`). -/
def replayLean (candidate : ExportedEnv) : IO (Bool × String) := do
  try
    let env ← mkEmptyEnvironment
    let constMap := candidate.constMap.erase ``Quot.mk |>.erase ``Quot.lift |>.erase ``Quot.ind
    discard <| env.replay' constMap
    return (true, "lean kernel accepts")
  catch e =>
    return (false, toString e)

/-- A kernel in the set `K`: a name, a role, and a replay action returning (accepted, detail). -/
structure KernelSpec where
  name : String
  role : KernelRole
  replay : ExportedEnv → IO (Bool × String)

/-- The built-in Lean kernel as the default gating kernel. -/
def leanGatingKernel : KernelSpec :=
  { name := "lean", role := .gating, replay := replayLean }

/-! ### The primitive -/

/-- **Primitive 1.** Run all three legs and assemble the `ProofReport`. Statement identity and
axiom closure are pure; each kernel in `kernels` replays the candidate (gating decide admission,
shadow cross-check silently). -/
def checkProof (reference candidate : ExportedEnv)
    (targets permitted primitive : Array Name)
    (kernels : Array KernelSpec := #[leanGatingKernel]) : IO ProofReport := do
  let statement : LegResult :=
    match checkStatement reference candidate targets primitive with
    | .ok _ => .pass
    | .error e => .fail e
  let «axioms» : LegResult :=
    match checkAxioms candidate targets permitted with
    | .ok _ => .pass
    | .error e => .fail e
  let mut outcomes : Array KernelOutcome := #[]
  for k in kernels do
    let (accepted, detail) ← k.replay candidate
    outcomes := outcomes.push
      { kernel := k.name, role := k.role, ran := true, accepted, detail }
  return { statement, «axioms», kernels := outcomes }

end Mathesis.CheckProof
