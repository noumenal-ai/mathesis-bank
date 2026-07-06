/-!
# Mathesis deposit
@kind: result
@title: Honest discharge
@module: Submission
@decls: fib_key
@pin: leanprover/lean4:v4.31.0
@discharges: MTH.C-TEST-0001
@gloss:
  discharge test
-/
def Q (n:Nat):Prop := 100 < n
def P (n:Nat):Prop := Q n
theorem fib_key : P 200 := by unfold P Q; decide
