import StetData

/-- 1000 random finite binary32 values, decoded by the kernel. -/
def S : List (Option Dyadic) := (f32bits% "1000.f32").toList.map decode32
