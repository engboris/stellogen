open Sedlexing
open Parser

exception SyntaxError of string

let space = [%sedlex.regexp? Plus (' ' | '\t')]

let newline = [%sedlex.regexp? '\r' | '\n' | "\r\n"]

let rec comment lexbuf =
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
  | Plus (Compl (Chars "'\" \t\n\r()<>[]|@#")) ->
    let lexeme = Utf8.lexeme lexbuf in
    begin
      match lexeme.[0] with 'A' .. 'Z' -> VAR lexeme | _ -> SYM lexeme
    end
  | '(' -> LPAR
  | ')' -> RPAR
  | '[' -> LBRACK
  | ']' -> RBRACK
  | '<' -> LANGLE
  | '>' -> RANGLE
  | '@' -> AT
  | '#' -> UNQUOTE
  | '|' -> BAR
  | '\'' -> comment lexbuf
  | "'''" -> comments lexbuf
  | '"' -> STRMARK
  | space | newline -> read lexbuf
  | eof -> EOF
  | _ ->
    raise
      (SyntaxError
         ("Unexpected character '" ^ Utf8.lexeme lexbuf ^ "' during lexing") )
