open Base
open Stellogen.Sgen_ast
open Stellogen.Sgen_parser
open Stellogen.Sgen_lexer
open Lexing

let usage_msg = "sgen <filename>"

let input_file = ref ""

let anon_fun filename = input_file := filename

let speclist = []

let get_position lexbuf =
  let pos = lexbuf.lex_curr_p in
  Printf.sprintf "%s:%d:%d" pos.pos_fname
  pos.pos_lnum (pos.pos_cnum - pos.pos_bol + 1)

let parse_with_error lexbuf =
  try program read lexbuf with
  | SyntaxError msg ->
    let message = Printf.sprintf "%s: %s\n" (get_position lexbuf) msg in
    Out_channel.output_string Out_channel.stderr message;
    failwith "Error"

let () =
  Stdlib.Arg.parse speclist anon_fun usage_msg;
  let lexbuf = Lexing.from_channel (Stdlib.open_in !input_file) in
  let p = parse_with_error lexbuf in
  let _ = eval_program p in
  ()
