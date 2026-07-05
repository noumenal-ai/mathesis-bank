/-
Copyright (c) 2026 Dhruv Gupta. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Dhruv Gupta
-/
import Mathesis.Verdict
import Mathesis.Primitive.CheckProof
import Mathesis.Primitive.RunWitness
import Mathesis.Manifest
import Mathesis.Adjudicate

/-!
# Mathesis — the evidence bank's Lean core

Part 1 (this build): Primitive 1, `Mathesis.CheckProof.checkProof` — the constraint-admission
gate, generalized from Comparator to the bank's `(R, S, K)` form. Later parts add Primitive 2
(`runWitness`, the C witness-execution harness bound in-kernel), the four legs, the trusted
statement extractor (`Manifest`), and the orchestrator (`Adjudicate`).
-/
