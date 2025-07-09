open Base
open Cmdliner
open Stellogen

let parse input_file =
  let lexbuf = Sedlexing.Utf8.from_channel (Stdlib.open_in input_file) in
  let start_pos filename =
    { Lexing.pos_fname = filename; pos_lnum = 1; pos_bol = 0; pos_cnum = 0 }
  in
  Sedlexing.set_position lexbuf (start_pos input_file);
  Sgen_parsing.parse_with_error input_file lexbuf

let run input_file =
  let expr = parse input_file in
  let preprocessed = Expr.preprocess expr in
  let p = Expr.program_of_expr preprocessed in
  let _ = Stellogen.Sgen_eval.eval_program p in
  ()

let preprocess_only input_file =
  let expr = parse input_file in
  let preprocessed = Expr.preprocess expr in
  Stdlib.print_string
    (List.map ~f:Expr.to_string preprocessed |> String.concat ~sep:"\n");
  Stdlib.print_newline ()

let input_file_arg =
  let doc = "Input file to process." in
  Arg.(required & pos 0 (some string) None & info [] ~docv:"FILENAME" ~doc)

let wrap f input_file =
  try Ok (f input_file) with e -> Error (`Msg (Stdlib.Printexc.to_string e))

let run_cmd =
  let term = Term.(const (wrap run) $ input_file_arg |> term_result) in
  Cmd.v (Cmd.info "run" ~doc:"Run the Stellogen program") term

let preprocess_cmd =
  let term =
    Term.(const (wrap preprocess_only) $ input_file_arg |> term_result)
  in
  Cmd.v (Cmd.info "preprocess" ~doc:"Show the preprocessed code") term

let default_cmd =
  let doc = "Stellogen: code generator and evaluator" in
  Cmd.group (Cmd.info "sgen" ~doc) [ run_cmd; preprocess_cmd ]

let () = Stdlib.exit (Cmd.eval default_cmd)
