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

/-- Collect the *structure type names* stored on `.proj` nodes anywhere in `e`.

`Expr.getUsedConstants` collects only `.const` occurrences; a projection `.proj S i s` carries its
structure type `S` as a bare `Name` field, NOT as an `Expr.const`, so `getUsedConstants` misses it.
Without this, a statement whose type reaches a constant only through a projection would never enqueue
that structure's `ConstantInfo` for comparison — letting a candidate smuggle a divergent definition
of `S` behind a byte-identical `.proj` node (statement-identity closure gap). Folded in alongside
`getUsedConstants` in `runForUsedConsts` so both the identity and axiom closures see projected types. -/
partial def collectProjTypes : Expr → Array Name → Array Name
  | .proj tn _ s, acc => collectProjTypes s (acc.push tn)
  | .app f a,       acc => collectProjTypes a (collectProjTypes f acc)
  | .lam _ t b _,   acc => collectProjTypes b (collectProjTypes t acc)
  | .forallE _ t b _, acc => collectProjTypes b (collectProjTypes t acc)
  | .letE _ t v b _, acc => collectProjTypes b (collectProjTypes v (collectProjTypes t acc))
  | .mdata _ b,     acc => collectProjTypes b acc
  | _,              acc => acc

/-- Canonicalize a declaration's type by renaming its universe parameters to a positional sequence,
so two types that differ ONLY in universe-parameter *names* compare equal. Used to bind a permitted
axiom NAME to its genuine kernel TYPE (below) without being fooled by the exporter naming a universe
parameter differently than `Init` does. -/
def canonLevels (levelParams : List Name) (type : Expr) : Expr :=
  let canon := (List.range levelParams.length).map fun i => Level.param (Name.mkSimple s!"_canonU{i}")
  type.instantiateLevelParams levelParams canon

/-- Does candidate constant `cand` agree with the trusted constant `genuine` of the same name?
Used to reject a candidate that REDEFINES a trusted logical-core constant (`Iff`, `Eq`, `False`, …)
— the fake-connective attack: a `prelude` deposit keeps a genuine-TYPED `propext` but fakes the
connectives its type names, deriving `True = False`. The name-only whitelist and the axiom
type-binding do not catch that; comparing every reached constant that also exists in the trusted
base does. `genuine` comes from a bank-owned `init.export` PARSED THE SAME WAY as the candidate
(both lean4export representation), so genuine constants match byte-for-byte and only a real
redefinition diverges (comparing against a freshly *imported* env fails — the representations
differ). Compares canonicalized TYPE, kind, inductive constructor list/arities, and definition
value; a theorem's proof is intentionally not compared. -/
def trustedMatches (cand genuine : ConstantInfo) : Bool :=
  cand.levelParams.length == genuine.levelParams.length
  && canonLevels cand.levelParams cand.type == canonLevels genuine.levelParams genuine.type
  && (match cand, genuine with
      | .inductInfo c, .inductInfo g =>
          c.ctors == g.ctors && c.numParams == g.numParams
            && c.numIndices == g.numIndices && c.all == g.all && c.isRec == g.isRec
      | .ctorInfo c, .ctorInfo g =>
          c.induct == g.induct && c.cidx == g.cidx
            && c.numParams == g.numParams && c.numFields == g.numFields
      | .axiomInfo _, .axiomInfo _ => true          -- type already compared above
      | .inductInfo _, _ | _, .inductInfo _ => false
      | .ctorInfo _, _ | _, .ctorInfo _ => false
      | .axiomInfo _, _ | _, .axiomInfo _ => false
      | _, _ =>
          match cand.value? (allowOpaque := false), genuine.value? (allowOpaque := false) with
          | some cv, some gv => canonLevels cand.levelParams cv == canonLevels genuine.levelParams gv
          | none, none => true
          | _, _ => false)

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
  (collectProjTypes info.type #[]).forM f
  f info.name
  if let some val := info.value? (allowOpaque := deep) then
    val.getUsedConstants.forM f
    (collectProjTypes val #[]).forM f
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
  /-- Genuine kernel `ConstantInfo` for each permitted axiom NAME, from a trusted base environment.
  Binds name→type so a permitted *name* declared with a non-genuine *type* (a spoof) is rejected.
  Empty ⇒ name-only (legacy) — callers that can supply the trusted types MUST, or the spoof is open. -/
  permittedTypes : Std.HashMap Name ConstantInfo := {}
  /-- Lookup into a TRUSTED base (a bank-owned `init.export`, parsed the same way as the candidate).
  Any reached constant whose name resolves here must match it (`trustedMatches`), else it is rejected
  as a redefinition of a trusted logical-core constant — this closes the fake-connective (`Iff`/`Eq`/
  `False`) class the axiom type-binding alone leaves open. `fun _ => none` ⇒ no base check (legacy). -/
  trusted : Name → Option ConstantInfo := fun _ => none

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
      -- Name-only whitelisting is spoofable: a `prelude` deposit can declare `axiom propext : <false>`
      -- and prove it (name matches, type is bogus). Bind each permitted NAME to its genuine kernel
      -- TYPE and reject a mismatch. (Message keeps the `illegal axiom reached: '<name>'` shape so the
      -- report's `illegal_axiom` field still names the offending axiom.)
      if let some genuine := (← read).permittedTypes[ax.name]? then
        if canonLevels ax.levelParams ax.type != canonLevels genuine.levelParams genuine.type then
          throw s!"illegal axiom reached: '{ax.name}' (permitted name declared with a non-genuine type — spoof)"
    -- Trusted-base redefinition check (ALL kinds): a reached constant whose name is in the trusted
    -- `init.export` must match it, else it is a redefinition of a trusted logical-core constant (a
    -- faked `Iff`/`Eq`/`False` used to derive falsehood under a genuine-typed `propext`).
    if let some genuine := (← read).trusted n then
      if !trustedMatches info genuine then
        throw s!"trusted constant redefined: '{n}' (candidate's declaration differs from the trusted init.export copy)"
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
def checkAxioms (candidate : ExportedEnv) (targets permitted : Array Name)
    (permittedTypes : Std.HashMap Name ConstantInfo := {})
    (trusted : Name → Option ConstantInfo := fun _ => none) :
    Except String Unit := do
  let mut worklist := #[]
  for target in targets do
    if !candidate.constMap.contains target then
      throw s!"target absent from candidate: '{target}'"
    worklist := worklist.push target
  Axioms.loop.run { candidate, permitted := Std.HashSet.ofArray permitted, permittedTypes, trusted }
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
    (kernels : Array KernelSpec := #[leanGatingKernel])
    (permittedTypes : Std.HashMap Name ConstantInfo := {})
    (trusted : Name → Option ConstantInfo := fun _ => none) : IO ProofReport := do
  let statement : LegResult :=
    match checkStatement reference candidate targets primitive with
    | .ok _ => .pass
    | .error e => .fail e
  let «axioms» : LegResult :=
    match checkAxioms candidate targets permitted permittedTypes trusted with
    | .ok _ => .pass
    | .error e => .fail e
  let mut outcomes : Array KernelOutcome := #[]
  for k in kernels do
    let (accepted, detail) ← k.replay candidate
    outcomes := outcomes.push
      { kernel := k.name, role := k.role, ran := true, accepted, detail }
  return { statement, «axioms», kernels := outcomes }

end Mathesis.CheckProof
