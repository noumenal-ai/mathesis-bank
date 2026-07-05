/-
Copyright (c) 2026 Dhruv Gupta. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Dhruv Gupta
-/
import Lean
import Export.Parse
import Mathesis.Primitive.CheckProof

/-!
# Manifest — the trusted reference extractor (freezes `R`)

The security boundary of the whole gate (oscillation O1): the reference statement `R` against which
untrusted candidates are checked must come from the **bank's trusted build over Dictionary-admitted
definitions at claim-admission time**, NOT from the untrusted deposit's environment. If `R` were
re-extracted from the deposit, the attacker would control its definitional context `Δ` and
statement-identity would be vacuous.

So `R` is *frozen*: extracted once, at claim-admission, and stored as the accession's immutable
reference. `Adjudicate` later *loads* that frozen `R` and never rebuilds it.

Two representations of the frozen `R`:
* `referenceExport` — an in-process `ExportedEnv` closed over the statement's constant graph from a
  trusted `Environment`. This is the trusted extractor when the bank holds the claim in-process.
* `freezeExportText` — the durable form: run `lean4export` on the claim module (under isolation)
  and keep the resulting text; it round-trips through `Export.parseStream` (verified against the
  lean4export/Comparator API). The text is the immutable accession artifact (deck: "DOI resolves to
  an immutable snapshot"). This is the IO boundary, run under landrun on the bank VM.
-/

namespace Mathesis.Manifest

open Lean Export

/-! ### In-process reference extraction (the trusted-environment freeze) -/

/-- Every constant referenced by `ci`, collected into an array (reuses the gate's traversal). -/
def usedConstsOf (ci : ConstantInfo) : Array Name :=
  (Mathesis.CheckProof.runForUsedConsts (m := StateM (Array Name)) ci
    (fun n => modify (·.push n))).run #[] |>.2

/-- Worklist closure building a constant map from a trusted environment. -/
partial def buildConstMap (env : Environment) (work : Array Name)
    (cm : Std.HashMap Name ConstantInfo) (seen : Std.HashSet Name) :
    Std.HashMap Name ConstantInfo :=
  if work.isEmpty then cm
  else
    let n := work.back!
    let rest := work.pop
    if seen.contains n then buildConstMap env rest cm seen
    else match env.find? n with
      | some ci => buildConstMap env (rest ++ usedConstsOf ci) (cm.insert n ci) (seen.insert n)
      | none => buildConstMap env rest cm (seen.insert n)

/-- **TEST-ONLY. Do NOT use to freeze `R` for ingestion (finding F7).** This in-process extractor
closes over `stmtDecls` using the `getUsedConstants` worklist, which UNDER-CLOSES the kernel
dependency graph: on a real statement it produces ~11 constants where the true `lean4export` closure
is ~384, and the resulting env FAILS `replayLean` (`unknown constant 'sorryAx'`-style). It is kept
only for in-process fixture tests where the env is never replayed. The ingestion/freeze path MUST
use `freezeExportText` (the real `lean4export` binary), whose output is complete and replay-accepts;
callers should assert `replayLean` accepts the frozen `R` before banking it. -/
def referenceExport (env : Environment) (stmtDecls : Array Name) : ExportedEnv :=
  { constMap := buildConstMap env stmtDecls {} {}, constOrder := stmtDecls }

/-! ### Durable text freeze (IO boundary; round-trips via `parseStream`) -/

/-- Deserialize a frozen `lean4export` text artifact back into an `ExportedEnv`. This is how
`Adjudicate` loads a durably-frozen `R` (from the accession) without rebuilding it. Uses a String
byte-stream (Comparator's `stringStream` idiom). -/
def loadFrozenText (exportText : String) : IO ExportedEnv := do
  let ref ← IO.mkRef { data := exportText.toUTF8 : IO.FS.Stream.Buffer }
  Export.parseStream (IO.FS.Stream.ofBuffer ref)

/-- **Durable freeze (IO boundary).** Run `lean4export` on the bank's claim `module`, exporting
`decls` (+ the kernel primitives), returning the export text to persist as the immutable accession
reference. Mirrors Comparator's `safeExport`; in production this call is wrapped by isolation
(landrun) on the bank VM. `lean4exportBin` is the path to the pinned exporter. -/
def freezeExportText (lean4exportBin : String) (module : Name) (decls : Array Name) : IO String := do
  let args := #[module.toString (escape := false), "--"]
    ++ decls.map (·.toString (escape := false))
  let out ← IO.Process.output { cmd := lean4exportBin, args }
  if out.exitCode != 0 then
    throw <| .userError s!"lean4export failed on {module}: {out.stderr}"
  return out.stdout

end Mathesis.Manifest
