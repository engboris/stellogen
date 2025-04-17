open Base
open Lsc_ast

type ident = string

type idvar = string * int option

type idfunc = polarity * string

type ray_prefix = StellarRays.fmark * idfunc

type type_declaration =
  | TDef of ident * ident list * ident option
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
  | Union of galaxy_expr * galaxy_expr
  | Subst of galaxy_expr * substitution
  | Focus of galaxy_expr
  | Process of galaxy_expr list

and substitution =
  | Extend of ray_prefix
  | Reduce of ray_prefix
  | SVar of ident * StellarRays.term
  | SFunc of (StellarRays.fmark * idfunc) * (StellarRays.fmark * idfunc)
  | SGal of ident * galaxy_expr

let reserved_words = [ "clean"; "kill" ]

let is_reserved = List.mem reserved_words ~equal:equal_string

type env =
  { objs : (ident * galaxy_expr) list
  ; types : (ident * (ident list * ident option)) list
  }

let expect (g : galaxy_expr) : galaxy_expr =
  Raw (Galaxy [ GLabelDef ("expect", g) ])

let initial_env =
  { objs = [ ("^empty", Raw (Const [])) ]
  ; types = [ ("^empty", ([ "^empty" ], None)) ]
  }

type declaration =
  | Def of ident * galaxy_expr
  | Show of galaxy_expr
  | ShowExec of galaxy_expr
  | Trace of galaxy_expr
  | Run of galaxy_expr
  | TypeDef of type_declaration
  | ProofDef of ident * ident list * ident option * galaxy_expr

type program = declaration list
