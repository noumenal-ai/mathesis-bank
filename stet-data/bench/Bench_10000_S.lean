import StetData

/-- 10000 random finite binary32 values, decoded by the kernel. -/
def S : List (Option Dyadic) := (f32bits% "10000.f32").toList.map decode32
