open Base
open Lsc_ast
open Expr_err

type ident = StellarRays.term

type idvar = string * int option

type idfunc = polarity * string

type source_location =
  { filename : string
  ; line : int
  ; column : int
  }

type sgen_expr =
  | Raw of Marked.constellation
  | Call of ident
  | Exec of bool * sgen_expr
  | Group of sgen_expr list
  | Focus of sgen_expr
  | Process of sgen_expr list
  | Eval of sgen_expr
  | Def of ident * sgen_expr
  | Show of sgen_expr
  | Expect of sgen_expr * sgen_expr * ident * source_location option
  | Match of sgen_expr * sgen_expr * ident * source_location option
  | Use of ident

type err =
  | ExpectError of
      { got : Marked.constellation
      ; expected : Marked.constellation
      ; message : ident
      ; location : source_location option
      }
  | MatchError of
      { term1 : Marked.constellation
      ; term2 : Marked.constellation
      ; message : ident
      ; location : source_location option
      }
  | UnknownID of string * source_location option
  | ExprError of expr_err * source_location option

type env = { objs : (ident * sgen_expr) list }

let initial_env = { objs = [] }

type program = sgen_expr list
