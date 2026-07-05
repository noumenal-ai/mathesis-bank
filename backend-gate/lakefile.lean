import Lake
open Lake DSL

package mathesis where
  leanOptions := #[⟨`autoImplicit, false⟩]

require lean4export from git
  "https://github.com/leanprover/lean4export" @ "ca36c44858e2d7ba40996203d2f08a69113d1211"

require Lean4Checker from git
  "https://github.com/leanprover/lean4checker" @ "b7398199245524275543dec6113229c9bb4902e5"

@[default_target]
lean_lib Mathesis where
  globs := #[Glob.andSubmodules `Mathesis]

/-- The re-derivation gate the public CI runs: `mathesis-adjudicate <export> -- <decls>`,
exit 0 iff replay accepts AND every target's axiom closure ⊆ the hard-coded whitelist. -/
lean_exe «mathesis-adjudicate» where
  root := `MathesisAdjudicate
  supportInterpreter := true
