open Base
open Lsc_ast
open Sgen_ast
open Out_channel

let ( let* ) x f = Result.bind x ~f

let add_obj env x e = List.Assoc.add ~equal:equal_ray env.objs x e

let get_obj env x = List.Assoc.find ~equal:equal_ray env.objs x

let rec replace_id (xfrom : ident) (xto : sgen_expr) e :
  (sgen_expr, err) Result.t =
  match e with
  | Id x when equal_ray x xfrom -> Ok xto
  | Exec (b, e) ->
    let* g = replace_id xfrom xto e in
    Exec (b, g) |> Result.return
  | Kill e ->
    let* g = replace_id xfrom xto e in
    Kill g |> Result.return
  | Clean e ->
    let* g = replace_id xfrom xto e in
    Clean g |> Result.return
  | Union es ->
    let* gs = List.map ~f:(replace_id xfrom xto) es |> Result.all in
    Union gs |> Result.return
  | Focus e ->
    let* g = replace_id xfrom xto e in
    Focus g |> Result.return
  | Subst (e, subst) ->
    let* g = replace_id xfrom xto e in
    Subst (g, subst) |> Result.return
  | Process gs ->
    let* procs = List.map ~f:(replace_id xfrom xto) gs |> Result.all in
    Process procs |> Result.return
  | Eval e ->
    let* g = replace_id xfrom xto e in
    Eval g |> Result.return
  | Raw _ | Id _ -> e |> Result.return

let rec map_sgen_expr env ~f : sgen_expr -> (sgen_expr, err) Result.t = function
  | Raw g -> Raw (f g) |> Result.return
  | Id x -> begin
    match get_obj env x with
    | None -> Error (UnknownID (string_of_ray x))
    | Some g -> map_sgen_expr env ~f g
  end
  | Exec (b, e) ->
    let* map_e = map_sgen_expr env ~f e in
    Exec (b, map_e) |> Result.return
  | Kill e ->
    let* map_e = map_sgen_expr env ~f e in
    Kill map_e |> Result.return
  | Clean e ->
    let* map_e = map_sgen_expr env ~f e in
    Clean map_e |> Result.return
  | Union es ->
    let* map_es = List.map ~f:(map_sgen_expr env ~f) es |> Result.all in
    Union map_es |> Result.return
  | Subst (e, Extend pf) ->
    let* map_e = map_sgen_expr env ~f e in
    Subst (map_e, Extend pf) |> Result.return
  | Subst (e, Reduce pf) ->
    let* map_e = map_sgen_expr env ~f e in
    Subst (map_e, Reduce pf) |> Result.return
  | Focus e ->
    let* map_e = map_sgen_expr env ~f e in
    Focus map_e |> Result.return
  | Subst (e, SVar (x, r)) ->
    let* map_e = map_sgen_expr env ~f e in
    Subst (map_e, SVar (x, r)) |> Result.return
  | Subst (e, SFunc (pf, pf')) ->
    let* map_e = map_sgen_expr env ~f e in
    Subst (map_e, SFunc (pf, pf')) |> Result.return
  | Subst (e', SGal (x, e)) ->
    let* map_e = map_sgen_expr env ~f e in
    let* map_e' = map_sgen_expr env ~f e' in
    Subst (map_e', SGal (x, map_e)) |> Result.return
  | Process gs ->
    let* procs = List.map ~f:(map_sgen_expr env ~f) gs |> Result.all in
    Process procs |> Result.return
  | Eval e ->
    let* map_e = map_sgen_expr env ~f e in
    Eval map_e |> Result.return

let subst_vars env _from _to =
  map_sgen_expr env ~f:(subst_all_vars [ (_from, _to) ])

let subst_funcs env _from _to =
  map_sgen_expr env ~f:(subst_all_funcs [ (_from, _to) ])

let pp_err e : (string, err) Result.t =
  let red text = "\x1b[31m" ^ text ^ "\x1b[0m" in
  let open Lsc_ast.StellarRays in
  let open Printf in
  match e with
  | ExpectError (x, e, Func ((Null, f), [])) when equal_string f "default" ->
    sprintf "%s:\n* expected: %s\n* got: %s\n" (red "Expect Error")
      (x |> remove_mark_all |> string_of_constellation)
      (e |> remove_mark_all |> string_of_constellation)
    |> Result.return
  | ExpectError (_x, _e, Func ((Null, f), [ t ])) when equal_string f "error" ->
    sprintf "%s: %s\n" (red "Expect Error") (string_of_ray t) |> Result.return
  | ExpectError (_x, _e, message) ->
    sprintf "%s\n" (string_of_ray message) |> Result.return
  | UnknownID x ->
    sprintf "%s: identifier '%s' not found.\n" (red "UnknownID Error") x
    |> Result.return

let rec eval_sgen_expr (env : env) :
  sgen_expr -> (marked_constellation, err) Result.t = function
  | Raw mcs -> Ok mcs
  | Id x -> begin
    begin
      match get_obj env x with
      | None -> Error (UnknownID (string_of_ray x))
      | Some g -> eval_sgen_expr env g
    end
  end
  | Union es ->
    let* eval_es = List.map ~f:(eval_sgen_expr env) es |> Result.all in
    let* mcs = Ok eval_es in
    Ok (List.concat mcs)
  | Exec (b, e) ->
    let* eval_e = eval_sgen_expr env e in
    Ok (exec ~linear:b ~showtrace:false eval_e |> unmark_all)
  | Focus e ->
    let* eval_e = eval_sgen_expr env e in
    eval_e |> remove_mark_all |> focus |> Result.return
  | Kill e ->
    let* eval_e = eval_sgen_expr env e in
    eval_e |> remove_mark_all |> kill |> focus |> Result.return
  | Clean e ->
    let* eval_e = eval_sgen_expr env e in
    eval_e |> remove_mark_all |> clean |> focus |> Result.return
  | Process [] -> Ok []
  | Process (h :: t) ->
    let* eval_e = eval_sgen_expr env h in
    let init = eval_e |> remove_mark_all |> focus in
    let* res =
      List.fold_left t ~init:(Ok init) ~f:(fun acc x ->
        let* acc = acc in
        match x with
        | Id (Func ((Null, "kill"), [])) ->
          acc |> remove_mark_all |> kill |> focus |> Result.return
        | Id (Func ((Null, "clean"), [])) ->
          acc |> remove_mark_all |> clean |> focus |> Result.return
        | _ ->
          let origin = acc |> remove_mark_all |> focus in
          eval_sgen_expr env (Focus (Exec (false, Union [ x; Raw origin ]))) )
    in
    res |> Result.return
  | Subst (e, Extend pf) ->
    let* eval_e = eval_sgen_expr env e in
    List.map eval_e ~f:(map_mstar ~f:(fun r -> gfunc pf [ r ])) |> Result.return
  | Subst (e, Reduce pf) ->
    let* eval_e = eval_sgen_expr env e in
    List.map eval_e
      ~f:
        (map_mstar ~f:(fun r ->
           match r with
           | StellarRays.Func (pf', ts)
             when StellarSig.equal_idfunc pf pf' && List.length ts = 1 ->
             List.hd_exn ts
           | _ -> r ) )
    |> Result.return
  | Subst (e, SVar (x, r)) ->
    let* subst = subst_vars env (x, None) r e in
    eval_sgen_expr env subst
  | Subst (e, SFunc (pf1, pf2)) ->
    let* subst = subst_funcs env pf1 pf2 e in
    eval_sgen_expr env subst
  | Subst (e, SGal (x, _to)) ->
    let* fill = replace_id x _to e in
    eval_sgen_expr env fill
  | Eval e -> (
    let* eval_e = eval_sgen_expr env e in
    match eval_e with
    | [ Marked { content = [ r ]; bans = _ } ]
    | [ Unmarked { content = [ r ]; bans = _ } ] ->
      r |> expr_of_ray |> Expr.sgen_expr_of_expr |> eval_sgen_expr env
    | _ -> failwith "error: only rays can be evaluated." )

and expr_of_ray = function
  | Var (x, None) -> Expr.Var x
  | Var (x, Some i) -> Expr.Var (x ^ Int.to_string i)
  | Func (pf, []) -> Symbol (Lsc_ast.string_of_polsym pf)
  | Func ((Null, k), [ r ]) when equal_string k "#" -> Unquote (expr_of_ray r)
  | Func (pf, args) ->
    Expr.List
      (Symbol (Lsc_ast.string_of_polsym pf) :: List.map ~f:expr_of_ray args)

let rec eval_decl env : declaration -> (env, err) Result.t = function
  | Def (x, e) ->
    let env = { objs = add_obj env x e } in
    Ok env
  | Show (Id x) -> begin
    match get_obj env x with
    | None -> Error (UnknownID (string_of_ray x))
    | Some e -> eval_decl env (Show e)
  end
  | Show (Raw mcs) ->
    mcs |> remove_mark_all |> string_of_constellation |> Stdlib.print_string;
    Stdlib.print_newline ();
    Stdlib.flush Stdlib.stdout;
    Ok env
  | Show e ->
    let* eval_e = eval_sgen_expr env e in
    List.map eval_e ~f:remove_mark
    |> string_of_constellation |> Stdlib.print_string;
    Stdlib.print_newline ();
    Ok env
  | Trace e ->
    let* eval_e = eval_sgen_expr env e in
    let _ = exec ~showtrace:true eval_e in
    Ok env
  | Run e ->
    let _ = eval_sgen_expr env (Exec (false, e)) in
    Ok env
  | Expect (x, e, message) ->
    let* eval_x = eval_sgen_expr env (Id x) in
    let* eval_e = eval_sgen_expr env e in
    let normalize x = x |> remove_mark_all |> unmark_all in
    if not @@ equal_mconstellation (normalize eval_e) (normalize eval_x) then
      Error (ExpectError (eval_x, eval_e, message))
    else Ok env
  | Use path ->
    let open Lsc_ast.StellarRays in
    let formatted_filename : string =
      match path with
      | Func ((Null, f), [ s ]) when equal_string f "%string" -> string_of_ray s
      | path -> string_of_ray path ^ ".sg"
    in
    let lexbuf =
      Sedlexing.Utf8.from_channel (Stdlib.open_in formatted_filename)
    in
    let start_pos filename =
      { Lexing.pos_fname = filename; pos_lnum = 1; pos_bol = 0; pos_cnum = 0 }
    in
    Sedlexing.set_position lexbuf (start_pos formatted_filename);
    let expr = Sgen_parsing.parse_with_error lexbuf in
    let preprocessed = Expr.preprocess expr in
    let p = Expr.program_of_expr preprocessed in
    let* env = eval_program p in
    Ok env

and eval_program (p : program) =
  match
    List.fold_left
      ~f:(fun acc x ->
        let* acc = acc in
        eval_decl acc x )
      ~init:(Ok initial_env) p
  with
  | Ok env -> Ok env
  | Error e ->
    let* pp = pp_err e in
    output_string stderr pp;
    Error e
