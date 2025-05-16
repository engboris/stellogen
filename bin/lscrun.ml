open Base
open Cmdliner
open Lsc.Lsc_ast
open Lsc.Lsc_err
open Out_channel

let parse_and_eval input_file unfincomp linear showtrace =
  let lexbuf = Sedlexing.Utf8.from_channel (Stdlib.open_in input_file) in
  let start_pos filename =
    { Lexing.pos_fname = filename; pos_lnum = 1; pos_bol = 0; pos_cnum = 0 }
  in
  Sedlexing.set_position lexbuf (start_pos input_file);
  let lexer = Sedlexing.with_tokenizer Lsc.Lsc_lexer.read lexbuf in
  let parser =
    MenhirLib.Convert.Simplified.traditional2revised
      Lsc.Lsc_parser.constellation_file
  in
  let mcs = parser lexer in
  let result =
    match exec ~linear ~showtrace mcs with
    | Ok result -> result
    | Error e ->
      pp_err_effect e |> Out_channel.output_string Out_channel.stderr;
      Stdlib.exit 1
  in
  if not showtrace then
    result
    |> (if unfincomp then kill else Fn.id)
    |> string_of_constellation |> Stdlib.print_endline
  else output_string stdout "No interaction left.\n"

let input_file_arg =
  let doc = "Input file to process." in
  Arg.(required & pos 0 (some string) None & info [] ~docv:"FILENAME" ~doc)

let unfincomp_flag =
  let doc =
    "Show stars containing polarities which are left after execution\n\n\
    \    (they correspond to unfinished computation and are omitted by \
     default)."
  in
  Arg.(value & flag & info [ "unfincomp" ] ~doc)

let showtrace_flag =
  let doc = "Interactively show steps of selection and unification." in
  Arg.(value & flag & info [ "showtrace" ] ~doc)

let linear_flag =
  let doc = "Actions which are used are consummed." in
  Arg.(value & flag & info [ "linear" ] ~doc)

let term =
  let open Term in
  const (fun input_file unfincomp showtrace linear ->
    try Ok (parse_and_eval input_file unfincomp showtrace linear)
    with e -> Error (`Msg (Stdlib.Printexc.to_string e)) )
  $ input_file_arg $ unfincomp_flag $ showtrace_flag $ linear_flag
  |> term_result

let cmd = Cmd.v (Cmd.info "sgen" ~doc:"Run the Stellogen program.") term

let () = Stdlib.exit (Cmd.eval cmd)
