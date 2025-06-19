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
    | ConsWithParams of t list * t list
end

type expr =
  | Symbol of string
  | Var of ident
  | Unquote of expr
  | List of expr list

let nil_op = "$nil"

let cons_op = "$cons"

let unquote_op = "#"

let focus_op = "@"

let def_op = ":="

let typedef_op = "::"

let expect_op = "=="

let params_op = "$params"

let ineq_op = "!="

let incomp_op = "!@"

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
    List.fold_left es ~init:(Symbol nil_op) ~f:(fun acc e ->
      List [ Symbol cons_op; expand_macro e; acc ] )
  | Raw.ConsWithParams (es, ps) ->
    List [ Symbol params_op; expand_macro (Cons es); expand_macro (List ps) ]
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
  | Unquote e -> to_func ((Muted, (Null, "#")), [ ray_of_expr e ])
  | List [] -> failwith "error: ray cannot be empty"
  | List (Symbol h :: t) ->
    to_func ((Muted, symbol_of_str h), List.map ~f:ray_of_expr t)
  | List (_ :: _) -> failwith "error: ray must start with constant"

let bans_of_expr : expr list -> ban list =
  let ban_of_expr = function
    | List [ Symbol k; a; b ] when equal_string k ineq_op ->
      Ineq (ray_of_expr a, ray_of_expr b)
    | List [ Symbol k; a; b ] when equal_string k incomp_op ->
      Incomp (ray_of_expr a, ray_of_expr b)
    | _ -> failwith "error: invalid ban expression"
  in
  List.map ~f:ban_of_expr

let rec raylist_of_expr (e : expr) : ray list =
  match e with
  | Symbol k when equal_string k nil_op -> []
  | Symbol _ | Var _ -> [ ray_of_expr e ]
  | Unquote e -> failwith ("error: cannot unquote star " ^ to_string e)
  | List [ Symbol s; h; t ] when equal_string s cons_op ->
    ray_of_expr h :: raylist_of_expr t
  | e -> failwith ("error: unhandled star " ^ to_string e)

let rec star_of_expr : expr -> marked_star = function
  | List [ Symbol k; s ] when equal_string k focus_op ->
    star_of_expr s |> Lsc_ast.remove_mark |> Lsc_ast.mark
  | List [ Symbol k; s; List ps ] when equal_string k params_op ->
    Unmarked { content = raylist_of_expr s; bans = bans_of_expr ps }
  | e -> Unmarked { content = raylist_of_expr e; bans = [] }

let rec constellation_of_expr : expr -> marked_constellation = function
  | Symbol k when equal_string k nil_op -> []
  | Symbol s -> [ Unmarked { content = [ var (s, None) ]; bans = [] } ]
  | Var x -> [ Unmarked { content = [ var (x, None) ]; bans = [] } ]
  | Unquote e -> failwith ("error: can't unquote constellation" ^ to_string e)
  | List [ Symbol s; h; t ] when equal_string s cons_op ->
    star_of_expr h :: constellation_of_expr t
  | List g -> [ Unmarked { content = [ ray_of_expr (List g) ]; bans = [] } ]

(* ---------------------------------------
   Stellogen expr of Expr
   --------------------------------------- *)

let is_cons = function
  | List [ Symbol s; _; _ ] when equal_string s cons_op -> true
  | _ -> false

let rec contains_cons = function
  | List [ Symbol s; h; t ] when equal_string s cons_op ->
    is_cons h || contains_cons t
  | _ -> false

let rec sgen_expr_of_expr (e : expr) : sgen_expr =
  match e with
  (* ray *)
  | Var _ | Symbol _ ->
    Raw [ Unmarked { content = [ ray_of_expr e ]; bans = [] } ]
  (* star *)
  | List [ Symbol s; h; t ]
    when equal_string s cons_op && (not @@ is_cons h) && (not @@ contains_cons t)
    ->
    Raw [ star_of_expr e ]
  (* id *)
  | Unquote g -> Id (ray_of_expr g)
  (* focus @ *)
  | List [ Symbol k; g ] when equal_string k focus_op ->
    Focus (sgen_expr_of_expr g)
  (* union *)
  | List (Symbol k :: gs) when equal_string k "union" ->
    Union (List.map ~f:sgen_expr_of_expr gs)
  (* process *)
  | List (Symbol k :: gs) when equal_string k "process" ->
    Process (List.map ~f:sgen_expr_of_expr gs)
  (* kill *)
  | List [ Symbol k; g ] when equal_string k "kill" ->
    Kill (sgen_expr_of_expr g)
  (* clean *)
  | List [ Symbol k; g ] when equal_string k "clean" ->
    Clean (sgen_expr_of_expr g)
  (* exec *)
  | List [ Symbol k; g ] when equal_string k "exec" ->
    Exec (sgen_expr_of_expr g)
  (* linear exec *)
  | List [ Symbol k; g ] when equal_string k "linexec" ->
    LinExec (sgen_expr_of_expr g)
  (* linear exec *)
  | List [ Symbol k; g ] when equal_string k "eval" ->
    Eval (sgen_expr_of_expr g)
  (* KEEP LAST -- raw constellation *)
  | List g -> Raw (constellation_of_expr (List g))

(* ---------------------------------------
   Stellogen program of Expr
   --------------------------------------- *)

(* let typedecl_of_expr : expr -> type_declaration = function
  | Symbol k when equal_string k nil_op -> []
  | List [ Symbol k; h; t ] when equal_string k cons_op ->
*)

let decl_of_expr : expr -> declaration = function
  (* definition := *)
  | List [ Symbol k; x; g ] when equal_string k def_op ->
    Def (ray_of_expr x, sgen_expr_of_expr g)
  | List [ Symbol k; x; g ] when equal_string k "spec" ->
    Def (ray_of_expr x, sgen_expr_of_expr g)
  (* type declaration :: *)
  (* | List [ Symbol k; x; g ] when equal_string k typedef_op ->
    Typedecl (ray_of_expr x, typedecl_of_expr g) *)
  (* show *)
  | List [ Symbol k; g ] when equal_string k "show" ->
    Show (sgen_expr_of_expr g)
  (* trace *)
  | List [ Symbol k; g ] when equal_string k "trace" ->
    Trace (sgen_expr_of_expr g)
  (* expect *)
  | List [ Symbol k; x; g ] when equal_string k expect_op ->
    Expect (ray_of_expr x, sgen_expr_of_expr g)
  | _ -> failwith "error: invalid declaration"

let program_of_expr = List.map ~f:decl_of_expr
