open Base
open Stellogen.Sgen_eval

let usage_msg = "sgen [--typecheck-only] <filename>"

let input_file = ref ""

let typecheckonly = ref false

let notyping = ref false

let anon_fun filename = input_file := filename

let speclist =
  [ ( "--typecheck-only"
    , Stdlib.Arg.Set typecheckonly
    , "Only perform typechecking." )
  ; ("--no-typing", Stdlib.Arg.Set notyping, "Perform execution without typing.")
  ]

let () =
  Stdlib.Arg.parse speclist anon_fun usage_msg;
  let lexbuf = Sedlexing.Utf8.from_channel (Stdlib.open_in !input_file) in
  let start_pos filename =
    { Lexing.pos_fname = filename; pos_lnum = 1; pos_bol = 0; pos_cnum = 0 }
  in
  Sedlexing.set_position lexbuf (start_pos !input_file);
  let lexer = Sedlexing.with_tokenizer Stellogen.Sgen_lexer.read lexbuf in
  let parser =
    MenhirLib.Convert.Simplified.traditional2revised
      Stellogen.Sgen_parser.program
  in
  let p = parser lexer in
  let _ = eval_program ~typecheckonly:!typecheckonly ~notyping:!notyping p in
  ()
