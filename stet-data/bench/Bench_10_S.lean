import StetData

/-- 10 random finite binary32 values, decoded by the kernel. -/
def S : List (Option Dyadic) := (f32bits% "10.f32").toList.map decode32
