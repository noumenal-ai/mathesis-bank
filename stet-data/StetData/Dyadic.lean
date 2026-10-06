/-!
# Dyadic rationals

Step 1 uses core's `Dyadic` (`Init.Data.Dyadic`, in every Lean file without an import) and adds
nothing to it. What the plan's design asked of a dyadic type, core already provides:

* **One form per value.** A `Dyadic` is `.zero` or `.ofOdd n k _`, the value `n · 2^(−k)` with `n`
  odd. Equal values therefore have equal forms, so the derived `DecidableEq` decides equality of
  values, by comparing literals. `Dyadic.ofIntWithPrec i k` builds `i · 2^(−k)` from any `i`,
  removing trailing zero bits with fuel taken from `i` itself (`Int.trailingZeros`), so it reaches
  the normal form for every input.
* **Exact arithmetic.** `+`, `*`, `-` and negation are exact on dyadics. Step 1 uses no division and
  no rounding. A sum of a list is `List.sum`.
* **Order.** `x < y` is `Dyadic.blt x y = true` and `x ≤ y` is `Dyadic.ble x y = true`, both
  decidable. Core proves these agree with the order of the rationals: `Dyadic.blt_iff_toRat` and
  `Dyadic.ble_iff_toRat`. Agreement with the real numbers would need Mathlib, which step 1 does not
  use.

Notation in this package: the plan writes `⟨m, e⟩` for the value `m · 2^e`. In core's form that is
`.ofOdd m (-e) _`, and `⟨0, 0⟩` is `.zero`.
-/
