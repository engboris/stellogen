open Base
open Cmdliner
open Stellogen

let parse_and_eval input_file =
  let lexbuf = Sedlexing.Utf8.from_channel (Stdlib.open_in input_file) in
  let start_pos filename =
    { Lexing.pos_fname = filename; pos_lnum = 1; pos_bol = 0; pos_cnum = 0 }
  in
  Sedlexing.set_position lexbuf (start_pos input_file);
  let expr = Sgen_parsing.parse_with_error lexbuf in
  let preprocessed = Expr.preprocess expr in
  Stdlib.print_string
    (List.map ~f:Expr.to_string preprocessed |> String.concat ~sep:"\n");
  Stdlib.print_newline ();
  Stdlib.print_string "----------------";
  Stdlib.flush Stdlib.stdout;
  let p = Expr.program_of_expr preprocessed in
  Stdlib.print_string "\n";
  let _ = Stellogen.Sgen_eval.eval_program p in
  ()

let input_file_arg =
  let doc = "Input file to process." in
  Arg.(required & pos 0 (some string) None & info [] ~docv:"FILENAME" ~doc)

let term =
  let open Term in
  const (fun input_file ->
    try Ok (parse_and_eval input_file)
    with e -> Error (`Msg (Stdlib.Printexc.to_string e)) )
  $ input_file_arg |> term_result

let cmd = Cmd.v (Cmd.info "sgen" ~doc:"Run the Stellogen program.") term

let () = Stdlib.exit (Cmd.eval cmd)
