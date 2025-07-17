open Base
open Cmdliner
open Stellogen

let run input_file =
  let lexbuf = Sedlexing.Utf8.from_channel (Stdlib.open_in input_file) in
  let start_pos filename =
    { Lexing.pos_fname = filename; pos_lnum = 1; pos_bol = 0; pos_cnum = 0 }
  in
  Sedlexing.set_position lexbuf (start_pos input_file);
  let lexer = Sedlexing.with_tokenizer Cosmog_lexer.read lexbuf in
  let parser =
    MenhirLib.Convert.Simplified.traditional2revised Cosmog_parser.expr_file
  in
  parser lexer |> Cosmog_compile.compile
  |> List.map ~f:Expr.Raw.to_string
  |> String.concat ~sep:"\n"
  |> fun s ->
  let oc = Stdlib.open_out "out.sg" in
  Stdlib.output_string oc s;
  Stdlib.close_out oc

let input_file_arg =
  let doc = "Input file to process." in
  Arg.(required & pos 0 (some string) None & info [] ~docv:"FILENAME" ~doc)

let wrap f input_file =
  try Ok (f input_file) with e -> Error (`Msg (Stdlib.Printexc.to_string e))

let compile_cmd =
  let term = Term.(const (wrap run) $ input_file_arg |> term_result) in
  Cmd.v (Cmd.info "compile" ~doc:"Compile a mini ML program") term

let default_cmd =
  let doc = "Cosmographer: compile mini-ML to Stellogen" in
  Cmd.group (Cmd.info "cosmog" ~doc) [ compile_cmd ]

let () = Stdlib.exit (Cmd.eval default_cmd)
