open Base
open Lsc_ast
open Sgen_ast
open Expr_err

let ( let* ) x f = Result.bind x ~f

type ident = string

module Raw = struct
  type t =
    | Symbol of string
    | Var of ident
    | String of string
    | Focus of t
    | Call of t
    | List of t list
    | Stack of t list
    | Group of t list
    | Cons of t list
    | ConsWithParams of t list * t list
    | ConsWithBase of t list * t
end

type expr =
  | Symbol of string
  | Var of ident
  | List of expr list
[@@derive eq]

let primitive = String.append "%"

let nil_op = primitive "nil"

let cons_op = primitive "cons"

let call_op = "#"

let focus_op = "@"

let string_op = primitive "string"

let def_op = ":="

let expect_op = "=="

let params_op = primitive "params"

let ineq_op = "!="

let incomp_op = "slice"

let group_op = "%group"

let rec to_string : expr -> string = function
  | Symbol s -> s
  | Var x -> x
  | List es ->
    Printf.sprintf "(%s)" (List.map ~f:to_string es |> String.concat ~sep:" ")

let rec expand_macro : Raw.t -> expr = function
  | Raw.Symbol s -> Symbol s
  | Raw.Var x -> Var x
  | Raw.String s -> List [ Symbol string_op; Symbol s ]
  | Raw.Call e' -> List [ Symbol call_op; expand_macro e' ]
  | Raw.Focus e' -> List [ Symbol focus_op; expand_macro e' ]
  | Raw.Group es -> List (Symbol group_op :: List.map ~f:expand_macro es)
  | Raw.List es -> List (List.map ~f:expand_macro es)
  | Raw.Cons es -> expand_macro (Raw.ConsWithBase (es, Symbol nil_op))
  | Raw.ConsWithBase (es, base) ->
    List.fold_left es ~init:(expand_macro base) ~f:(fun acc e ->
      List [ Symbol cons_op; expand_macro e; acc ] )
  | Raw.ConsWithParams (es, ps) ->
    List [ Symbol params_op; expand_macro (Cons es); expand_macro (List ps) ]
  | Raw.Stack [] -> List []
  | Raw.Stack (h :: t) ->
    List.fold_left t ~init:(expand_macro h) ~f:(fun acc e ->
      List [ expand_macro e; acc ] )

let rec replace_id (var_from : ident) replacement expr =
  match expr with
  | Var x when String.equal x var_from -> replacement
  | Symbol _ | Var _ -> expr
  | List exprs -> List (List.map exprs ~f:(replace_id var_from replacement))

let unfold_decl_def (macro_env : (string * (string list * expr list)) list)
  exprs =
  let process_expr (env, acc) = function
    | List (Symbol "new-declaration" :: List (Symbol macro_name :: args) :: body)
      ->
      let var_args =
        List.map args ~f:(function
          | Var x -> x
          | _ -> failwith "error: syntax declaration must contain variables" )
      in
      ((macro_name, (var_args, body)) :: env, acc)
    | List (Symbol macro_name :: call_args) as expr -> (
      match List.Assoc.find env macro_name ~equal:String.equal with
      | Some (formal_params, body) ->
        if List.length formal_params <> List.length call_args then
          failwith
            (Printf.sprintf "Error: macro '%s' expects %d args, got %d"
               macro_name
               (List.length formal_params)
               (List.length call_args) )
        else
          let apply_substitution expr =
            List.fold_left (List.zip_exn formal_params call_args) ~init:expr
              ~f:(fun acc (param, arg) -> replace_id param arg acc )
          in
          let expanded = List.map body ~f:apply_substitution |> List.rev in
          (env, expanded @ acc)
      | None -> (env, expr :: acc) )
    | expr -> (env, expr :: acc)
  in
  List.fold_left exprs ~init:(macro_env, []) ~f:process_expr |> snd |> List.rev

(* ---------------------------------------
   Constellation of Expr
   --------------------------------------- *)

let symbol_of_str (symbol : string) : idfunc =
  match String.get symbol 0 with
  | '+' -> (Pos, String.subo symbol ~pos:1)
  | '-' -> (Neg, String.subo symbol ~pos:1)
  | _ -> (Null, symbol)

let rec ray_of_expr : expr -> (ray, expr_err) Result.t = function
  | Symbol s -> to_func (symbol_of_str s, []) |> Result.return
  | Var "_" -> to_var ("_" ^ fresh_placeholder ()) |> Result.return
  | Var s -> to_var s |> Result.return
  | List [] -> Error EmptyRay
  | List (Symbol h :: t) ->
    let* args = List.map ~f:ray_of_expr t |> Result.all in
    to_func (symbol_of_str h, args) |> Result.return
  | List (_ :: _) as e -> Error (NonConstantRayHeader (to_string e))

let bans_of_expr ban_exprs : (ban list, expr_err) Result.t =
  let ban_of_expr = function
    | List [ Symbol op; expr1; expr2 ] when String.equal op ineq_op ->
      let* ray1 = ray_of_expr expr1 in
      let* ray2 = ray_of_expr expr2 in
      Ineq (ray1, ray2) |> Result.return
    | List [ Symbol op; expr1; expr2 ] when String.equal op incomp_op ->
      let* ray1 = ray_of_expr expr1 in
      let* ray2 = ray_of_expr expr2 in
      Incomp (ray1, ray2) |> Result.return
    | invalid_expr -> Error (InvalidBan (to_string invalid_expr))
  in
  List.map ban_exprs ~f:ban_of_expr |> Result.all

let rec raylist_of_expr expr : (ray list, expr_err) Result.t =
  match expr with
  | Symbol k when String.equal k nil_op -> Ok []
  | Symbol _ | Var _ ->
    let* ray = ray_of_expr expr in
    Ok [ ray ]
  | List [ Symbol op; head; tail ] when String.equal op cons_op ->
    let* head_ray = ray_of_expr head in
    let* tail_rays = raylist_of_expr tail in
    Ok (head_ray :: tail_rays)
  | invalid -> Error (InvalidRaylist (to_string invalid))

let rec star_of_expr : expr -> (Marked.star, expr_err) Result.t = function
  | List [ Symbol k; s ] when equal_string k focus_op ->
    let* ss = star_of_expr s in
    ss |> Marked.remove |> Marked.make_state |> Result.return
  | List [ Symbol k; s; List ps ] when equal_string k params_op ->
    let* content = raylist_of_expr s in
    let* bans = bans_of_expr ps in
    Marked.Action { content; bans } |> Result.return
  | e ->
    let* content = raylist_of_expr e in
    Marked.Action { content; bans = [] } |> Result.return

let rec constellation_of_expr :
  expr -> (Marked.constellation, expr_err) Result.t = function
  | Symbol s ->
    [ Marked.Action { content = [ var (s, None) ]; bans = [] } ]
    |> Result.return
  | Var x ->
    [ Marked.Action { content = [ var (x, None) ]; bans = [] } ]
    |> Result.return
  | List [ Symbol s; h; t ] when equal_string s cons_op ->
    let* sh = star_of_expr h in
    let* ct = constellation_of_expr t in
    Ok (sh :: ct)
  | List g ->
    let* rg = ray_of_expr (List g) in
    [ Marked.Action { content = [ rg ]; bans = [] } ] |> Result.return

(* ---------------------------------------
   Stellogen expr of Expr
   --------------------------------------- *)

let rec sgen_expr_of_expr expr : (sgen_expr, expr_err) Result.t =
  match expr with
  | Symbol k when String.equal k nil_op ->
    Raw [ Action { content = []; bans = [] } ] |> Result.return
  | Var _ | Symbol _ ->
    let* ray = ray_of_expr expr in
    Raw [ Action { content = [ ray ]; bans = [] } ] |> Result.return
  | List (Symbol op :: _) when String.equal op params_op ->
    let* star = star_of_expr expr in
    Raw [ star ] |> Result.return
  | List (Symbol op :: _) when String.equal op cons_op ->
    let* star = star_of_expr expr in
    Raw [ star ] |> Result.return
  | List [ Symbol op; arg ] when String.equal op call_op ->
    let* ray = ray_of_expr arg in
    Call ray |> Result.return
  | List [ Symbol op; arg ] when String.equal op focus_op ->
    let* sgen_expr = sgen_expr_of_expr arg in
    Focus sgen_expr |> Result.return
  | List (Symbol op :: args) when String.equal op group_op ->
    let* sgen_exprs = List.map args ~f:sgen_expr_of_expr |> Result.all in
    Group sgen_exprs |> Result.return
  | List (Symbol "process" :: args) ->
    let* sgen_exprs = List.map args ~f:sgen_expr_of_expr |> Result.all in
    Process sgen_exprs |> Result.return
  | List (Symbol "interact" :: args) ->
    let* sgen_exprs = List.map args ~f:sgen_expr_of_expr |> Result.all in
    Exec (false, Group sgen_exprs) |> Result.return
  | List (Symbol "fire" :: args) ->
    let* sgen_exprs = List.map args ~f:sgen_expr_of_expr |> Result.all in
    Exec (true, Group sgen_exprs) |> Result.return
  | List [ Symbol "eval"; arg ] ->
    let* sgen_expr = sgen_expr_of_expr arg in
    Eval sgen_expr |> Result.return
  | List _ as list_expr ->
    let* constellation = constellation_of_expr list_expr in
    Raw constellation |> Result.return

(* ---------------------------------------
   Stellogen program of Expr
   --------------------------------------- *)

let decl_of_expr : expr -> (declaration, expr_err) Result.t = function
  | List [ Symbol op; identifier; value ] when String.equal op def_op ->
    let* id_ray = ray_of_expr identifier in
    let* value_expr = sgen_expr_of_expr value in
    Def (id_ray, value_expr) |> Result.return
  | List [ Symbol "show"; arg ] ->
    let* sgen_expr = sgen_expr_of_expr arg in
    Show sgen_expr |> Result.return
  | List [ Symbol op; expr1; expr2 ] when String.equal op expect_op ->
    let* sgen_expr1 = sgen_expr_of_expr expr1 in
    let* sgen_expr2 = sgen_expr_of_expr expr2 in
    Expect (sgen_expr1, sgen_expr2, const "default") |> Result.return
  | List [ Symbol op; expr1; expr2; message ] when String.equal op expect_op ->
    let* sgen_expr1 = sgen_expr_of_expr expr1 in
    let* sgen_expr2 = sgen_expr_of_expr expr2 in
    let* message_ray = ray_of_expr message in
    Expect (sgen_expr1, sgen_expr2, message_ray) |> Result.return
  | List [ Symbol "use"; path ] ->
    let* path_ray = ray_of_expr path in
    Use path_ray |> Result.return
  | invalid -> Error (InvalidDeclaration (to_string invalid))

let program_of_expr e = List.map ~f:decl_of_expr e |> Result.all

let preprocess e = e |> List.map ~f:expand_macro |> unfold_decl_def []
