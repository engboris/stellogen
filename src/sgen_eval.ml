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
  let bold text = "\x1b[1m" ^ text ^ "\x1b[0m" in
  let cyan text = "\x1b[36m" ^ text ^ "\x1b[0m" in
  let yellow text = "\x1b[33m" ^ text ^ "\x1b[0m" in
  let green text = "\x1b[32m" ^ text ^ "\x1b[0m" in

  let format_location loc =
    Printf.sprintf "%s:%d:%d" (cyan loc.filename) loc.line loc.column
  in

  let get_source_line filename line_num =
    try
      let ic = Stdlib.open_in filename in
      let rec skip_lines n =
        if n <= 1 then ()
        else (
          ignore (Stdlib.input_line ic);
          skip_lines (n - 1) )
      in
      skip_lines line_num;
      let line = Stdlib.input_line ic in
      Stdlib.close_in ic;
      Some line
    with _ -> None
  in

  let show_source_location loc =
    match get_source_line loc.filename loc.line with
    | Some line ->
      let line_num_str = Printf.sprintf "%4d" loc.line in
      let pointer = String.make (loc.column - 1) ' ' ^ red "^" in
      Printf.sprintf "\n %s %s %s\n      %s %s\n" (cyan line_num_str) (cyan "|")
        line (cyan "|") pointer
    | None -> ""
  in

  let open Lsc_ast.StellarRays in
  match error with
  | ExpectError { got; expected; message = Func ((Null, f), []); location }
    when String.equal f "default" ->
    let header = bold (red "error") ^ ": " ^ bold "assertion failed" in
    let loc_str =
      Option.map location ~f:format_location
      |> Option.value ~default:"<unknown location>"
    in
    let source =
      Option.map location ~f:show_source_location |> Option.value ~default:""
    in
    let expected_str =
      expected |> Marked.remove_all |> string_of_constellation
    in
    let got_str = got |> Marked.remove_all |> string_of_constellation in

    Printf.sprintf "%s\n  %s %s\n%s\n  %s %s\n  %s %s\n\n" header (cyan "-->")
      loc_str source (bold "Expected:") (green expected_str) (bold "     Got:")
      (yellow got_str)
    |> Result.return
  | ExpectError { message = Func ((Null, f), [ term ]); location; _ }
    when String.equal f "error" ->
    let header = bold (red "error") ^ ": " ^ string_of_ray term in
    let loc_str =
      Option.map location ~f:format_location
      |> Option.value ~default:"<unknown location>"
    in
    let source =
      Option.map location ~f:show_source_location |> Option.value ~default:""
    in
    Printf.sprintf "%s\n  %s %s\n%s\n" header (cyan "-->") loc_str source
    |> Result.return
  | ExpectError { message; location; _ } ->
    let header = bold (red "error") ^ ": " ^ string_of_ray message in
    let loc_str =
      Option.map location ~f:format_location
      |> Option.value ~default:"<unknown location>"
    in
    let source =
      Option.map location ~f:show_source_location |> Option.value ~default:""
    in
    Printf.sprintf "%s\n  %s %s\n%s\n" header (cyan "-->") loc_str source
    |> Result.return
  | UnknownID (identifier, location) ->
    let header = bold (red "error") ^ ": " ^ bold "identifier not found" in
    let loc_str =
      Option.map location ~f:format_location
      |> Option.value ~default:"<unknown location>"
    in
    let source =
      Option.map location ~f:show_source_location |> Option.value ~default:""
    in
    Printf.sprintf "%s\n  %s %s\n%s\n  The identifier %s was not defined.\n\n"
      header (cyan "-->") loc_str source
      (yellow ("'" ^ identifier ^ "'"))
    |> Result.return
  | ExprError (expr_error, location) ->
    let error_msg, hint =
      match expr_error with
      | EmptyRay ->
        ("rays cannot be empty", "Remove the empty ray or add content to it.")
      | NonConstantRayHeader expr ->
        ( Printf.sprintf "ray '%s' must start with a constant function symbol"
            expr
        , "Rays must begin with a function symbol, not a variable." )
      | InvalidBan expr ->
        ( Printf.sprintf "invalid ban expression '%s'" expr
        , "Ban expressions must use != or 'slice'." )
      | InvalidRaylist expr ->
        ( Printf.sprintf "expression '%s' is not a valid star" expr
        , "Check the syntax of your star expression." )
      | InvalidDeclaration expr ->
        ( Printf.sprintf "expression '%s' is not a valid declaration" expr
        , "Declarations must use :=, show, ==, or use." )
    in
    let header = bold (red "error") ^ ": " ^ bold error_msg in
    let loc_str =
      Option.map location ~f:format_location
      |> Option.value ~default:"<unknown location>"
    in
    let source =
      Option.map location ~f:show_source_location |> Option.value ~default:""
    in
    Printf.sprintf "%s\n  %s %s\n%s\n  %s %s\n\n" header (cyan "-->") loc_str
      source (cyan "help:") hint
    |> Result.return

let rec eval_sgen_expr (env : env) :
  sgen_expr -> (Marked.constellation, err) Result.t = function
  | Raw mcs -> Ok mcs
  | Call x -> begin
    match get_obj env x with
    | None -> Error (UnknownID (string_of_ray x, None))
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
        | Error e -> Error (ExprError (e, None))
      end
    | e ->
      failwith
        ( "eval error: "
        ^ string_of_constellation (Marked.remove_all e)
        ^ " is not a ray." ) )

and expr_of_ray : ray -> Expr.expr = function
  | Var (x, None) -> Expr.Var x
  | Var (x, Some i) -> Expr.Var (x ^ Int.to_string i)
  | Func (pf, []) -> Symbol (string_of_polsym pf)
  | Func (pf, args) ->
    Expr.List
      ( { Expr.content = Symbol (string_of_polsym pf); loc = None }
      :: List.map
           ~f:(fun r -> { Expr.content = expr_of_ray r; loc = None })
           args )

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
  | Expect (expr1, expr2, message, location) ->
    let* eval1 = eval_sgen_expr env expr1 in
    let* eval2 = eval_sgen_expr env expr2 in
    let normalized1 = Marked.normalize_all eval1 in
    let normalized2 = Marked.normalize_all eval2 in
    if Marked.equal_constellation normalized1 normalized2 then Ok env
    else Error (ExpectError { got = eval1; expected = eval2; message; location })
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
    | Error (expr_err, loc) -> Error (ExprError (expr_err, loc)) )

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
