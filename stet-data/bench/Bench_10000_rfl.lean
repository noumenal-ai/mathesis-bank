import StetData

/-- 10000 random finite binary32 values, decoded by the kernel. -/
def S : List (Option Dyadic) := (f32bits% "10000.f32").toList.map decode32

example : Dyadic.blt (S.filterMap id).sum (Dyadic.ofIntWithPrec 1 (-200)) = true := rfl
