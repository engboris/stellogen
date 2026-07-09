open Base
open Constellation
open Expression_error

type ident = StellarRays.term

type idvar = string * int option

type idfunc = polarity * string

type source_location =
  { filename : string
  ; line : int
  ; column : int
  }

type sgen_expr =
  | Raw of StellarRays.term
  | Call of ident * source_location option
  | Exec of bool * sgen_expr * source_location option
  | Group of sgen_expr list (* Internal: for combining multiple expressions *)
  | Focus of sgen_expr
  | Def of ident * sgen_expr list
  | Forall of ident * ident * sgen_expr * source_location option
  | Show of sgen_expr list * source_location option
  | Expect of sgen_expr * sgen_expr * ident * source_location option
  | Match of sgen_expr * sgen_expr * ident * source_location option
  | Use of ident * source_location option

(* One #call unwound while looking for where an error originated:
   the identifier that was called, and the location of that call site. *)
type frame =
  { called : ident
  ; location : source_location option
  }

type err =
  | ExpectError of
      { got : Marked.constellation
      ; expected : Marked.constellation
      ; message : ident
      ; location : source_location option
      ; trace : frame list
      }
  | MatchError of
      { term1 : Marked.constellation
      ; term2 : Marked.constellation
      ; message : ident
      ; location : source_location option
      ; trace : frame list
      }
  | UnknownID of string * source_location option * frame list
  | ExprError of expr_err * source_location option * frame list

type env = { objs : (ident * sgen_expr) list }

let initial_env = { objs = [] }

type program = sgen_expr list
