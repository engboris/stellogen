open Base
open Lexing
open Lexer
open Parser

let red text = "\x1b[31m" ^ text ^ "\x1b[0m"
let bold text = "\x1b[1m" ^ text ^ "\x1b[0m"
let cyan text = "\x1b[36m" ^ text ^ "\x1b[0m"
let yellow text = "\x1b[33m" ^ text ^ "\x1b[0m"

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
    Printf.sprintf "no opening delimiter for '%s'" (string_of_token tok)
  | Some tok -> Printf.sprintf "unexpected symbol '%s'" (string_of_token tok)
  | None -> "unexpected end of input"

let format_location filename pos =
  let column = pos.pos_cnum - pos.pos_bol + 1 in
  Printf.sprintf "%s:%d:%d" (cyan filename) pos.pos_lnum column

let show_source_location filename pos =
  match get_line filename pos.pos_lnum with
  | Some line ->
    let line_num_str = Printf.sprintf "%4d" pos.pos_lnum in
    let column = pos.pos_cnum - pos.pos_bol + 1 in
    let pointer = String.make (column - 1) ' ' ^ red "^" in
    Printf.sprintf "\n %s %s %s\n      %s %s\n"
      (cyan line_num_str)
      (cyan "|")
      line
      (cyan "|")
      pointer
  | None -> ""

let print_syntax_error pos error_msg filename =
  let header = bold (red "error") ^ ": " ^ bold error_msg in
  let loc_str = format_location filename pos in
  let source = show_source_location filename pos in
  Stdlib.Printf.eprintf "%s\n  %s %s\n%s\n"
    header
    (cyan "-->")
    loc_str
    source

let handle_unclosed_delimiter c pos filename =
  let error_msg = Printf.sprintf "unclosed delimiter '%c'" c in
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
  Parser_context.current_filename := filename;
  let lexer = Sedlexing.with_tokenizer read lexbuf in
  let parser = MenhirLib.Convert.Simplified.traditional2revised Parser.expr_file in
  try parser lexer with
  | Parser.Error -> (
    match !last_token with
    | Some EOF -> (
      match !delimiters_stack with
      | [] ->
        let header = bold (red "error") ^ ": " ^ bold "unexpected end of file" in
        Stdlib.Printf.eprintf "%s\n  %s %s\n\n"
          header
          (cyan "-->")
          (cyan filename);
        Stdlib.exit 1
      | (delimiter_char, pos) :: _ ->
        handle_unclosed_delimiter delimiter_char pos filename )
    | _ ->
      let start_pos, _ = Sedlexing.lexing_positions lexbuf in
      handle_unexpected_token start_pos filename )
  | LexerError (msg, pos) -> handle_lexer_error msg pos filename
