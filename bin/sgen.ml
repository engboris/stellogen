open Base
open Cmdliner
open Stellogen.Sgen_eval

let parse_and_eval input_file typecheckonly notyping =
  let lexbuf = Sedlexing.Utf8.from_channel (Stdlib.open_in input_file) in
  let start_pos filename =
    { Lexing.pos_fname = filename; pos_lnum = 1; pos_bol = 0; pos_cnum = 0 }
  in
  Sedlexing.set_position lexbuf (start_pos input_file);
  let p = Stellogen.Sgen_parsing.parse_with_error lexbuf in
  let _ = eval_program ~typecheckonly ~notyping p in
  ()

let input_file_arg =
  let doc = "Input file to process." in
  Arg.(required & pos 0 (some string) None & info [] ~docv:"FILENAME" ~doc)

let typecheckonly_flag =
  let doc = "Only perform typechecking." in
  Arg.(value & flag & info [ "typecheck-only" ] ~doc)

let notyping_flag =
  let doc = "Perform execution without typing." in
  Arg.(value & flag & info [ "no-typing" ] ~doc)

let term =
  let open Term in
  const (fun input_file typecheckonly notyping ->
    try Ok (parse_and_eval input_file typecheckonly notyping)
    with e -> Error (`Msg (Stdlib.Printexc.to_string e)) )
  $ input_file_arg $ typecheckonly_flag $ notyping_flag |> term_result

let cmd = Cmd.v (Cmd.info "sgen" ~doc:"Run the Stellogen program.") term

let () = Stdlib.exit (Cmd.eval cmd)
