open Base
open Lsc_ast

type err =
  | IllFormedChecker
  | ReservedWord of string
  | UnknownID of string
  | LscError of Lsc_err.err_effect

type ident = StellarRays.term

type idvar = string * int option

type idfunc = polarity * string

type ray_prefix = StellarRays.fmark * idfunc

and sgen_expr =
  | Raw of marked_constellation
  | Id of ident
  | Exec of sgen_expr
  | LinExec of sgen_expr
  | Union of sgen_expr list
  | Subst of sgen_expr * substitution
  | Focus of sgen_expr
  | Clean of sgen_expr
  | Kill of sgen_expr
  | Process of sgen_expr list
  | Eval of sgen_expr

and substitution =
  | Extend of ray_prefix
  | Reduce of ray_prefix
  | SVar of string * StellarRays.term
  | SFunc of (StellarRays.fmark * idfunc) * (StellarRays.fmark * idfunc)
  | SGal of ident * sgen_expr

let reserved_words = [ const "clean"; const "kill" ]

let is_reserved = List.mem reserved_words ~equal:equal_ray

type env =
  { objs : (ident * sgen_expr) list
  ; types : (ident * (ident * ident option) list) list
  }

let initial_env =
  { objs = [ (const "^empty", Raw []) ]
  ; types = [ (const "^empty", [ (const "^empty", None) ]) ]
  }

type declaration =
  | Def of ident * sgen_expr
  | Show of sgen_expr
  | Trace of sgen_expr
  | Run of sgen_expr
  | Expect of ident * sgen_expr
  | Use of ident list

type program = declaration list
