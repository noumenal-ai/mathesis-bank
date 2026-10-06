/-!
# `decode32`: an IEEE-754 binary32 word to a dyadic rational

`decode32 w` reads `w` as the bits of a binary32 value (IEEE 754-2019, §3.4) and returns its exact
value as a `Dyadic`, or `none` when `w` is not a finite value: ±∞, every NaN, and every `w ≥ 2^32`
(the argument is a `Nat`, so its type does not bound it).

It works on `Nat` with `&&&`, `>>>` and `^`, which the kernel computes natively, rather than on
`UInt32`, whose operations reduce through `BitVec` and `Fin`.

What this is not:
* "Every finite binary32 value is a dyadic" holds here by construction, because `decode32` returns
  a `Dyadic`. It is not a theorem of this package.
* `decode32` is not injective. `+0` and `−0` both give `0`, and every non-finite word gives `none`,
  so a round trip back to bits can hold only for the other words.
* That `decode32` matches IEEE 754 is tested against an independent oracle (`tests/diff`), not
  proved.
-/

/-- The exact value of the binary32 word `w`: `none` for ±∞, every NaN and every `w ≥ 2^32`.
With sign bit `s`, exponent field `E` and fraction field `F`, the value is `(−1)^s · F · 2^(−149)`
when `E = 0` (subnormal, or zero) and `(−1)^s · (2^23 + F) · 2^(E − 150)` when `1 ≤ E ≤ 254`. -/
def decode32 (w : Nat) : Option Dyadic :=
  if w < 2 ^ 32 then
    let E := (w >>> 23) &&& 0xFF
    let F := w &&& 0x7FFFFF
    if E = 255 then none
    else
      -- `Dyadic.ofIntWithPrec m k` is `m · 2^(−k)`.
      let m : Nat := if E = 0 then F else 2 ^ 23 + F
      let k : Int := if E = 0 then 149 else 150 - (E : Int)
      let m : Int := if w >>> 31 = 1 then -(m : Int) else m
      some (Dyadic.ofIntWithPrec m k)
  else none
