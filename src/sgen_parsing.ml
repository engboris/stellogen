open Lexing
open Lexer
open Parser

let red text = "\x1b[31m" ^ text ^ "\x1b[0m"

let string_of_token = function
  | VAR s -> s
  | SYM s -> s
  | STRING s -> s
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
  let ic = open_in filename in
  let rec loop n =
    if n = 0 then input_line ic
    else begin
      ignore (input_line ic);
      loop (n - 1)
    end
  in
  let line = try Some (loop (line_num - 1)) with End_of_file -> None in
  close_in ic;
  line

let unexpected_token_msg () =
  match !last_token with
  | Some EOF -> Printf.sprintf "Unexpected end of file or unclosed symbol"
  | Some tok when is_end_delimiter tok ->
    Printf.sprintf "No opening delimiter for '%s'." (string_of_token tok)
  | Some tok -> Printf.sprintf "Unexpected symbol '%s'." (string_of_token tok)
  | None -> "Unexpected end of input."

let string_of_line filename header lnum =
  match get_line filename lnum with
  | None -> ""
  | Some l -> Printf.sprintf "%s%s" header l

let string_of_position cnum = String.make cnum ' ' ^ red "^"

let parse_with_error filename lexbuf =
  let lexer = Sedlexing.with_tokenizer read lexbuf in
  let parser = MenhirLib.Convert.Simplified.traditional2revised expr_file in
  try parser lexer with
  | Parser.Error ->
    let start_pos, _ = Sedlexing.lexing_positions lexbuf in
    let header = Printf.sprintf "%d| " start_pos.pos_lnum in
    let size_of_header = String.length header in
    let column = start_pos.pos_cnum - start_pos.pos_bol + 1 in
    Printf.eprintf "%s at line %d, column %d.\n%s\n%s\n%s%s\n"
      (red "Syntax error") start_pos.pos_lnum column (unexpected_token_msg ())
      (string_of_line filename header start_pos.pos_lnum)
      (String.make size_of_header ' ')
      (string_of_position (column - 1));
    exit 1
  | LexerError (msg, pos) ->
    let header = Printf.sprintf "%d| " pos.pos_lnum in
    let size_of_header = String.length header in
    let column = pos.pos_cnum - pos.pos_bol + 1 in
    Printf.eprintf "%s at line %d, column %d.\n%s\n%s\n%s%s\n"
      (red "Syntax error") pos.pos_lnum column msg
      (string_of_line filename header pos.pos_lnum)
      (String.make size_of_header ' ')
      (string_of_position (column - 1));
    exit 1
