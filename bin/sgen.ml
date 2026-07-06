open Base
open Cmdliner
open Stellogen

let create_start_pos filename =
  { Lexing.pos_fname = filename; pos_lnum = 1; pos_bol = 0; pos_cnum = 0 }

let parse input_file =
  let lexbuf = Sedlexing.Utf8.from_channel (Stdlib.open_in input_file) in
  Sedlexing.set_position lexbuf (create_start_pos input_file);
  Stellogen_parsing.parse_with_error input_file lexbuf

let run input_file =
  let expr = parse input_file in
  let preprocessed =
    Stellogen_parsing.preprocess_with_imports input_file expr
  in
  match Expression.program_of_expr preprocessed with
  | Ok program ->
    let (_ : (Syntax.env, Syntax.err) Result.t) =
      Evaluator.eval_program program
    in
    ()
  | Error (expr_error, loc) -> (
    match Evaluator.pp_err (ExprError (expr_error, loc)) with
    | Ok error_msg -> Stdlib.Printf.eprintf "%s" error_msg
    | Error _ -> () )

let trace input_file =
  let expr = parse input_file in
  let preprocessed =
    Stellogen_parsing.preprocess_with_imports input_file expr
  in
  match Expression.program_of_expr preprocessed with
  | Ok program ->
    (* Enable trace mode by setting __trace__ in the environment *)
    let trace_marker = Syntax.Raw (Constellation.func "%nil" []) in
    let initial_env =
      { Syntax.objs =
          (Constellation.const "__trace__", trace_marker)
          :: Syntax.initial_env.objs
      }
    in
    let (_ : (Syntax.env, Syntax.err) Result.t) =
      match Evaluator.eval_program_internal initial_env program with
      | Ok env -> Ok env
      | Error e ->
        let open Base.Result in
        Evaluator.pp_err e >>= fun pp ->
        Stdlib.output_string Stdlib.stderr pp;
        Error e
    in
    ()
  | Error (expr_error, loc) -> (
    match Evaluator.pp_err (ExprError (expr_error, loc)) with
    | Ok error_msg -> Stdlib.Printf.eprintf "%s" error_msg
    | Error _ -> () )

let preprocess_only input_file =
  let expr = parse input_file in
  let preprocessed =
    Stellogen_parsing.preprocess_with_imports input_file expr
  in
  preprocessed
  |> List.map ~f:(fun e -> Expression.to_string e.Expression.content)
  |> String.concat ~sep:"\n" |> Stdlib.print_endline

let input_file_arg =
  let doc = "Input file to process." in
  Arg.(required & pos 0 (some string) None & info [] ~docv:"FILENAME" ~doc)

let wrap f input_file =
  try Ok (f input_file) with e -> Error (`Msg (Exn.to_string e))

let run_cmd =
  let doc = "Run the Stellogen program" in
  let term = Term.(const (wrap run) $ input_file_arg |> term_result) in
  Cmd.v (Cmd.info "run" ~doc) term

let trace_cmd =
  let doc = "Run the Stellogen program with interactive execution trace" in
  let term = Term.(const (wrap trace) $ input_file_arg |> term_result) in
  Cmd.v (Cmd.info "trace" ~doc) term

let preprocess_cmd =
  let doc = "Show the preprocessed code" in
  let term =
    Term.(const (wrap preprocess_only) $ input_file_arg |> term_result)
  in
  Cmd.v (Cmd.info "preprocess" ~doc) term

let default_cmd =
  let doc = "Stellogen: code generator and evaluator" in
  Cmd.group (Cmd.info "sgen" ~doc) [ run_cmd; trace_cmd; preprocess_cmd ]

let () = Stdlib.exit (Cmd.eval default_cmd)
