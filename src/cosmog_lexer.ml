open Cosmog_parser

let space = [%sedlex.regexp? Plus (' ' | '\t')]

let newline = [%sedlex.regexp? '\r' | '\n' | "\r\n"]

let rec comments lexbuf =
  let tok =
    match%sedlex lexbuf with
    | "*)" | eof -> read lexbuf
    | _ ->
      ignore (Sedlexing.next lexbuf);
      comments lexbuf
  in
  tok

and read lexbuf =
  match%sedlex lexbuf with
  | "fun" -> FUN
  | "let" -> LET
  | "print" -> PRINT
  | 'a' .. 'z', Star ('a' .. 'z' | 'A' .. 'Z' | '0' .. '9' | '_' | '\'') ->
    let id = Sedlexing.Utf8.lexeme lexbuf in
    IDENT id
  | '(' -> LPAR
  | ')' -> RPAR
  | "->" -> RARROW
  | "=" -> EQ
  | "(*" -> comments lexbuf
  | '"' -> string_literal lexbuf
  | space -> read lexbuf
  | newline -> read lexbuf
  | eof -> EOF
  | _ -> failwith "Unexpected symbol in lexing."

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
