open Lexing
open Sgen_lexer
open Sgen_parser

let print_position outx lexbuf =
  let pos = lexbuf.lex_curr_p in
  Stdlib.Printf.fprintf outx "%s:%d:%d" pos.pos_fname pos.pos_lnum
    (pos.pos_cnum - pos.pos_bol)

let parse_with_error lexbuf =
  try program read lexbuf
  with SyntaxError msg ->
    Stdlib.Printf.fprintf Stdlib.stderr "%a: %s\n" print_position lexbuf msg;
    raise (SyntaxError msg)
