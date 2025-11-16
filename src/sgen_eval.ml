open Base
open Lsc_ast
open Lsc_pretty
open Lsc_eval
open Sgen_ast
open Out_channel

let ( let* ) x f = Result.bind x ~f

let unifiable r r' = StellarRays.solution [ (r, r') ] |> Option.is_some

(* Global trace config for CLI trace mode *)
let cli_trace_config : Lsc_eval.trace_config option ref = ref None

let constellations_matchable c1 c2 =
  (* Check if two constellations are matchable for Match (~=) *)
  (* Uses term unification (ignoring polarity, only checking function name equality) *)
  let open Lsc_ast in
  (* Extract all rays from both constellations *)
  let rays_from_constellation c =
    List.concat_map c ~f:(fun (star : Raw.star) -> star.content)
  in
  let rays1 = rays_from_constellation c1 in
  let rays2 = rays_from_constellation c2 in

  (* Check if any ray from c1 can unify with any ray from c2 (ignoring polarity) *)
  List.exists rays1 ~f:(fun r1 ->
    List.exists rays2 ~f:(fun r2 -> terms_unifiable r1 r2) )

let rec find_with_solution env x =
  let rec search_objs = function
    | [] -> None
    | (key, value) :: rest -> (
      let key_normalized = replace_indices 0 key in
      let value_normalized = map_ray env ~f:(replace_indices 0) value in
      let x_normalized = replace_indices 1 x in
      match StellarRays.solution [ (key_normalized, x_normalized) ] with
      | Some substitution ->
        (* Only use renamed value if there's actual parameter substitution *)
        let result_value =
          if List.is_empty substitution then value else value_normalized
        in
        Some (result_value, substitution)
      | None -> search_objs rest )
  in
  search_objs env.objs

and add_obj env key expr = List.Assoc.add ~equal:unifiable env.objs key expr

and get_obj env identifier = find_with_solution env identifier

and get_trace_config env =
  match
    List.Assoc.find ~equal:unifiable env.objs (Lsc_ast.const "__trace__")
  with
  | Some (Raw _) -> (
    (* Create trace config once and reuse it *)
    match !cli_trace_config with
    | Some cfg -> Some cfg
    | None ->
      let cfg = Lsc_eval.make_trace_config true in
      cli_trace_config := Some cfg;
      Some cfg )
  | _ -> None

and map_ray env ~f : sgen_expr -> sgen_expr = function
  | Raw g -> Raw (List.map ~f:(Marked.map ~f) g)
  | Call x -> Call (f x)
  | Exec (b, e, loc) ->
    let map_e = map_ray env ~f e in
    Exec (b, map_e, loc)
  | Group es ->
    let map_es = List.map ~f:(map_ray env ~f) es in
    Group map_es
  | Focus e ->
    let map_e = map_ray env ~f e in
    Focus map_e
  | Def (id, e) -> Def (f id, map_ray env ~f e)
  | Show (exprs, loc) -> Show (List.map ~f:(map_ray env ~f) exprs, loc)
  | Expect (e1, e2, msg, loc) ->
    Expect (map_ray env ~f e1, map_ray env ~f e2, f msg, loc)
  | Match (e1, e2, msg, loc) ->
    Match (map_ray env ~f e1, map_ray env ~f e2, f msg, loc)
  | Use id -> Use (f id)

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
  | MatchError { term1; term2; message = Func ((Null, f), []); location }
    when String.equal f "default" ->
    let header = bold (red "error") ^ ": " ^ bold "unification failed" in
    let loc_str =
      Option.map location ~f:format_location
      |> Option.value ~default:"<unknown location>"
    in
    let source =
      Option.map location ~f:show_source_location |> Option.value ~default:""
    in
    let term1_str = term1 |> Marked.remove_all |> string_of_constellation in
    let term2_str = term2 |> Marked.remove_all |> string_of_constellation in

    Printf.sprintf "%s\n  %s %s\n%s\n  %s %s\n  %s %s\n\n" header (cyan "-->")
      loc_str source (bold "Term 1:") (green term1_str) (bold "Term 2:")
      (yellow term2_str)
    |> Result.return
  | MatchError { message; location; _ } ->
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
        , "Declarations must use def, show, ==, or use." )
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
  sgen_expr -> (env * Marked.constellation, err) Result.t = function
  | Raw mcs -> Ok (env, mcs)
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
    let* env', eval_es =
      List.fold_left es
        ~init:(Ok (env, []))
        ~f:(fun acc e ->
          let* env_acc, results = acc in
          let* env_new, result = eval_sgen_expr env_acc e in
          Ok (env_new, result :: results) )
    in
    Ok (env', List.concat (List.rev eval_es))
  | Exec (b, e, loc) ->
    let* env', eval_e = eval_sgen_expr env e in
    let trace_cfg = get_trace_config env' in
    (* Set location in trace config if available *)
    ( match (trace_cfg, loc) with
    | Some cfg, Some location ->
      let lsc_loc =
        { Lsc_eval.filename = location.filename
        ; line = location.line
        ; column = location.column
        }
      in
      Lsc_eval.set_trace_location cfg (Some lsc_loc)
    | _ -> () );
    Ok (env', exec ~linear:b ~trace:trace_cfg eval_e |> Marked.make_action_all)
  | Focus e ->
    let* env', eval_e = eval_sgen_expr env e in
    eval_e |> Marked.remove_all |> Marked.make_state_all |> fun c -> Ok (env', c)
  | Def (identifier, expr) -> Ok ({ objs = add_obj env identifier expr }, [])
  | Show (exprs, show_loc) ->
    (* Evaluate all expressions and collect results *)
    let rec eval_all env_acc results = function
      | [] ->
        (* Print all results separated by spaces *)
        let output =
          List.rev results
          |> List.map ~f:(fun evaluated ->
            evaluated |> List.map ~f:Marked.remove |> string_of_constellation )
          |> String.concat ~sep:" "
        in
        Stdlib.print_endline output;
        Stdlib.flush Stdlib.stdout;
        Ok (env_acc, [])
      | expr :: rest ->
        (* Propagate location to inner expr if it doesn't have one *)
        let expr_with_loc =
          match expr with
          | Exec (b, e, None) -> Exec (b, e, show_loc)
          | other -> other
        in
        let* env', evaluated = eval_sgen_expr env_acc expr_with_loc in
        eval_all env' (evaluated :: results) rest
    in
    eval_all env [] exprs
  | Expect (expr1, expr2, message, location) ->
    let* env1, eval1 = eval_sgen_expr env expr1 in
    let* env2, eval2 = eval_sgen_expr env1 expr2 in
    let normalized1 = Marked.normalize_all eval1 in
    let normalized2 = Marked.normalize_all eval2 in
    if Marked.equal_constellation normalized1 normalized2 then Ok (env2, [])
    else Error (ExpectError { got = eval1; expected = eval2; message; location })
  | Match (expr1, expr2, message, location) ->
    let* env1, eval1 = eval_sgen_expr env expr1 in
    let* env2, eval2 = eval_sgen_expr env1 expr2 in
    let const1 = List.map eval1 ~f:Marked.remove in
    let const2 = List.map eval2 ~f:Marked.remove in
    if constellations_matchable const1 const2 then Ok (env2, [])
    else Error (MatchError { term1 = eval1; term2 = eval2; message; location })
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
    let preprocessed = Sgen_parsing.preprocess_with_imports filename expr in
    match Expr.program_of_expr preprocessed with
    | Ok program ->
      let* new_env = eval_program_internal env program in
      Ok (new_env, [])
    | Error (expr_err, loc) -> Error (ExprError (expr_err, loc)) )

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

and eval_program (p : program) =
  match eval_program_internal initial_env p with
  | Ok env -> Ok env
  | Error e ->
    let* pp = pp_err e in
    output_string stderr pp;
    Error e

and eval_program_internal (env : env) (p : program) =
  List.fold_left
    ~f:(fun acc x ->
      let* acc_env = acc in
      let* new_env, _ = eval_sgen_expr acc_env x in
      Ok new_env )
    ~init:(Ok env) p
