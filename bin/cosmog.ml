(** Cosmographer: Compiler from linear lambda calculus to Stellogen *)

open Base
open Cmdliner
open Stellogen

(** Create initial lexer position for a file *)
let create_start_pos filename =
  { Lexing.pos_fname = filename
  ; pos_lnum = 1
  ; pos_bol = 0
  ; pos_cnum = 0
  }

(** Compile a mini-ML file to Stellogen

    @param input_file Path to the input .ml file
    @param output_file Path to the output .sg file *)
let compile_file input_file output_file =
  (* Open input file with proper resource management *)
  let ic =
    try Stdlib.open_in input_file
    with Sys_error msg ->
      failwith (Printf.sprintf "Failed to open input file '%s': %s" input_file msg)
  in

  (* Parse and compile, ensuring input file is closed *)
  let output_code =
    Stdlib.Fun.protect
      ~finally:(fun () -> Stdlib.close_in ic)
      (fun () ->
        (* Set up lexer *)
        let lexbuf = Sedlexing.Utf8.from_channel ic in
        Sedlexing.set_position lexbuf (create_start_pos input_file);
        let lexer = Sedlexing.with_tokenizer Cosmog_lexer.read lexbuf in

        (* Parse the input *)
        let parser =
          MenhirLib.Convert.Simplified.traditional2revised Cosmog_parser.expr_file
        in
        let ast = parser lexer in

        (* Compile to Stellogen *)
        let compiled = Cosmog_compile.compile ast in
        List.map ~f:Expr.Raw.to_string compiled
        |> String.concat ~sep:"\n"
      )
  in

  (* Write output file with proper resource management *)
  let oc =
    try Stdlib.open_out output_file
    with Sys_error msg ->
      failwith (Printf.sprintf "Failed to open output file '%s': %s" output_file msg)
  in

  Stdlib.Fun.protect
    ~finally:(fun () -> Stdlib.close_out oc)
    (fun () ->
      Stdlib.output_string oc output_code;
      Stdlib.output_char oc '\n'
    )

(** {1 Command-line interface} *)

let input_file_arg =
  let doc = "Input mini-ML file to compile." in
  Arg.(required & pos 0 (some file) None & info [] ~docv:"INPUT" ~doc)

let output_file_arg =
  let doc = "Output Stellogen file (default: out.sg)." in
  Arg.(value & opt string "out.sg" & info [ "o"; "output" ] ~docv:"OUTPUT" ~doc)

(** Wrap compilation with error handling *)
let wrap_compile input_file output_file =
  try
    compile_file input_file output_file;
    Ok ()
  with
  | Failure msg -> Error (`Msg msg)
  | e -> Error (`Msg (Printf.sprintf "Unexpected error: %s" (Stdlib.Printexc.to_string e)))

let compile_cmd =
  let doc = "Compile a linear mini-ML program to Stellogen interaction nets." in
  let man = [
    `S Manpage.s_description;
    `P "Cosmographer compiles linear lambda calculus programs written in a \
        mini-ML syntax to Stellogen's interaction net representation.";
    `P "The input program must satisfy the linearity constraint: each \
        variable must be used exactly once.";
    `S Manpage.s_examples;
    `P "Compile input.ml to out.sg:";
    `Pre "  cosmog compile input.ml";
    `P "Compile input.ml to custom output:";
    `Pre "  cosmog compile input.ml -o output.sg";
  ] in
  let term = Term.(const wrap_compile $ input_file_arg $ output_file_arg |> term_result) in
  Cmd.v (Cmd.info "compile" ~doc ~man) term

let default_cmd =
  let doc = "Cosmographer: compile linear mini-ML to Stellogen" in
  let man = [
    `S Manpage.s_description;
    `P "Cosmographer is a compiler from linear lambda calculus to Stellogen.";
    `S Manpage.s_bugs;
    `P "Report bugs at https://github.com/engboris/stellogen/issues";
  ] in
  Cmd.group (Cmd.info "cosmog" ~version:"1.0" ~doc ~man) [ compile_cmd ]

let () = Stdlib.exit (Cmd.eval default_cmd)
