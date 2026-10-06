import StetData

/-- 100 random finite binary32 values, decoded by the kernel. -/
def S : List (Option Dyadic) := (f32bits% "100.f32").toList.map decode32

example : (S.filterMap id).sum < Dyadic.ofIntWithPrec 1 (-200) := by decide +kernel
