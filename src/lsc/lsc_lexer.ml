open Sedlexing
open Lsc_parser

exception SyntaxError of string

let buf = Sedlexing.Utf8.from_channel

let is_func_start = [%sedlex.regexp? 'a' .. 'z' | '0' .. '9']

let is_func_rest =
  [%sedlex.regexp? 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9' | '_' | '?']

let is_var_start = [%sedlex.regexp? 'A' .. 'Z']

let is_var_rest =
  [%sedlex.regexp? 'A' .. 'Z' | 'a' .. 'z' | '0' .. '9' | '_' | '-']

let space = [%sedlex.regexp? Plus (' ' | '\t')]

let newline = [%sedlex.regexp? '\r' | '\n' | "\r\n"]

let rec read_string buf lexbuf =
  match%sedlex lexbuf with
  | '"' -> SYM ("\"" ^ Buffer.contents buf ^ "\"")
  | '\\', '/' ->
    Buffer.add_char buf '/';
    read_string buf lexbuf
  | '\\', '\\' ->
    Buffer.add_char buf '\\';
    read_string buf lexbuf
  | '\\', 'b' ->
    Buffer.add_char buf '\b';
    read_string buf lexbuf
  | '\\', 'f' ->
    Buffer.add_char buf '\012';
    read_string buf lexbuf
  | '\\', 'n' ->
    Buffer.add_char buf '\n';
    read_string buf lexbuf
  | '\\', 'r' ->
    Buffer.add_char buf '\r';
    read_string buf lexbuf
  | '\\', 't' ->
    Buffer.add_char buf '\t';
    read_string buf lexbuf
  | Plus (Compl ('"' | '\\')) ->
    Buffer.add_string buf (Utf8.lexeme lexbuf);
    read_string buf lexbuf
  | eof -> raise (SyntaxError "String is not terminated")
  | _ -> raise (SyntaxError ("Illegal string character: " ^ Utf8.lexeme lexbuf))

and comment lexbuf =
  match%sedlex lexbuf with
  | newline | eof -> read lexbuf
  | _ ->
    ignore (Sedlexing.next lexbuf);
    comment lexbuf

and comments lexbuf =
  match%sedlex lexbuf with
  | "'''" -> read lexbuf
  | _ ->
    ignore (Sedlexing.next lexbuf);
    comments lexbuf

and read lexbuf =
  match%sedlex lexbuf with
  | is_var_start, Star is_var_rest -> VAR (Utf8.lexeme lexbuf)
  | is_func_start, Star is_func_rest -> SYM (Utf8.lexeme lexbuf)
  | '\'' -> comment lexbuf
  | "'''" -> comments lexbuf
  | '_' -> PLACEHOLDER
  | '.' -> DOT
  | '|' -> BAR
  | '[' -> LBRACK
  | ']' -> RBRACK
  | '(' -> LPAR
  | ')' -> RPAR
  | ',' -> COMMA
  | '@' -> AT
  | '&' -> AMP
  | '+' -> PLUS
  | '-' -> MINUS
  | ':' -> CONS
  | ';' -> SEMICOLON
  | '"' -> read_string (Buffer.create 128) lexbuf
  | space | newline -> read lexbuf
  | eof -> EOF
  | _ ->
    raise
      (SyntaxError
         ("Unexpected character '" ^ Utf8.lexeme lexbuf ^ "' during lexing") )
