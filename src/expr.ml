open Base
open Lsc_ast
open Sgen_ast
open Expr_err

let ( let* ) x f = Result.bind x ~f

type ident = string

(* Generic type for attaching source locations *)
type 'a loc =
  { content : 'a
  ; loc : source_location option
  }

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
    | Positioned of t * Lexing.position * Lexing.position
end

type expr =
  | Symbol of string
  | Var of ident
  | List of expr loc list

let rec equal_expr e1 e2 =
  match (e1, e2) with
  | Symbol s1, Symbol s2 -> String.equal s1 s2
  | Var v1, Var v2 -> String.equal v1 v2
  | List l1, List l2 ->
    List.equal (fun a b -> equal_expr a.content b.content) l1 l2
  | _ -> false

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
    Printf.sprintf "(%s)"
      (List.map ~f:(fun e -> to_string e.content) es |> String.concat ~sep:" ")

let rec expand_macro : Raw.t -> expr loc = function
  | Raw.Symbol s -> { content = Symbol s; loc = None }
  | Raw.Var x -> { content = Var x; loc = None }
  | Raw.String s ->
    { content =
        List
          [ { content = Symbol string_op; loc = None }
          ; { content = Symbol s; loc = None }
          ]
    ; loc = None
    }
  | Raw.Call e' ->
    let e = expand_macro e' in
    { content = List [ { content = Symbol call_op; loc = None }; e ]
    ; loc = None
    }
  | Raw.Focus e' ->
    let e = expand_macro e' in
    { content = List [ { content = Symbol focus_op; loc = None }; e ]
    ; loc = None
    }
  | Raw.Group es ->
    { content =
        List
          ( { content = Symbol group_op; loc = None }
          :: List.map ~f:expand_macro es )
    ; loc = None
    }
  | Raw.List es -> { content = List (List.map ~f:expand_macro es); loc = None }
  | Raw.Cons es -> expand_macro (Raw.ConsWithBase (es, Symbol nil_op))
  | Raw.ConsWithBase (es, base) ->
    List.fold_left es ~init:(expand_macro base) ~f:(fun acc e ->
      { content =
          List [ { content = Symbol cons_op; loc = None }; expand_macro e; acc ]
      ; loc = None
      } )
  | Raw.ConsWithParams (es, ps) ->
    { content =
        List
          [ { content = Symbol params_op; loc = None }
          ; expand_macro (Cons es)
          ; expand_macro (List ps)
          ]
    ; loc = None
    }
  | Raw.Stack [] -> { content = List []; loc = None }
  | Raw.Stack (h :: t) ->
    List.fold_left t ~init:(expand_macro h) ~f:(fun acc e ->
      { content = List [ expand_macro e; acc ]; loc = None } )
  | Raw.Positioned (e, start_pos, _) ->
    let source_loc =
      { filename = start_pos.Lexing.pos_fname
      ; line = start_pos.Lexing.pos_lnum
      ; column = start_pos.Lexing.pos_cnum - start_pos.Lexing.pos_bol + 1
      }
    in
    let expanded = expand_macro e in
    { expanded with loc = Some source_loc }

let rec replace_id (var_from : ident) replacement (expr : expr loc) : expr loc =
  match expr.content with
  | Var x when String.equal x var_from -> { replacement with loc = expr.loc }
  | Symbol _ | Var _ -> expr
  | List exprs ->
    { content = List (List.map exprs ~f:(replace_id var_from replacement))
    ; loc = expr.loc
    }

let unfold_decl_def (macro_env : (string * (string list * expr loc list)) list)
  exprs =
  let process_expr (env, acc) (expr : expr loc) =
    match expr.content with
    | List
        ( { content = Symbol "macro"; _ }
        :: { content = List ({ content = Symbol macro_name; _ } :: args); _ }
        :: body ) ->
      let var_args =
        List.map args ~f:(fun arg ->
          match arg.content with
          | Var x -> x
          | _ -> failwith "error: syntax declaration must contain variables" )
      in
      ((macro_name, (var_args, body)) :: env, acc)
    | List ({ content = Symbol macro_name; _ } :: call_args) -> (
      match List.Assoc.find env macro_name ~equal:String.equal with
      | Some (formal_params, body) ->
        if List.length formal_params <> List.length call_args then
          failwith
            (Printf.sprintf "Error: macro '%s' expects %d args, got %d"
               macro_name
               (List.length formal_params)
               (List.length call_args) )
        else
          let apply_substitution e =
            List.fold_left (List.zip_exn formal_params call_args) ~init:e
              ~f:(fun acc (param, arg) -> replace_id param arg acc )
          in
          let expanded = List.map body ~f:apply_substitution |> List.rev in
          (env, expanded @ acc)
      | None -> (env, expr :: acc) )
    | _ -> (env, expr :: acc)
  in
  List.fold_left exprs ~init:(macro_env, []) ~f:(fun (env, acc) e ->
    process_expr (env, acc) e )
  |> snd |> List.rev

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
  | List ({ content = Symbol h; _ } :: t) ->
    let* args = List.map ~f:(fun e -> ray_of_expr e.content) t |> Result.all in
    to_func (symbol_of_str h, args) |> Result.return
  | List (_ :: _) as e -> Error (NonConstantRayHeader (to_string e))

let bans_of_expr ban_exprs : (ban list, expr_err) Result.t =
  let ban_of_expr = function
    | List [ { content = Symbol op; _ }; expr1; expr2 ]
      when String.equal op ineq_op ->
      let* ray1 = ray_of_expr expr1.content in
      let* ray2 = ray_of_expr expr2.content in
      Ineq (ray1, ray2) |> Result.return
    | List [ { content = Symbol op; _ }; expr1; expr2 ]
      when String.equal op incomp_op ->
      let* ray1 = ray_of_expr expr1.content in
      let* ray2 = ray_of_expr expr2.content in
      Incomp (ray1, ray2) |> Result.return
    | invalid_expr -> Error (InvalidBan (to_string invalid_expr))
  in
  List.map ban_exprs ~f:(fun e -> ban_of_expr e.content) |> Result.all

let rec raylist_of_expr expr : (ray list, expr_err) Result.t =
  match expr with
  | Symbol k when String.equal k nil_op -> Ok []
  | Symbol _ | Var _ ->
    let* ray = ray_of_expr expr in
    Ok [ ray ]
  | List [ { content = Symbol op; _ }; head; tail ] when String.equal op cons_op
    ->
    let* head_ray = ray_of_expr head.content in
    let* tail_rays = raylist_of_expr tail.content in
    Ok (head_ray :: tail_rays)
  | invalid -> Error (InvalidRaylist (to_string invalid))

let rec star_of_expr : expr -> (Marked.star, expr_err) Result.t = function
  | List [ { content = Symbol k; _ }; s ] when equal_string k focus_op ->
    let* ss = star_of_expr s.content in
    ss |> Marked.remove |> Marked.make_state |> Result.return
  | List [ { content = Symbol k; _ }; s; { content = List ps; _ } ]
    when equal_string k params_op ->
    let* content = raylist_of_expr s.content in
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
  | List [ { content = Symbol s; _ }; h; t ] when equal_string s cons_op ->
    let* sh = star_of_expr h.content in
    let* ct = constellation_of_expr t.content in
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
  | List ({ content = Symbol op; _ } :: _) when String.equal op params_op ->
    let* star = star_of_expr expr in
    Raw [ star ] |> Result.return
  | List ({ content = Symbol op; _ } :: _) when String.equal op cons_op ->
    let* star = star_of_expr expr in
    Raw [ star ] |> Result.return
  | List [ { content = Symbol op; _ }; arg ] when String.equal op call_op ->
    let* ray = ray_of_expr arg.content in
    Call ray |> Result.return
  | List [ { content = Symbol op; _ }; arg ] when String.equal op focus_op ->
    let* sgen_expr = sgen_expr_of_expr arg.content in
    Focus sgen_expr |> Result.return
  | List ({ content = Symbol op; _ } :: args) when String.equal op group_op ->
    let* sgen_exprs =
      List.map args ~f:(fun e -> sgen_expr_of_expr e.content) |> Result.all
    in
    Group sgen_exprs |> Result.return
  | List ({ content = Symbol "process"; _ } :: args) ->
    let* sgen_exprs =
      List.map args ~f:(fun e -> sgen_expr_of_expr e.content) |> Result.all
    in
    Process sgen_exprs |> Result.return
  | List ({ content = Symbol "interact"; _ } :: args) ->
    let* sgen_exprs =
      List.map args ~f:(fun e -> sgen_expr_of_expr e.content) |> Result.all
    in
    Exec (false, Group sgen_exprs) |> Result.return
  | List ({ content = Symbol "fire"; _ } :: args) ->
    let* sgen_exprs =
      List.map args ~f:(fun e -> sgen_expr_of_expr e.content) |> Result.all
    in
    Exec (true, Group sgen_exprs) |> Result.return
  | List [ { content = Symbol "eval"; _ }; arg ] ->
    let* sgen_expr = sgen_expr_of_expr arg.content in
    Eval sgen_expr |> Result.return
  | List _ as list_expr ->
    let* constellation = constellation_of_expr list_expr in
    Raw constellation |> Result.return

(* ---------------------------------------
   Stellogen program of Expr
   --------------------------------------- *)

let decl_of_expr (expr : expr loc) : (declaration, expr_err) Result.t =
  match expr.content with
  | List [ { content = Symbol op; _ }; expr1; expr2 ]
    when String.equal op expect_op ->
    let* sgen_expr1 = sgen_expr_of_expr expr1.content in
    let* sgen_expr2 = sgen_expr_of_expr expr2.content in
    Expect (sgen_expr1, sgen_expr2, const "default", expr.loc) |> Result.return
  | List [ { content = Symbol op; _ }; expr1; expr2; message ]
    when String.equal op expect_op ->
    let* sgen_expr1 = sgen_expr_of_expr expr1.content in
    let* sgen_expr2 = sgen_expr_of_expr expr2.content in
    let* message_ray = ray_of_expr message.content in
    Expect (sgen_expr1, sgen_expr2, message_ray, expr.loc) |> Result.return
  | List [ { content = Symbol op; _ }; identifier; value ]
    when String.equal op def_op ->
    let* id_ray = ray_of_expr identifier.content in
    let* value_expr = sgen_expr_of_expr value.content in
    Def (id_ray, value_expr) |> Result.return
  | List [ { content = Symbol "show"; _ }; arg ] ->
    let* sgen_expr = sgen_expr_of_expr arg.content in
    Show sgen_expr |> Result.return
  | List [ { content = Symbol "use"; _ }; path ] ->
    let* path_ray = ray_of_expr path.content in
    Use path_ray |> Result.return
  | invalid -> Error (InvalidDeclaration (to_string invalid))

let program_of_expr e = List.map ~f:decl_of_expr e |> Result.all

let preprocess e = e |> List.map ~f:expand_macro |> unfold_decl_def []
