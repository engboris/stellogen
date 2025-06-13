open Base
open Lsc_ast
open Sgen_ast

type ident = string

module Raw = struct
  type t =
    | Symbol of string
    | Var of ident
    | Focus of t
    | Unquote of t
    | List of t list
    | Stack of t list
    | Cons of t list
end

type expr =
  | Symbol of string
  | Var of ident
  | Unquote of expr
  | List of expr list

let cons_op = "cons"

let unquote_op = "#"

let focus_op = "@"

let def_op = ":="

let typedef_op = "::"

let expect_op = "=="

let string_of_list lmark rmark l =
  l |> String.concat ~sep:" " |> fun l' ->
  Printf.sprintf "%s%s%s" lmark l' rmark

let rec to_string : expr -> string = function
  | Symbol s -> s
  | Var x -> x
  | Unquote e -> Printf.sprintf "%s%s" unquote_op (to_string e)
  | List es -> es |> List.map ~f:to_string |> string_of_list "(" ")"

let rec expand_macro : Raw.t -> expr = function
  | Raw.Symbol s -> Symbol s
  | Raw.Var x -> Var x
  | Raw.Unquote e' -> Unquote (expand_macro e')
  | Raw.Focus e' -> List [ Symbol focus_op; expand_macro e' ]
  | Raw.List es -> List (List.map ~f:expand_macro es)
  | Raw.Cons es ->
    List.fold_left es ~init:(Symbol "nil") ~f:(fun acc e ->
      List [ Symbol cons_op; expand_macro e; acc ] )
  | Raw.Stack [] -> List []
  | Raw.Stack (h :: t) ->
    List.fold_left t ~init:(expand_macro h) ~f:(fun acc e ->
      List [ expand_macro e; acc ] )

(* ---------------------------------------
   Constellation of Expr
   --------------------------------------- *)

let symbol_of_str (s : string) : idfunc =
  let rest = String.subo s ~pos:1 in
  match String.get s 0 with
  | '+' -> (Pos, rest)
  | '-' -> (Neg, rest)
  | _ -> (Null, s)

let rec ray_of_expr : expr -> ray = function
  | Symbol s -> to_func ((Muted, symbol_of_str s), [])
  | Var s -> to_var s
  | Unquote _ -> failwith "error: cannot unquote ray"
  | List [] -> failwith "error: ray cannot be empty"
  | List (Symbol h :: t) ->
    to_func ((Muted, symbol_of_str h), List.map ~f:ray_of_expr t)
  | List (_ :: _) -> failwith "error: ray must start with constant"
  | e -> failwith ("error: unhandled ray" ^ to_string e)

let rec star_of_expr : expr -> marked_star = function
  | Symbol "nil" -> Marked { content = []; bans = [] }
  | Symbol s -> Marked { content = []; bans = [] }
  | Var x -> Marked { content = []; bans = [] }
  | Unquote e -> Marked { content = []; bans = [] }
  | List [ Symbol s; h; t ] when equal_string s cons_op -> begin
    match star_of_expr t with
    | Marked { content = next_content; bans = next_bans } ->
      Marked { content = ray_of_expr h :: next_content; bans = next_bans }
  end
  | e -> failwith ("error: unhandled star" ^ to_string e)

let rec constellation_of_expr : expr -> marked_constellation = function
  | Symbol "nil" -> []
  | Symbol s -> [ Unmarked { content = [ var (s, None) ]; bans = [] } ]
  | Var x -> [ Unmarked { content = [ var (x, None) ]; bans = [] } ]
  | Unquote e -> failwith "error: can't unquote constellation"
  | List [ Symbol s; h; t ] when equal_string s cons_op ->
    star_of_expr h :: constellation_of_expr t
  | List g -> [ Unmarked { content = [ ray_of_expr (List g) ]; bans = [] } ]
  | e -> failwith ("error: unhandled constellation " ^ to_string e)

(* ---------------------------------------
   Galaxy expr of Expr
   --------------------------------------- *)

let rec galaxy_expr_of_expr : expr -> galaxy_expr = function
  (* ray *)
  | Symbol s ->
    Raw (Const [ Unmarked { content = [ ray_of_expr (Symbol s) ]; bans = [] } ])
  (* id *)
  | Unquote g -> Id (ray_of_expr g)
  (* focus @ *)
  | List [ Symbol k; g ] when equal_string k focus_op ->
    Focus (galaxy_expr_of_expr g)
  (* union *)
  | List (Symbol k :: gs) when equal_string k "union" ->
    Union (List.map ~f:galaxy_expr_of_expr gs)
  (* exec *)
  | List [ Symbol k; g ] when equal_string k "exec" ->
    Exec (galaxy_expr_of_expr g)
  (* linear exec *)
  | List [ Symbol k; g ] when equal_string k "linexec" ->
    LinExec (galaxy_expr_of_expr g)
  (* raw constellation *)
  | List g -> Raw (Const (constellation_of_expr (List g)))

(* ---------------------------------------
   Stellogen program of Expr
   --------------------------------------- *)

let rec decl_of_expr : expr -> declaration = function
  (* definition := *)
  | List [ Symbol k; x; g ] when equal_string k def_op ->
    Def (ray_of_expr x, galaxy_expr_of_expr g)
  (* show *)
  | List [ Symbol k; g ] when equal_string k "show" ->
    Show (galaxy_expr_of_expr g)
  (* trace *)
  | List [ Symbol k; g ] when equal_string k "trace" ->
    Show (galaxy_expr_of_expr g)
  (* expect *)
  | List [ Symbol k; x; g ] when equal_string k expect_op ->
    TypeDef (TExp (ray_of_expr x, galaxy_expr_of_expr g))
  | _ -> failwith "error: invalid declaration"

let program_of_expr = List.map ~f:decl_of_expr
