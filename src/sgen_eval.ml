open Base
open Lsc_ast
open Lsc_pretty
open Lsc_eval
open Sgen_ast
open Out_channel

let ( let* ) x f = Result.bind x ~f

let unifiable r r' = StellarRays.solution [ (r, r') ] |> Option.is_some

let find_with_solution env x =
  let rec aux = function
    | [] -> None
    | (key, value) :: rest -> (
      match StellarRays.solution [ (key, x) ] with
      | Some subst -> Some (value, subst)
      | None -> aux rest )
  in
  aux env.objs

let add_obj env x e = List.Assoc.add ~equal:unifiable env.objs x e

let get_obj env x = find_with_solution env x

let rec map_sgen_expr env ~f : sgen_expr -> (sgen_expr, err) Result.t = function
  | Raw g -> Raw (f g) |> Result.return
  | Id x -> Id x |> Result.return
  | Exec (b, e) ->
    let* map_e = map_sgen_expr env ~f e in
    Exec (b, map_e) |> Result.return
  | Group es ->
    let* map_es = List.map ~f:(map_sgen_expr env ~f) es |> Result.all in
    Group map_es |> Result.return
  | Focus e ->
    let* map_e = map_sgen_expr env ~f e in
    Focus map_e |> Result.return
  | Process gs ->
    let* procs = List.map ~f:(map_sgen_expr env ~f) gs |> Result.all in
    Process procs |> Result.return
  | Eval e ->
    let* map_e = map_sgen_expr env ~f e in
    Eval map_e |> Result.return

let subst_vars env _from _to =
  map_sgen_expr env ~f:(subst_all_vars [ (_from, _to) ])

let pp_err e : (string, err) Result.t =
  let red text = "\x1b[31m" ^ text ^ "\x1b[0m" in
  let open Lsc_ast.StellarRays in
  let open Printf in
  match e with
  | ExpectError (x, e, Func ((Null, f), [])) when equal_string f "default" ->
    sprintf "%s:\n* expected: %s\n* got: %s\n" (red "Expect Error")
      (e |> Marked.remove_all |> string_of_constellation)
      (x |> Marked.remove_all |> string_of_constellation)
    |> Result.return
  | ExpectError (_x, _e, Func ((Null, f), [ t ])) when equal_string f "error" ->
    sprintf "%s: %s\n" (red "Expect Error") (string_of_ray t) |> Result.return
  | ExpectError (_x, _e, message) ->
    sprintf "%s\n" (string_of_ray message) |> Result.return
  | UnknownID x ->
    sprintf "%s: identifier '%s' not found.\n" (red "UnknownID Error") x
    |> Result.return

let rec eval_sgen_expr (env : env) :
  sgen_expr -> (Marked.constellation, err) Result.t = function
  | Raw mcs -> Ok mcs
  | Id x -> begin
    match get_obj env x with
    | None -> Error (UnknownID (string_of_ray x))
    | Some (g, subst) ->
      let result =
        List.fold_result subst ~init:g ~f:(fun g_acc (xfrom, xto) ->
          subst_vars env xfrom xto g_acc )
      in
      Result.bind result ~f:(eval_sgen_expr env)
  end
  | Group es ->
    let* eval_es = List.map ~f:(eval_sgen_expr env) es |> Result.all in
    let* mcs = Ok eval_es in
    Ok (List.concat mcs)
  | Exec (b, e) ->
    let* eval_e = eval_sgen_expr env e in
    Ok (exec ~linear:b eval_e |> Marked.make_action_all)
  | Focus e ->
    let* eval_e = eval_sgen_expr env e in
    eval_e |> Marked.remove_all |> Marked.make_state_all |> Result.return
  | Process [] -> Ok []
  | Process (h :: t) ->
    let* eval_e = eval_sgen_expr env h in
    let init = eval_e |> Marked.remove_all |> Marked.make_state_all in
    let* res =
      List.fold_left t ~init:(Ok init) ~f:(fun acc x ->
        let* acc = acc in
        let origin = acc |> Marked.remove_all |> Marked.make_state_all in
        eval_sgen_expr env (Focus (Exec (false, Group [ x; Raw origin ]))) )
    in
    res |> Result.return
  | Eval e -> (
    let* eval_e = eval_sgen_expr env e in
    match eval_e with
    | [ State { content = [ r ]; bans = _ } ]
    | [ Action { content = [ r ]; bans = _ } ] ->
      r |> expr_of_ray |> Expr.sgen_expr_of_expr |> eval_sgen_expr env
    | e ->
      failwith
        ( "eval error: "
        ^ string_of_constellation (Marked.remove_all e)
        ^ " is not a ray." ) )

and expr_of_ray = function
  | Var (x, None) -> Expr.Var x
  | Var (x, Some i) -> Expr.Var (x ^ Int.to_string i)
  | Func (pf, []) -> Symbol (string_of_polsym pf)
  | Func (pf, args) ->
    Expr.List (Symbol (string_of_polsym pf) :: List.map ~f:expr_of_ray args)

let rec eval_decl env : declaration -> (env, err) Result.t = function
  | Def (x, e) ->
    let env = { objs = add_obj env x e } in
    Ok env
  | Show (Raw mcs) ->
    mcs |> Marked.remove_all |> string_of_constellation |> Stdlib.print_string;
    Stdlib.print_newline ();
    Stdlib.flush Stdlib.stdout;
    Ok env
  | Show e ->
    let* eval_e = eval_sgen_expr env e in
    List.map eval_e ~f:Marked.remove
    |> string_of_constellation |> Stdlib.print_string;
    Stdlib.print_newline ();
    Ok env
  | Run e ->
    let _ = eval_sgen_expr env (Exec (false, e)) in
    Ok env
  | Expect (e1, e2, message) ->
    let* eval_e1 = eval_sgen_expr env e1 in
    let* eval_e2 = eval_sgen_expr env e2 in
    if
      not
      @@ Marked.equal_constellation
           (Marked.normalize_all eval_e1)
           (Marked.normalize_all eval_e2)
    then Error (ExpectError (eval_e1, eval_e2, message))
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
    let expr = Sgen_parsing.parse_with_error formatted_filename lexbuf in
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
