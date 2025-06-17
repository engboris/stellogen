open Base
open Lsc_ast

type ident = StellarRays.term

type idvar = string * int option

type idfunc = polarity * string

type ray_prefix = StellarRays.fmark * idfunc

type type_declaration =
  | TDef of ident * (ident * ident option) list
  | TExp of ident * galaxy_expr

and galaxy =
  | Const of marked_constellation
  | Galaxy of galaxy_declaration list
  | Interface of type_declaration list

and galaxy_declaration =
  | GTypeDef of type_declaration
  | GLabelDef of ident * galaxy_expr

and galaxy_expr =
  | Raw of galaxy
  | Access of galaxy_expr * ident
  | Id of ident
  | Exec of galaxy_expr
  | LinExec of galaxy_expr
  | Union of galaxy_expr list
  | Subst of galaxy_expr * substitution
  | Focus of galaxy_expr
  | Clean of galaxy_expr
  | Kill of galaxy_expr
  | Process of galaxy_expr list
  | Eval of galaxy_expr

and substitution =
  | Extend of ray_prefix
  | Reduce of ray_prefix
  | SVar of string * StellarRays.term
  | SFunc of (StellarRays.fmark * idfunc) * (StellarRays.fmark * idfunc)
  | SGal of ident * galaxy_expr

let reserved_words = [ const "clean"; const "kill" ]

let is_reserved = List.mem reserved_words ~equal:equal_ray

type env =
  { objs : (ident * galaxy_expr) list
  ; types : (ident * (ident * ident option) list) list
  }

let expect (g : galaxy_expr) : galaxy_expr =
  Raw
    (Galaxy
       [ GLabelDef (const "interaction", Id (const "tested"))
       ; GLabelDef (const "expect", g)
       ] )

let initial_env =
  { objs = [ (const "^empty", Raw (Const [])) ]
  ; types = [ (const "^empty", [ (const "^empty", None) ]) ]
  }

type declaration =
  | Def of ident * galaxy_expr
  | Show of galaxy_expr
  | Trace of galaxy_expr
  | Run of galaxy_expr
  | TypeDef of type_declaration
  | Use of ident list

type program = declaration list
