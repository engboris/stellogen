open Lexing
open Sgen_lexer
open Sgen_parser

let print_position fmt (pos : Lexing.position) =
  Format.fprintf fmt "%s:%d:%d" pos.pos_fname pos.pos_lnum
    (pos.pos_cnum - pos.pos_bol + 1)

let parse_with_error lexbuf =
  let lexer = Sedlexing.with_tokenizer read lexbuf in
  let parser = MenhirLib.Convert.Simplified.traditional2revised program in
  try parser lexer
  with SyntaxError msg ->
    let _start_pos, end_pos = Sedlexing.lexing_positions lexbuf in
    Format.fprintf Format.err_formatter "%a: %s\n" print_position end_pos msg;
    raise (SyntaxError msg)
