import Lake
open Lake DSL

package StetData

@[default_target]
lean_lib StetData

@[default_target]
lean_exe decodecheck where
  root := `DecodeCheck
  srcDir := "tests/diff"
