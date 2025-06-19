open Base
open Lsc_ast
open Lsc_err
open Sgen_ast
open Sgen_err
open Out_channel

let ( let* ) x f = Result.bind x ~f

let add_obj env x e = List.Assoc.add ~equal:equal_ray env.objs x e

let get_obj env x = List.Assoc.find ~equal:equal_ray env.objs x

let add_type env x e = List.Assoc.add ~equal:equal_ray env.types x e

let get_type env x = List.Assoc.find ~equal:equal_ray env.types x

let rec map_sgen_expr env ~f : sgen_expr -> (sgen_expr, err) Result.t =
  function
  | Raw g -> Raw (f g) |> Result.return
  | Id x when is_reserved x -> Ok (Id x)
  | Id x -> begin
    match get_obj env x with
    | None -> Error (UnknownID (string_of_ray x))
    | Some g -> map_sgen_expr env ~f g
  end
  | Exec e ->
    let* map_e = map_sgen_expr env ~f e in
    Exec map_e |> Result.return
  | Kill e ->
    let* map_e = map_sgen_expr env ~f e in
    Kill map_e |> Result.return
  | Clean e ->
    let* map_e = map_sgen_expr env ~f e in
    Clean map_e |> Result.return
  | LinExec e ->
    let* map_e = map_sgen_expr env ~f e in
    LinExec map_e |> Result.return
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

let rec replace_id env (_from : ident) (_to : sgen_expr) e :
  (sgen_expr, err) Result.t =
  match e with
  | Id x when is_reserved x -> Ok (Id x)
  | Id x when equal_ray x _from -> Ok _to
  | Exec e ->
    let* g = replace_id env _from _to e in
    Exec g |> Result.return
  | Kill e ->
    let* g = replace_id env _from _to e in
    Kill g |> Result.return
  | Clean e ->
    let* g = replace_id env _from _to e in
    Clean g |> Result.return
  | LinExec e ->
    let* g = replace_id env _from _to e in
    LinExec g |> Result.return
  | Union es ->
    let* gs = List.map ~f:(replace_id env _from _to) es |> Result.all in
    Union gs |> Result.return
  | Focus e ->
    let* g = replace_id env _from _to e in
    Focus g |> Result.return
  | Subst (e, subst) ->
    let* g = replace_id env _from _to e in
    Subst (g, subst) |> Result.return
  | Process gs ->
    let* procs = List.map ~f:(replace_id env _from _to) gs |> Result.all in
    Process procs |> Result.return
  | Eval e ->
    let* g = replace_id env _from _to e in
    Eval g |> Result.return
  | Raw _ | Id _ -> e |> Result.return

let subst_vars env _from _to =
  map_sgen_expr env ~f:(subst_all_vars [ (_from, _to) ])

let subst_funcs env _from _to =
  map_sgen_expr env ~f:(subst_all_funcs [ (_from, _to) ])

let rec pp_err e : (string, err) Result.t =
  match e with
  | IllFormedChecker -> "Ill-formed checker.\n" |> Result.return
  | ReservedWord x ->
    Printf.sprintf "%s: identifier '%s' is reserved.\n"
      (red "ReservedWord Error") x
    |> Result.return
  | UnknownID x ->
    Printf.sprintf "%s: identifier '%s' not found.\n" (red "UnknownID Error") x
    |> Result.return
  | TestFailed (x, t, id, got, exp) ->
    Printf.sprintf "%s: %s.\nChecking %s :: %s\n* got: %s\n* expected: %s\n"
      (red "TestFailed Error")
      ( if equal_string id "_" then "unique test of '" ^ t ^ "' failed"
        else "test '" ^ id ^ "' failed" )
      x t
      (got |> List.map ~f:remove_mark |> string_of_constellation)
      (exp |> List.map ~f:remove_mark |> string_of_constellation)
    |> Result.return
  | LscError e -> pp_err_effect e |> Result.return

and eval_sgen_expr ~notyping (env : env) :
  sgen_expr -> (marked_constellation, err) Result.t = function
  | Raw mcs -> Ok mcs
  | Id x -> begin
    begin
      match get_obj env x with
      | None -> Error (UnknownID (string_of_ray x))
      | Some g -> eval_sgen_expr ~notyping env g
    end
  end
  | Union es ->
    let* eval_es = List.map ~f:(eval_sgen_expr ~notyping env) es |> Result.all in
    let* mcs = Ok eval_es in
    Ok (List.concat mcs)
  | Exec e ->
    let* eval_e = eval_sgen_expr ~notyping env e in
    begin
      match exec ~linear:false ~showtrace:false eval_e with
      | Ok res -> Ok (unmark_all res)
      | Error e -> Error (LscError e)
    end
  | LinExec e ->
    let* eval_e = eval_sgen_expr ~notyping env e in
    begin
      match exec ~linear:true ~showtrace:false eval_e with
      | Ok mcs -> Ok (unmark_all mcs)
      | Error e -> Error (LscError e)
    end
  | Focus e ->
    let* eval_e = eval_sgen_expr ~notyping env e in
    (eval_e |> remove_mark_all |> focus) |> Result.return
  | Kill e ->
    let* eval_e = eval_sgen_expr ~notyping env e in
    (eval_e |> remove_mark_all |> kill |> focus) |> Result.return
  | Clean e ->
    let* eval_e = eval_sgen_expr ~notyping env e in
    (eval_e |> remove_mark_all |> clean |> focus) |> Result.return
  | Process [] -> Ok []
  | Process (h :: t) ->
    let* eval_e = eval_sgen_expr ~notyping env h in
    let init = eval_e |> remove_mark_all |> focus in
    let* res =
      List.fold_left t ~init:(Ok init) ~f:(fun acc x ->
        let* acc = acc in
        match x with
        | Id (Func ((Muted, (Null, "kill")), [])) ->
          acc |> remove_mark_all |> kill |> focus |> Result.return
        | Id (Func ((Muted, (Null, "clean")), [])) ->
          acc |> remove_mark_all |> clean |> focus |> Result.return
        | _ ->
          let origin = acc |> remove_mark_all |> focus in
            eval_sgen_expr ~notyping env
              (Focus (Exec (Union [ x; Raw origin ])))
          )
    in
    res |> Result.return
  | Subst (e, Extend pf) ->
    let* eval_e = eval_sgen_expr ~notyping env e in
    (List.map eval_e ~f:(map_mstar ~f:(fun r -> gfunc pf [ r ])))
    |> Result.return
  | Subst (e, Reduce pf) ->
    let* eval_e = eval_sgen_expr ~notyping env e in
      (List.map eval_e
         ~f:
           (map_mstar ~f:(fun r ->
              match r with
              | StellarRays.Func (pf', ts)
                when StellarSig.equal_idfunc (snd pf) (snd pf')
                     && List.length ts = 1 ->
                List.hd_exn ts
              | _ -> r ) ) )
    |> Result.return
  | Subst (e, SVar (x, r)) ->
    let* subst = subst_vars env (x, None) r e in
    eval_sgen_expr ~notyping env subst
  | Subst (e, SFunc (pf1, pf2)) ->
    let* subst = subst_funcs env pf1 pf2 e in
    eval_sgen_expr ~notyping env subst
  | Subst (e, SGal (x, _to)) ->
    let* fill = replace_id env x _to e in
    eval_sgen_expr ~notyping env fill
  | Eval e -> (
    let* eval_e = eval_sgen_expr ~notyping env e in
    match eval_e with
    | [ Marked { content = [ r ]; bans = _ } ]
    | [ Unmarked { content = [ r ]; bans = _ } ] ->
      r |> expr_of_ray |> Expr.sgen_expr_of_expr
      |> eval_sgen_expr ~notyping env
    | _ -> failwith "error: only rays can be evaluated." )

and expr_of_ray = function
  | Var (x, None) -> Expr.Var x
  | Var (x, Some i) -> Expr.Var (x ^ Int.to_string i)
  | Func (pf, []) -> Symbol (Lsc_ast.string_of_polsym pf)
  | Func ((Muted, (Null, k)), [ r ]) when equal_string k "#" ->
    Unquote (expr_of_ray r)
  | Func (pf, args) ->
    Expr.List
      (Symbol (Lsc_ast.string_of_polsym pf) :: List.map ~f:expr_of_ray args)

and string_of_type_expr (t, ck) =
  match ck with
  | None -> Printf.sprintf "%s" (string_of_ray t)
  | Some xck -> Printf.sprintf "%s [%s]" (string_of_ray t) (string_of_ray xck)

let rec eval_decl ~typecheckonly ~notyping env :
  declaration -> (env, err) Result.t = function
  | Def (x, _) when is_reserved x -> Error (ReservedWord (string_of_ray x))
  | Def (x, e) ->
    let env = { objs = add_obj env x e; types = env.types } in
    Ok env
  | Show _ when typecheckonly -> Ok env
  | Show (Id x) -> begin
    match get_obj env x with
    | None -> Error (UnknownID (string_of_ray x))
    | Some e -> eval_decl ~typecheckonly ~notyping env (Show e)
  end
  | Show (Raw mcs) ->
    mcs |> remove_mark_all
    |> string_of_constellation |> Stdlib.print_string;
    Stdlib.print_newline ();
    Stdlib.flush Stdlib.stdout;
    Ok env
  | Show e ->
    let* eval_e = eval_sgen_expr ~notyping env e in
    List.map eval_e ~f:remove_mark
    |> string_of_constellation |> Stdlib.print_string;
    Stdlib.print_newline ();
    Ok env
  | Trace _ when typecheckonly -> Ok env
  | Trace e ->
    let* eval_e = eval_sgen_expr ~notyping env e in
    begin
      match exec ~showtrace:true eval_e with
      | Ok _ -> Ok env
      | Error e -> Error (LscError e)
    end
  | Run _ when typecheckonly -> Ok env
  | Run e ->
    let _ = eval_sgen_expr ~notyping env (Exec e) in
    Ok env
  | Typedecl _ when notyping -> Ok env
  | Typedecl (x, ts) -> Ok { objs = env.objs; types = add_type env x ts }
  | Expect (_x, _mcs) -> Ok { objs = []; types = [] }
    (* TODO *)
  | Use path ->
    let path = List.map path ~f:string_of_ray in
    let formatted_filename = String.concat ~sep:"/" path ^ ".sg" in
    let lexbuf =
      Sedlexing.Utf8.from_channel (Stdlib.open_in formatted_filename)
    in
    let start_pos filename =
      { Lexing.pos_fname = filename; pos_lnum = 1; pos_bol = 0; pos_cnum = 0 }
    in
    Sedlexing.set_position lexbuf (start_pos formatted_filename);
    let expr = Sgen_parsing.parse_with_error lexbuf in
    let expanded = List.map ~f:Expr.expand_macro expr in
    let p = Expr.program_of_expr expanded in
    let* env = eval_program ~typecheckonly ~notyping p in
    Ok env

and eval_program ~typecheckonly ~notyping (p : program) =
  match
    List.fold_left
      ~f:(fun acc x ->
        let* acc = acc in
        eval_decl ~typecheckonly ~notyping acc x )
      ~init:(Ok initial_env) p
  with
  | Ok env -> Ok env
  | Error e ->
    let* pp = pp_err e in
    output_string stderr pp;
    Error e
