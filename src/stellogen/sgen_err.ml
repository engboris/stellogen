open Base
open Common.Format_exn
open Sgen_ast

type ident = string

type err =
  | IllFormedChecker
  | ExpectedGalaxy
  | ReservedWord of ident
  | UnknownField of ident
  | UnknownID of ident
  | TestFailed of ident * ident * ident * galaxy * galaxy
  | LscError of Lsc_err.err_effect
