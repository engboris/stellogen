open Base
open Sgen_ast
open Lsc_ast

type err =
  | IllFormedChecker
  | ReservedWord of string
  | UnknownID of string
  | TestFailed of string * string * string * marked_constellation * marked_constellation
  | LscError of Lsc_err.err_effect
