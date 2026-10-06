import Lean

/-!
# `f32bits%`: a file of binary32 words, as numerals

`f32bits% "path"` is the binary counterpart of `include_str`. It reads the file at elaboration time
and produces an `Array Nat` literal: the file's 32-bit little-endian words, in order. It does not
decode them. Decoding is `decode32`, an ordinary definition applied inside the term, so the kernel
computes every value a claim depends on.

That division is the trust argument. Whatever an elaborator produces is checked by the kernel only
for type-correctness, not against the file it read, so an elaborator that decoded could write a
wrong value that nothing would ever re-examine. This one is trusted only for its transcription:
bytes, to 4-byte little-endian words, to numerals. Everything with meaning is a definition the kernel
evaluates and that theorems can be stated about.

As with `include_str`, the path is resolved against the directory of the current `.lean` file.
Elaboration fails if the file cannot be read or if its length is not a multiple of 4.
-/

open Lean Elab Term

namespace StetData

/-- The little-endian 32-bit words of `bytes`, whose size must be a multiple of 4:
`b0 + b1 · 2^8 + b2 · 2^16 + b3 · 2^24` for each group of four bytes. -/
def wordsLE (bytes : ByteArray) : Array Nat := Id.run do
  let mut ws : Array Nat := Array.emptyWithCapacity (bytes.size / 4)
  for i in [0:bytes.size / 4] do
    let b (j : Nat) : Nat := (bytes.get! (4 * i + j)).toNat
    ws := ws.push (b 0 + b 1 <<< 8 + b 2 <<< 16 + b 3 <<< 24)
  return ws

/-- `f32bits% "path"`: the little-endian binary32 words of the file at `path`, relative to the
directory of the current file, as an `Array Nat` literal. -/
syntax (name := f32bits) "f32bits% " str : term

@[term_elab f32bits] def elabF32Bits : TermElab := fun stx _ => do
  let some rel := stx[1].isStrLit? | throwUnsupportedSyntax
  let ctx ← readThe Core.Context
  let srcPath := System.FilePath.mk ctx.fileName
  let some srcDir := srcPath.parent
    | throwError "f32bits%: cannot compute the parent directory of `{srcPath}`"
  let bytes ← match ← (IO.FS.readBinFile (srcDir / rel)).toBaseIO with
    | .ok bytes => pure bytes
    | .error (.noFileOrDirectory ..) => throwError "f32bits%: cannot read `{rel}`: no such file"
    | .error e => throwError "f32bits%: cannot read `{rel}`: {e}"
  unless bytes.size % 4 == 0 do
    throwError "f32bits%: `{rel}` has {bytes.size} bytes, which is not a multiple of 4"
  return toExpr (wordsLE bytes)

end StetData
