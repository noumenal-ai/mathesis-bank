import StetData.Dyadic
import StetData.Float32

/-!
# Checks

Each `check_…` below is an executed computation on concrete values, closed by `decide`. They are
checks, not theorems about the data in general: each one only records that a computation came out
as stated.

The expected values were written down in the plan before any code ran (section 6, checked against
hardware floats). The plan writes `⟨m, e⟩` for `m · 2^e`; here that is `.ofOdd m (-e) rfl`, and
`⟨0, 0⟩` is `.zero`. The plan's `Dyadic.mk' m e` is `Dyadic.ofIntWithPrec m (-e)`.
-/

/-! ## Dyadic (step 1b) -/

/-- `4 · 2^(−1)` normalises to `1 · 2^1`: two zero bits are stripped. -/
theorem check_normal_form : Dyadic.ofIntWithPrec 4 1 = .ofOdd 1 (-1) rfl := by decide

theorem check_zero_normal_form : Dyadic.ofIntWithPrec 0 (-7) = .zero := by decide

/-- `3 + 1/2 = 7/2`. -/
theorem check_add : Dyadic.ofIntWithPrec 3 0 + Dyadic.ofIntWithPrec 1 1 = .ofOdd 7 1 rfl := by
  decide

/-- `−2.5 < 1`. -/
theorem check_lt : Dyadic.ofIntWithPrec (-5) 1 < Dyadic.ofIntWithPrec 1 0 := by decide

/-- `2^(−149) < 2^(−126)`, a large exponent gap. -/
theorem check_lt_exponent_gap : Dyadic.ofIntWithPrec 1 149 < Dyadic.ofIntWithPrec 1 126 := by
  decide

/-! ## `decode32` on table A (step 1c) -/

theorem check_decode_pos_zero : decode32 0x00000000 = some .zero := by decide
theorem check_decode_neg_zero : decode32 0x80000000 = some .zero := by decide
theorem check_decode_one : decode32 0x3F800000 = some (.ofOdd 1 0 rfl) := by decide
theorem check_decode_tenth : decode32 0x3DCCCCCD = some (.ofOdd 13421773 27 rfl) := by decide
theorem check_decode_neg_two_and_half : decode32 0xC0200000 = some (.ofOdd (-5) 1 rfl) := by
  decide
theorem check_decode_min_subnormal : decode32 0x00000001 = some (.ofOdd 1 149 rfl) := by decide
theorem check_decode_max_subnormal : decode32 0x007FFFFF = some (.ofOdd 8388607 149 rfl) := by
  decide
theorem check_decode_min_normal : decode32 0x00800000 = some (.ofOdd 1 126 rfl) := by decide
theorem check_decode_max_finite : decode32 0x7F7FFFFF = some (.ofOdd 16777215 (-104) rfl) := by
  decide
theorem check_decode_pos_inf : decode32 0x7F800000 = none := by decide
theorem check_decode_neg_inf : decode32 0xFF800000 = none := by decide
theorem check_decode_quiet_nan : decode32 0x7FC00000 = none := by decide
theorem check_decode_signalling_nan : decode32 0x7F800001 = none := by decide
theorem check_decode_out_of_range : decode32 (2 ^ 32) = none := by decide
