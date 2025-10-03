(** Lexer for the Cosmographer mini-ML language *)

open Cosmog_parser

(** Regular expressions for whitespace *)
let space = [%sedlex.regexp? Plus (' ' | '\t')]
let newline = [%sedlex.regexp? '\r' | '\n' | "\r\n"]

(** Regular expression for identifiers *)
let identifier = [%sedlex.regexp? 'a' .. 'z', Star ('a' .. 'z' | 'A' .. 'Z' | '0' .. '9' | '_' | '\'')]

(** Get current position for error reporting *)
let get_position lexbuf =
  let start_pos, _ = Sedlexing.lexing_positions lexbuf in
  Printf.sprintf "line %d, column %d"
    start_pos.Lexing.pos_lnum
    (start_pos.Lexing.pos_cnum - start_pos.Lexing.pos_bol + 1)

(** Lex multi-line comments *)
let rec comments lexbuf =
  match%sedlex lexbuf with
  | "*)" | eof -> read lexbuf
  | _ ->
    ignore (Sedlexing.next lexbuf);
    comments lexbuf

(** Main lexer function *)
and read lexbuf =
  match%sedlex lexbuf with
  | "fun" -> FUN
  | "let" -> LET
  | "print" -> PRINT
  | identifier ->
    IDENT (Sedlexing.Utf8.lexeme lexbuf)
  | '(' -> LPAR
  | ')' -> RPAR
  | "->" -> RARROW
  | "=" -> EQ
  | "(*" -> comments lexbuf
  | '"' -> string_literal lexbuf
  | space -> read lexbuf
  | newline -> read lexbuf
  | eof -> EOF
  | _ ->
    let pos = get_position lexbuf in
    let lexeme = Sedlexing.Utf8.lexeme lexbuf in
    failwith (Printf.sprintf "Unexpected symbol '%s' at %s" lexeme pos)

(** Lex string literals with escape sequences *)
and string_literal lexbuf =
  let buffer = Buffer.create 32 in
  let rec loop () =
    match%sedlex lexbuf with
    | '"' -> STRING (Buffer.contents buffer)
    | '\\' ->
      let escaped =
        match%sedlex lexbuf with
        | 'n' -> '\n'
        | 't' -> '\t'
        | 'r' -> '\r'
        | '\\' -> '\\'
        | '"' -> '"'
        | _ ->
          let pos = get_position lexbuf in
          let lexeme = Sedlexing.Utf8.lexeme lexbuf in
          failwith (Printf.sprintf "Unknown escape sequence '\\%s' at %s" lexeme pos)
      in
      Buffer.add_char buffer escaped;
      loop ()
    | eof ->
      let pos = get_position lexbuf in
      failwith (Printf.sprintf "Unterminated string literal at %s" pos)
    | any ->
      Buffer.add_string buffer (Sedlexing.Utf8.lexeme lexbuf);
      loop ()
    | _ ->
      let pos = get_position lexbuf in
      failwith (Printf.sprintf "Invalid character in string literal at %s" pos)
  in
  loop ()
