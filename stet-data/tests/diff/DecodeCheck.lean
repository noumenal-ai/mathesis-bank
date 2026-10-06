import StetData.Float32

/-!
# The Lean half of the differential test

For each hex word on stdin, or for every 32-bit word with `--all`, print `decode32` of it in the
oracle's format: `none`, or `m e` for the value `m · 2^e` in normal form (`m` odd, or `0 0`).

This runs `decode32` as compiled code. The checks in `StetData/Examples.lean` run it in the kernel.
Both evaluate the same definition.
-/

/-- `decode32 w` as the oracle prints it. Core's `.ofOdd n k _` is the value `n · 2^(−k)`. -/
def render : Option Dyadic → String
  | none => "none"
  | some .zero => "0 0"
  | some (.ofOdd n k _) => s!"{n} {-k}"

/-- The value of a hexadecimal numeral, or `none` if it has a character that is not a hex digit. -/
def parseHex (s : String) : Option Nat :=
  s.foldl (init := some 0) fun acc c => acc.bind fun n =>
    if '0' ≤ c ∧ c ≤ '9' then some (16 * n + (c.toNat - '0'.toNat))
    else if 'a' ≤ c ∧ c ≤ 'f' then some (16 * n + (c.toNat - 'a'.toNat + 10))
    else if 'A' ≤ c ∧ c ≤ 'F' then some (16 * n + (c.toNat - 'A'.toNat + 10))
    else none

def main (args : List String) : IO UInt32 := do
  let stdout ← IO.getStdout
  if args == ["--all"] then
    for w in [0:2 ^ 32] do
      stdout.putStrLn (render (decode32 w))
    return 0
  let stdin ← IO.getStdin
  repeat
    let line ← stdin.getLine
    if line.isEmpty then break
    let s := line.trimAsciiEnd.toString
    match parseHex s with
    | some w => stdout.putStrLn (render (decode32 w))
    | none =>
      IO.eprintln s!"decodecheck: not a hex word: {s}"
      return 2
  return 0
