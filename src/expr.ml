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

let rec replace_id (xfrom : ident) xto e =
  match e with
  | Var x when equal_string x xfrom -> xto
  | Symbol _ | Var _ -> e
  | List es -> List (List.map ~f:(replace_id xfrom xto) es)

let unfold_decl_def (env : (string * (string list * expr list)) list) es :
  expr list =
  List.fold_left es ~init:(env, []) ~f:(fun (env, acc) -> function
    | List (Symbol "new-declaration" :: List (Symbol k :: args) :: content) ->
      let var_args =
        List.map args ~f:(function
          | Var x -> x
          | _ -> failwith "error: syntax declaration must contain variables" )
      in
      ((k, (var_args, content)) :: env, acc)
    | List (Symbol k :: args)
      when List.Assoc.find ~equal:equal_string env k |> Option.is_some ->
      let syntax_args, content =
        List.Assoc.find_exn ~equal:equal_string env k
      in
      if List.length syntax_args <> List.length args then
        failwith ("Error: not enough args given in macro call " ^ k)
      else
        let replace_ids e =
          List.fold_left (List.zip_exn syntax_args args) ~init:e
            ~f:(fun acc (xfrom, xto) -> replace_id xfrom xto acc )
        in
        (env, (List.map ~f:replace_ids content |> List.rev) @ acc)
    | e -> (env, e :: acc) )
  |> snd |> List.rev

(* ---------------------------------------
   Constellation of Expr
   --------------------------------------- *)

let symbol_of_str (s : string) : idfunc =
  let rest = String.subo s ~pos:1 in
  match String.get s 0 with
  | '+' -> (Pos, rest)
  | '-' -> (Neg, rest)
  | _ -> (Null, s)

let rec ray_of_expr : expr -> (ray, expr_err) Result.t = function
  | Symbol s -> to_func (symbol_of_str s, []) |> Result.return
  | Var "_" -> to_var ("_" ^ fresh_placeholder ()) |> Result.return
  | Var s -> to_var s |> Result.return
  | List [] -> Error EmptyRay
  | List (Symbol h :: t) ->
    let* args = List.map ~f:ray_of_expr t |> Result.all in
    to_func (symbol_of_str h, args) |> Result.return
  | List (_ :: _) as e -> Error (NonConstantRayHeader (to_string e))

let bans_of_expr es : (ban list, expr_err) Result.t =
  let ban_of_expr = function
    | List [ Symbol k; a; b ] when equal_string k ineq_op ->
      let* ra = ray_of_expr a in
      let* rb = ray_of_expr b in
      Ineq (ra, rb) |> Result.return
    | List [ Symbol k; a; b ] when equal_string k incomp_op ->
      let* ra = ray_of_expr a in
      let* rb = ray_of_expr b in
      Incomp (ra, rb) |> Result.return
    | _ as e -> Error (InvalidBan (to_string e))
  in
  List.map ~f:ban_of_expr es |> Result.all

let rec raylist_of_expr (e : expr) : (ray list, expr_err) Result.t =
  match e with
  | Symbol k when equal_string k nil_op -> Ok []
  | Symbol _ | Var _ ->
    let* r = ray_of_expr e in
    Ok [ r ]
  | List [ Symbol s; h; t ] when equal_string s cons_op ->
    let* rh = ray_of_expr h in
    let* rt = raylist_of_expr t in
    Ok (rh :: rt)
  | e -> Error (InvalidRaylist (to_string e))

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

let rec sgen_expr_of_expr (e : expr) : (sgen_expr, expr_err) Result.t =
  match e with
  | Symbol k when equal_string k nil_op ->
    Raw [ Action { content = []; bans = [] } ] |> Result.return
  (* ray *)
  | Var _ | Symbol _ ->
    let* re = ray_of_expr e in
    Raw [ Action { content = [ re ]; bans = [] } ] |> Result.return
  (* star *)
  | List (Symbol s :: _) when equal_string s params_op ->
    let* se = star_of_expr e in
    Raw [ se ] |> Result.return
  | List (Symbol s :: _) when equal_string s cons_op ->
    let* se = star_of_expr e in
    Raw [ se ] |> Result.return
  (* id *)
  | List [ Symbol k; g ] when equal_string k call_op ->
    let* re = ray_of_expr g in
    Call re |> Result.return
  (* focus @ *)
  | List [ Symbol k; g ] when equal_string k focus_op ->
    let* sgg = sgen_expr_of_expr g in
    Focus sgg |> Result.return
  (* group *)
  | List (Symbol k :: gs) when equal_string k group_op ->
    let* sggs = List.map ~f:sgen_expr_of_expr gs |> Result.all in
    Group sggs |> Result.return
  (* process *)
  | List (Symbol "process" :: gs) ->
    let* sggs = List.map ~f:sgen_expr_of_expr gs |> Result.all in
    Process sggs |> Result.return
  (* interact *)
  | List (Symbol "interact" :: gs) ->
    let* sggs = List.map ~f:sgen_expr_of_expr gs |> Result.all in
    Exec (false, Group sggs) |> Result.return
  (* fire *)
  | List (Symbol "fire" :: gs) ->
    let* sggs = List.map ~f:sgen_expr_of_expr gs |> Result.all in
    Exec (true, Group sggs) |> Result.return
  (* eval *)
  | List [ Symbol "eval"; g ] ->
    let* sgg = sgen_expr_of_expr g in
    Eval sgg |> Result.return
  (* KEEP LAST -- raw constellation *)
  | List e ->
    let* ce = constellation_of_expr (List e) in
    Raw ce |> Result.return

(* ---------------------------------------
   Stellogen program of Expr
   --------------------------------------- *)

let decl_of_expr : expr -> (declaration, expr_err) Result.t = function
  (* definition := *)
  | List [ Symbol k; x; g ] when equal_string k def_op ->
    let* rx = ray_of_expr x in
    let* sgg = sgen_expr_of_expr g in
    Def (rx, sgg) |> Result.return
  (* show *)
  | List [ Symbol "show"; g ] ->
    let* sgg = sgen_expr_of_expr g in
    Show sgg |> Result.return
  (* expect *)
  | List [ Symbol k; g1; g2 ] when equal_string k expect_op ->
    let* sgg1 = sgen_expr_of_expr g1 in
    let* sgg2 = sgen_expr_of_expr g2 in
    Expect (sgg1, sgg2, const "default") |> Result.return
  | List [ Symbol k; g1; g2; m ] when equal_string k expect_op ->
    let* sgg1 = sgen_expr_of_expr g1 in
    let* sgg2 = sgen_expr_of_expr g2 in
    let* rm = ray_of_expr m in
    Expect (sgg1, sgg2, rm) |> Result.return
  (* use *)
  | List [ Symbol k; r ] when equal_string k "use" ->
    let* rr = ray_of_expr r in
    Use rr |> Result.return
  | e -> Error (InvalidDeclaration (to_string e))

let program_of_expr e = List.map ~f:decl_of_expr e |> Result.all

let preprocess e = e |> List.map ~f:expand_macro |> unfold_decl_def []
