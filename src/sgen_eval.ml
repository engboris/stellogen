open Base
open Lsc_ast
open Lsc_pretty
open Lsc_eval
open Sgen_ast
open Out_channel

let ( let* ) x f = Result.bind x ~f

let unifiable r r' = StellarRays.solution [ (r, r') ] |> Option.is_some

let rec find_with_solution env x =
  let rec search_objs = function
    | [] -> None
    | (key, value) :: rest -> (
      let key_normalized = replace_indices 0 key in
      let value_normalized = map_ray env ~f:(replace_indices 0) value in
      let x_normalized = replace_indices 1 x in
      match StellarRays.solution [ (key_normalized, x_normalized) ] with
      | Some substitution -> Some (value_normalized, substitution)
      | None -> search_objs rest )
  in
  search_objs env.objs

and add_obj env key expr = List.Assoc.add ~equal:unifiable env.objs key expr

and get_obj env identifier = find_with_solution env identifier

and map_ray env ~f : sgen_expr -> sgen_expr = function
  | Raw g -> Raw (List.map ~f:(Marked.map ~f) g)
  | Call x -> Call (f x)
  | Exec (b, e) ->
    let map_e = map_ray env ~f e in
    Exec (b, map_e)
  | Group es ->
    let map_es = List.map ~f:(map_ray env ~f) es in
    Group map_es
  | Focus e ->
    let map_e = map_ray env ~f e in
    Focus map_e
  | Process gs ->
    let procs = List.map ~f:(map_ray env ~f) gs in
    Process procs
  | Eval e ->
    let map_e = map_ray env ~f e in
    Eval map_e

let pp_err error : (string, err) Result.t =
  let red text = "\x1b[31m" ^ text ^ "\x1b[0m" in
  let open Lsc_ast.StellarRays in
  match error with
  | ExpectError (got, expected, Func ((Null, f), []))
    when String.equal f "default" ->
    Printf.sprintf "%s:\n* expected: %s\n* got: %s\n" (red "Expect Error")
      (expected |> Marked.remove_all |> string_of_constellation)
      (got |> Marked.remove_all |> string_of_constellation)
    |> Result.return
  | ExpectError (_, _, Func ((Null, f), [ term ])) when String.equal f "error"
    ->
    Printf.sprintf "%s: %s\n" (red "Expect Error") (string_of_ray term)
    |> Result.return
  | ExpectError (_, _, message) ->
    Printf.sprintf "%s\n" (string_of_ray message) |> Result.return
  | UnknownID identifier ->
    Printf.sprintf "%s: identifier '%s' not found.\n" (red "UnknownID Error")
      identifier
    |> Result.return
  | ExprError expr_error -> (
    let error_prefix = red "Expression Parsing Error" in
    match expr_error with
    | EmptyRay ->
      Printf.sprintf "%s: rays cannot be empty.\n" error_prefix |> Result.return
    | NonConstantRayHeader expr ->
      Printf.sprintf
        "%s: ray '%s' must start with a constant function symbol.\n"
        error_prefix expr
      |> Result.return
    | InvalidBan expr ->
      Printf.sprintf "%s: invalid ban expression '%s'.\n" error_prefix expr
      |> Result.return
    | InvalidRaylist expr ->
      Printf.sprintf "%s: expression '%s' is not a valid star.\n" error_prefix
        expr
      |> Result.return
    | InvalidDeclaration expr ->
      Printf.sprintf "%s: expression '%s' is not a valid declaration.\n"
        error_prefix expr
      |> Result.return )

let rec eval_sgen_expr (env : env) :
  sgen_expr -> (Marked.constellation, err) Result.t = function
  | Raw mcs -> Ok mcs
  | Call x -> begin
    match get_obj env x with
    | None -> Error (UnknownID (string_of_ray x))
    | Some (g, subst) ->
      let result =
        List.fold_result subst ~init:g ~f:(fun g_acc (xfrom, xto) ->
          map_ray env ~f:(StellarRays.subst [ (xfrom, xto) ]) g_acc
          |> Result.return )
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
      let er = expr_of_ray r in
      begin
        match Expr.sgen_expr_of_expr er with
        | Ok sg -> eval_sgen_expr env sg
        | Error e -> Error (ExprError e)
      end
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
  | Def (identifier, expr) -> Ok { objs = add_obj env identifier expr }
  | Show (Raw marked_constellation) ->
    marked_constellation |> Marked.remove_all |> string_of_constellation
    |> Stdlib.print_endline;
    Stdlib.flush Stdlib.stdout;
    Ok env
  | Show expr ->
    let* evaluated = eval_sgen_expr env expr in
    evaluated |> List.map ~f:Marked.remove |> string_of_constellation
    |> Stdlib.print_endline;
    Ok env
  | Run expr ->
    let (_ : (Marked.constellation, err) Result.t) =
      eval_sgen_expr env (Exec (false, expr))
    in
    Ok env
  | Expect (expr1, expr2, message) ->
    let* eval1 = eval_sgen_expr env expr1 in
    let* eval2 = eval_sgen_expr env expr2 in
    let normalized1 = Marked.normalize_all eval1 in
    let normalized2 = Marked.normalize_all eval2 in
    if Marked.equal_constellation normalized1 normalized2 then Ok env
    else Error (ExpectError (eval1, eval2, message))
  | Use path -> (
    let open Lsc_ast.StellarRays in
    let filename =
      match path with
      | Func ((Null, f), [ s ]) when String.equal f "%string" -> string_of_ray s
      | _ -> string_of_ray path ^ ".sg"
    in
    let create_start_pos fname =
      { Lexing.pos_fname = fname; pos_lnum = 1; pos_bol = 0; pos_cnum = 0 }
    in
    let lexbuf = Sedlexing.Utf8.from_channel (Stdlib.open_in filename) in
    Sedlexing.set_position lexbuf (create_start_pos filename);
    let expr = Sgen_parsing.parse_with_error filename lexbuf in
    let preprocessed = Expr.preprocess expr in
    match Expr.program_of_expr preprocessed with
    | Ok program ->
      let* new_env = eval_program program in
      Ok new_env
    | Error expr_err -> Error (ExprError expr_err) )

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
