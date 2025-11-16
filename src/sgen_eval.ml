open Base
open Lsc_ast
open Lsc_pretty
open Lsc_eval
open Sgen_ast
open Out_channel

let ( let* ) x f = Result.bind x ~f

let unifiable r r' = StellarRays.solution [ (r, r') ] |> Option.is_some

(* Conversion between terms and constellations *)
let group_sym = (Null, "%group")

let cons_sym = (Null, "%cons")

let nil_sym = (Null, "%nil")

let focus_sym = (Null, "@")

let params_sym = (Null, "%params")

let nil_term = StellarRays.Func (nil_sym, [])

(* Convert a constellation to a term using %group *)
let term_of_constellation (c : Marked.constellation) : StellarRays.term =
  let open StellarRays in
  let rec star_to_term : Marked.star -> term = function
    | State s -> Func (focus_sym, [ star_content_to_term s ])
    | Action s -> star_content_to_term s
  and star_content_to_term (s : Raw.star) : term =
    let rays_term = rays_to_term s.content in
    if List.is_empty s.bans then rays_term
    else
      let bans_term = bans_to_term s.bans in
      Func (params_sym, [ rays_term; bans_term ])
  and rays_to_term (rays : ray list) : term =
    List.fold_right rays
      ~init:(Func (nil_sym, []))
      ~f:(fun r acc -> Func (cons_sym, [ r; acc ]))
  and bans_to_term (bans : ban list) : term =
    let ban_to_term = function
      | Ineq (r1, r2) -> Func ((Null, "!="), [ r1; r2 ])
      | Incomp (r1, r2) -> Func ((Null, "slice"), [ r1; r2 ])
    in
    List.fold_right bans
      ~init:(Func (nil_sym, []))
      ~f:(fun b acc -> Func (cons_sym, [ ban_to_term b; acc ]))
  in
  (* Don't wrap single stars in %group *)
  match c with
  | [ single ] -> star_to_term single
  | multiple -> Func (group_sym, List.map ~f:star_to_term multiple)

(* Convert a term to a constellation - interprets %group and %cons structures *)
let rec constellation_of_term (t : StellarRays.term) : Marked.constellation =
  let open StellarRays in
  match t with
  | Func ((Null, "%group"), stars) ->
    List.concat_map ~f:constellation_of_term stars
  | Func ((Null, "%cons"), [ star; rest ]) when is_star_term star ->
    (* %cons at constellation level: list of stars *)
    constellation_of_term star @ constellation_of_term rest
  | Func ((Null, "%nil"), []) -> []
  | Func ((Null, "@"), [ inner ]) ->
    constellation_of_term inner |> Marked.remove_all |> Marked.make_state_all
  | Func ((Null, "%params"), [ rays_term; bans_term ]) ->
    let rays = rays_of_term rays_term in
    let bans = bans_of_term bans_term in
    [ Action { content = rays; bans } ]
  | other ->
    (* Check if this looks like a %cons list of rays (star representation) *)
    if is_cons_list other then
      let rays = rays_of_term other in
      [ Action { content = rays; bans = [] } ]
    else
      (* Single ray treated as a single-ray action star *)
      [ Action { content = [ other ]; bans = [] } ]

(* Check if a term is a cons list (%cons _ _) or %nil *)
and is_cons_list = function
  | Func ((Null, "%cons"), _) -> true
  | Func ((Null, "%nil"), []) -> true
  | _ -> false

(* Check if a term looks like a star (either @ focused, %params, or cons list) *)
and is_star_term = function
  | Func ((Null, "@"), _) -> true
  | Func ((Null, "%params"), _) -> true
  | Func ((Null, "%cons"), _) -> true
  | Func ((Null, "%nil"), _) -> true
  | _ -> false

and rays_of_term (t : StellarRays.term) : ray list =
  let open StellarRays in
  match t with
  | Func ((Null, "%cons"), [ ray; rest ]) -> ray :: rays_of_term rest
  | Func ((Null, "%nil"), []) -> []
  | other -> [ other ]

and bans_of_term (t : StellarRays.term) : ban list =
  let open StellarRays in
  match t with
  | Func ((Null, "%cons"), [ ban; rest ]) ->
    ban_of_term ban :: bans_of_term rest
  | Func ((Null, "%nil"), []) -> []
  | _ -> []

and ban_of_term (t : StellarRays.term) : ban =
  let open StellarRays in
  match t with
  | Func ((Null, "!="), [ r1; r2 ]) -> Ineq (r1, r2)
  | Func ((Null, "slice"), [ r1; r2 ]) -> Incomp (r1, r2)
  | _ -> failwith "Invalid ban structure"

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

and map_term_ray ~(f : ray -> ray) (t : StellarRays.term) : StellarRays.term =
  let open StellarRays in
  let rec map_t = function
    | Var x -> f (Var x)
    | Func (pf, ts) ->
      let mapped_args = List.map ~f:map_t ts in
      f (Func (pf, mapped_args))
  in
  map_t t

and map_ray env ~f : sgen_expr -> sgen_expr = function
  | Raw t -> Raw (map_term_ray ~f t)
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
  sgen_expr -> (env * StellarRays.term, err) Result.t = function
  | Raw t -> Ok (env, t)
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
    (* Evaluate each expression and combine the resulting terms into a %group *)
    let* env', eval_terms =
      List.fold_left es
        ~init:(Ok (env, []))
        ~f:(fun acc e ->
          let* env_acc, results = acc in
          let* env_new, result = eval_sgen_expr env_acc e in
          Ok (env_new, result :: results) )
    in
    Ok (env', func "%group" (List.rev eval_terms))
  | Exec (b, e, loc) ->
    let* env', eval_e = eval_sgen_expr env e in
    let eval_constellation = constellation_of_term eval_e in
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
    let result_constellation =
      exec ~linear:b ~trace:trace_cfg eval_constellation
      |> Marked.make_action_all
    in
    Ok (env', term_of_constellation result_constellation)
  | Focus e ->
    let* env', eval_e = eval_sgen_expr env e in
    let focused_constellation =
      constellation_of_term eval_e |> Marked.remove_all |> Marked.make_state_all
    in
    Ok (env', term_of_constellation focused_constellation)
  | Def (identifier, expr) ->
    Ok ({ objs = add_obj env identifier expr }, nil_term)
  | Show (exprs, show_loc) ->
    (* Evaluate all expressions and collect results *)
    let rec eval_all env_acc results = function
      | [] ->
        (* Print all results separated by spaces *)
        let output =
          List.rev results
          |> List.map ~f:(fun evaluated ->
            constellation_of_term evaluated
            |> List.map ~f:Marked.remove |> string_of_constellation )
          |> String.concat ~sep:" "
        in
        Stdlib.print_endline output;
        Stdlib.flush Stdlib.stdout;
        Ok (env_acc, nil_term)
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
    let const1 = constellation_of_term eval1 in
    let const2 = constellation_of_term eval2 in
    let normalized1 = Marked.normalize_all const1 in
    let normalized2 = Marked.normalize_all const2 in
    if Marked.equal_constellation normalized1 normalized2 then
      Ok (env2, nil_term)
    else
      Error (ExpectError { got = const1; expected = const2; message; location })
  | Match (expr1, expr2, message, location) ->
    let* env1, eval1 = eval_sgen_expr env expr1 in
    let* env2, eval2 = eval_sgen_expr env1 expr2 in
    let const1 = constellation_of_term eval1 |> List.map ~f:Marked.remove in
    let const2 = constellation_of_term eval2 |> List.map ~f:Marked.remove in
    if constellations_matchable const1 const2 then Ok (env2, nil_term)
    else
      let const1_marked = constellation_of_term eval1 in
      let const2_marked = constellation_of_term eval2 in
      Error
        (MatchError
           { term1 = const1_marked; term2 = const2_marked; message; location }
        )
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
      Ok (new_env, nil_term)
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
