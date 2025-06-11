open Base
open Sgen_ast

type err =
  | IllFormedChecker
  | ExpectedGalaxy
  | ReservedWord of string
  | UnknownField of string
  | UnknownID of string
  | TestFailed of string * string * string * galaxy * galaxy
  | LscError of Lsc_err.err_effect
