open Base
open Lsc_ast

type ident = StellarRays.term

type idvar = string * int option

type idfunc = polarity * string

type sgen_expr =
  | Raw of marked_constellation
  | Id of ident
  | Exec of bool * sgen_expr
  | Union of sgen_expr list
  | Subst of sgen_expr * substitution
  | Focus of sgen_expr
  | Clean of sgen_expr
  | Kill of sgen_expr
  | Process of sgen_expr list
  | Eval of sgen_expr

and substitution =
  | Extend of idfunc
  | Reduce of idfunc
  | SVar of string * StellarRays.term
  | SFunc of idfunc * idfunc
  | SGal of ident * sgen_expr

type err =
  | ExpectError of marked_constellation * marked_constellation * ident
  | UnknownID of string

type env = { objs : (ident * sgen_expr) list }

let initial_env = { objs = [] }

type declaration =
  | Def of ident * sgen_expr
  | Show of sgen_expr
  | Trace of sgen_expr
  | Run of sgen_expr
  | Expect of ident * sgen_expr * ident
  | Use of ident list

type program = declaration list
