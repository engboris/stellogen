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
  | "'''" | eof -> read lexbuf
  | _ ->
    ignore (Sedlexing.next lexbuf);
    comments lexbuf

and read lexbuf =
  match%sedlex lexbuf with
  | Compl (Chars "'\" \t\n\r()<>[]|@#%"), Star (Compl (Chars " \t\n\r()<>[]|"))
    ->
    let lexeme = Utf8.lexeme lexbuf in
    begin
      match lexeme.[0] with ('_' | 'A' .. 'Z') -> VAR lexeme | _ -> SYM lexeme
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
  | '"' -> string_literal lexbuf
  | space | newline -> read lexbuf
  | eof -> EOF
  | _ ->
    raise
      (SyntaxError
         ("Unexpected character '" ^ Utf8.lexeme lexbuf ^ "' during lexing") )

and string_literal lexbuf =
  let buffer = Buffer.create 32 in
  let rec loop () =
    match%sedlex lexbuf with
    | '"' -> STRING (Buffer.contents buffer)
    | '\\', any ->
      let escaped =
        match%sedlex lexbuf with
        | 'n' -> '\n'
        | 't' -> '\t'
        | '\\' -> '\\'
        | '"' -> '"'
        | _ -> failwith "Unknown escape sequence"
      in
      Buffer.add_char buffer escaped;
      loop ()
    | eof -> failwith "Unterminated string literal"
    | any ->
      Buffer.add_string buffer (Sedlexing.Utf8.lexeme lexbuf);
      loop ()
    | _ -> failwith "Invalid character in string literal"
  in
  loop ()
