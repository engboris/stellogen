open Base
open Lexing
open Lexer
open Parser

let red text = "\x1b[31m" ^ text ^ "\x1b[0m"

let string_of_token = function
  | VAR s | SYM s | STRING s -> s
  | AT -> "@"
  | BAR -> "|"
  | LPAR -> "("
  | RPAR -> ")"
  | LBRACK -> "["
  | RBRACK -> "]"
  | LBRACE -> "{"
  | RBRACE -> "}"
  | LANGLE -> "<"
  | RANGLE -> ">"
  | SHARP -> "#"
  | EOF -> "EOF"

let is_end_delimiter = function
  | RPAR | RANGLE | RBRACK | RBRACE -> true
  | _ -> false

let get_line filename line_num =
  let ic = Stdlib.open_in filename in
  let rec skip_lines n =
    if n <= 0 then ()
    else
      match Stdlib.input_line ic with
      | exception End_of_file -> ()
      | _ -> skip_lines (n - 1)
  in
  skip_lines (line_num - 1);
  let result = try Some (Stdlib.input_line ic) with End_of_file -> None in
  Stdlib.close_in ic;
  result

let unexpected_token_msg () =
  match !last_token with
  | Some tok when is_end_delimiter tok ->
    Printf.sprintf "No opening delimiter for '%s'." (string_of_token tok)
  | Some tok -> Printf.sprintf "Unexpected symbol '%s'." (string_of_token tok)
  | None -> "Unexpected end of input."

let string_of_line filename header lnum =
  match get_line filename lnum with
  | None -> ""
  | Some line -> Printf.sprintf "%s%s" header line

let string_of_position column_num = String.make column_num ' ' ^ red "^"

let print_syntax_error pos error_msg filename =
  let header = Printf.sprintf "%d| " pos.pos_lnum in
  let header_len = String.length header in
  let column = pos.pos_cnum - pos.pos_bol + 1 in
  Stdlib.Printf.eprintf "%s at line %d, column %d.\n%s\n%s\n%s%s\n"
    (red "Syntax error") pos.pos_lnum column error_msg
    (string_of_line filename header pos.pos_lnum)
    (String.make header_len ' ')
    (string_of_position (column - 1))

let handle_unclosed_delimiter c pos filename =
  let error_msg = Printf.sprintf "Unclosed delimiter '%c'." c in
  print_syntax_error pos error_msg filename;
  Stdlib.exit 1

let handle_unexpected_token start_pos filename =
  let error_msg = unexpected_token_msg () in
  print_syntax_error start_pos error_msg filename;
  Stdlib.exit 1

let handle_lexer_error msg pos filename =
  print_syntax_error pos msg filename;
  Stdlib.exit 1

let parse_with_error filename lexbuf =
  let lexer = Sedlexing.with_tokenizer read lexbuf in
  let parser = MenhirLib.Convert.Simplified.traditional2revised expr_file in
  try parser lexer with
  | Parser.Error -> (
    match !last_token with
    | Some EOF -> (
      match !delimiters_stack with
      | [] ->
        Stdlib.Printf.eprintf "%s: %s\n" (red "Syntax error")
          "unexpected end of file";
        Stdlib.exit 1
      | (delimiter_char, pos) :: _ ->
        handle_unclosed_delimiter delimiter_char pos filename )
    | _ ->
      let start_pos, _ = Sedlexing.lexing_positions lexbuf in
      handle_unexpected_token start_pos filename )
  | LexerError (msg, pos) -> handle_lexer_error msg pos filename
