/-
Copyright (c) 2026 Dhruv Gupta. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Dhruv Gupta
-/
import Lean
import Export.Parse
import Mathesis.Verdict
import Mathesis.Primitive.CheckProof
import Mathesis.Manifest

/-!
# `mathesis-adjudicate` — the security-critical re-derivation gate

An adversarial audit found the prior CI trusted RECORDED MANIFEST FIELDS (a deposit's
self-reported axiom list, self-reported replay status) instead of re-deriving them from the
export artifact itself. This executable is the fix: it loads the export text, PARSES it into an
`ExportedEnv` in-process, and RE-RUNS both the kernel replay (`CheckProof.replayLean`) and the
axiom-closure check (`CheckProof.checkAxioms`) from scratch. Nothing about admission is read from
the deposit's manifest — the manifest is not even an input to this program.

## The one property that makes this a gate and not theater

`permittedAxioms` below is a SOURCE CONSTANT: `propext`, `Classical.choice`, `Quot.sound`, and
nothing else. It is not a CLI argument, not a file, not an environment variable — there is no
runtime path by which a deposit (or a compromised caller) can widen it. Widening the permitted
axiom set requires editing and recompiling this file. That immutability IS the security property:
a self-describing deposit must never be able to expand what it is allowed to assume.

## CLI contract

    mathesis-adjudicate <export-path> -- <decl1> <decl2> ...

* `<export-path>` — a `lean4export` text artifact (the frozen/durable form `Manifest.loadFrozenText`
  reads).
* `--` — mandatory separator (mirrors `Manifest.freezeExportText`'s own argv convention).
* `<declN>` — target theorem names to adjudicate, in the *root* namespace as they appear in the
  export (e.g. `WMSpec.fiber_saturated`).

Emits one JSON object to stdout (schema in `main`'s doc) and exits 0 IFF the kernel replay is
accepted AND every target's axiom audit passes; 1 otherwise. Exit code is the actual gate — CI
should key on it, not on parsing the JSON.
-/

open Lean Export Mathesis Mathesis.CheckProof Mathesis.Manifest

namespace MathesisAdjudicate

/-! ### The immutable permitted-axiom whitelist (the security boundary) -/

/-- **THE permitted axiom set.** Exactly `propext`, `Classical.choice`, `Quot.sound` — Lean's three
standard noncomputable/quotient axioms, and nothing a deposit or its manifest can add to. Declared
`Array Name` (not read from argv/file/env) so that widening it is a source change, not a runtime
one. -/
def permittedAxioms : Array Name := #[``propext, ``Classical.choice, ``Quot.sound]

/-- The whitelist rendered as strings, for the JSON `permitted` field. -/
def permittedAxiomStrings : Array String := permittedAxioms.map (·.toString)

/-! ### `collectAxioms` — informative axiom-reachability traversal

Mirrors `CheckProof.Axioms.loop`'s worklist closure exactly, but ACCUMULATES every axiom it
reaches into a `Std.HashSet Name` instead of throwing on the first one outside `permitted`. This is
purely informative (the `axioms_reached` field of the report); the actual pass/fail gate decision
is `CheckProof.checkAxioms`, called separately below and unaffected by this function. -/

namespace CollectAxioms

structure Ctx where
  candidate : ExportedEnv

structure St where
  worklist : Array Name
  checked : Std.HashSet Name
  reached : Std.HashSet Name

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
    runForUsedConsts info visit
    modify fun s => { s with checked := s.checked.insert target }
    loop
where
  visit (n : Name) : M Unit := do
    let some info := (← read).candidate.constMap[n]?
      | throw s!"constant absent from candidate: '{n}'"
    if let .axiomInfo ax := info then
      modify fun s => { s with reached := s.reached.insert ax.name }
    if !(← get).checked.contains n then
      modify fun s => { s with worklist := s.worklist.push n }

end CollectAxioms

/-- Every axiom transitively reached from `target`'s proof value, in the candidate environment.
Purely informative — never gates. Returns `none` (with a note) rather than blocking the report if
the traversal itself fails (e.g. a dangling constant reference), since the pass/fail decision
comes from `checkAxioms` regardless. -/
def collectAxioms (candidate : ExportedEnv) (target : Name) : Array Name × Option String :=
  match candidate.constMap[target]? with
  | none => (#[], some s!"target absent from candidate: '{target}'")
  | some (.thmInfo tv) =>
    let worklist := tv.value.getUsedConstants
    let run := CollectAxioms.loop.run { candidate }
      |>.run { worklist, checked := {}, reached := {} }
    match run with
    | .ok ((), st) => (st.reached.toArray, none)
    | .error e => (#[], some e)
  | some _ => (#[], some s!"target is not a theorem: '{target}'")

/-! ### Per-target audit -/

/-- One target's audit result: the gate decision (`checkAxioms`, unchanged from Primitive 1) plus
the informative axiom traversal (`collectAxioms`, this file). -/
structure TargetAudit where
  decl : Name
  pass : Bool
  illegalAxiom : Option String
  axiomsReached : Array Name

/-- Run both the gate decision and the informative traversal for one target against `candidate`,
using the hard-coded `permittedAxioms`. `pass`/`illegalAxiom` are decided SOLELY by `checkAxioms`
(Primitive 1, unmodified); `collectAxioms`'s own traversal note (if its independent walk fails) is
never consulted for the gate decision — only `axiomsReached` comes from it. -/
def auditTarget (candidate : ExportedEnv) (decl : Name) : TargetAudit :=
  let (pass, illegalAxiom) :=
    match checkAxioms candidate #[decl] permittedAxioms with
    | .ok () => (true, none)
    | .error e => (false, some e)
  let (reached, _note) := collectAxioms candidate decl
  { decl, pass, illegalAxiom, axiomsReached := reached }

/-- Extract the illegal-axiom name from a `checkAxioms` error string, if the failure was in fact an
"illegal axiom reached" error (as opposed to some other failure like an absent constant). The error
strings are produced by `CheckProof.Axioms.loop.validateConst` (`s!"illegal axiom reached: '{ax}'"`)
— this parses that exact shape back out for the structured `illegal_axiom` field. -/
def extractIllegalAxiom (msg : String) : Option String :=
  -- Split on `'`: the message is exactly `illegal axiom reached: '<name>'`, so splitting on the
  -- quote yields `["illegal axiom reached: ", "<name>", ""]`. `splitOn` (unlike `take`/`dropRight`
  -- in this Std version) returns a stable `List String`, so this avoids the `String.Slice`
  -- migration entirely.
  match msg.splitOn "'" with
  | [pre, name, _] => if pre == "illegal axiom reached: " then some name else none
  | _ => none

/-! ### JSON assembly -/

def targetAuditToJson (t : TargetAudit) : Json :=
  Json.mkObj [
    ("decl", Json.str t.decl.toString),
    ("axiom_audit", Json.str (if t.pass then "pass" else "fail")),
    ("illegal_axiom",
      match t.illegalAxiom.bind extractIllegalAxiom with
      | some ax => Json.str ax
      | none => Json.null),
    ("axioms_reached", Json.arr (t.axiomsReached.map (Json.str ·.toString)))
  ]

/-! ### Argv parsing -/

/-- Split `<export-path> -- <decl1> <decl2> ...` into the export path and the target decl strings.
Requires the literal `--` separator (mirrors `Manifest.freezeExportText`'s own convention). -/
def parseArgs (args : List String) : Except String (String × List String) :=
  match args with
  | [] => .error "usage: mathesis-adjudicate <export-path> -- <decl1> <decl2> ..."
  | path :: rest =>
    match rest with
    | "--" :: decls =>
      if decls.isEmpty then
        .error "no target declarations given after '--'"
      else
        .ok (path, decls)
    | _ => .error "usage: mathesis-adjudicate <export-path> -- <decl1> <decl2> ... (missing '--')"

end MathesisAdjudicate

/-! ### `main`

Kept OUTSIDE `namespace MathesisAdjudicate`: `lean_exe`'s entry point must resolve to the top-level
symbol `main` (as in `MathesisSelfTest.RealReplay`'s `main`, which the linker also expects
unqualified) — a `main` declared inside a namespace compiles as `MathesisAdjudicate.main` and the
executable fails to link with "undefined symbol: main". -/

open MathesisAdjudicate in
/-- **`main`.** Loads the export, re-derives replay + per-target axiom closure from scratch
(NEVER trusts a recorded manifest field), emits the JSON report, and exits 0 IFF replay is accepted
AND every target's axiom audit passes.

Output schema (one line, compact JSON):

```
{"export": <path>,
 "constants": <number of constants in the parsed export>,
 "replay": {"accepted": <bool>, "detail": <string>},
 "permitted": ["propext", "Classical.choice", "Quot.sound"],
 "targets": [{"decl": <string>, "axiom_audit": "pass"|"fail",
              "illegal_axiom": <string|null>, "axioms_reached": [<string>, ...]}, ...],
 "verdict": "ADMITTED"|"REJECTED"}
```
-/
def main (args : List String) : IO UInt32 := do
  Lean.initSearchPath (← Lean.findSysroot)
  match parseArgs args with
  | .error msg =>
    IO.eprintln msg
    return 1
  | .ok (path, declStrs) =>
    let targets : Array Name := (declStrs.map (·.toName)).toArray
    let text ← IO.FS.readFile path
    let candidate ← loadFrozenText text
    let (accepted, detail) ← replayLean candidate
    let audits := targets.map (auditTarget candidate)
    let allPass := audits.all (·.pass)
    let verdictOk := accepted && allPass
    let json := Json.mkObj [
      ("export", Json.str path),
      ("constants", Json.num candidate.constMap.size),
      ("replay", Json.mkObj [("accepted", Json.bool accepted), ("detail", Json.str detail)]),
      ("permitted", Json.arr (permittedAxiomStrings.map Json.str)),
      ("targets", Json.arr (audits.map targetAuditToJson)),
      ("verdict", Json.str (if verdictOk then "ADMITTED" else "REJECTED"))
    ]
    IO.println json.compress
    return if verdictOk then 0 else 1
