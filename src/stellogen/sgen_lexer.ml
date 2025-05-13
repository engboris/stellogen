open Sgen_parser

exception SyntaxError of string

let update_pos_newline lexbuf =
  Sedlexing.new_line lexbuf;
  EOL

let rec read lexbuf =
  match%sedlex lexbuf with
  (* Stellogen *)
  | '{' -> LBRACE
  | '}' -> RBRACE
  | "end" -> END
  | "exec" -> EXEC
  | "run" -> RUN
  | "interface" -> INTERFACE
  | "show" -> SHOW
  | "spec" -> SPEC
  | "kill" -> KILL
  | "clean" -> CLEAN
  | "use" -> USE
  | "trace" -> TRACE
  | "linear-exec" -> LINEXEC
  | "show-exec" -> SHOWEXEC
  | "galaxy" -> GALAXY
  | "process" -> PROCESS
  | "->" -> RARROW
  | "=>" -> DRARROW
  | "." -> DOT
  | "#" -> SHARP
  | "&" -> AMP
  | '"' -> read_string (Buffer.create 255) lexbuf
  (* Stellar resolution *)
  | '|' -> BAR
  | "!=" -> NEQ
  | '_' -> PLACEHOLDER
  | '[' -> LBRACK
  | ']' -> RBRACK
  | '(' -> LPAR
  | ')' -> RPAR
  | ',' -> COMMA
  | '@' -> AT
  | '+' -> PLUS
  | '-' -> MINUS
  | '=' -> EQ
  | ':' -> CONS
  | ';' -> SEMICOLON
  (* Identifiers *)
  | Plus 'A' .. 'Z', Star ('a' .. 'z' | 'A' .. 'Z' | '0' .. '9' | '_' | '-') ->
    VAR (Sedlexing.Utf8.lexeme lexbuf)
  | ( ('a' .. 'z' | '0' .. '9')
    , Star ('a' .. 'z' | 'A' .. 'Z' | '0' .. '9' | '_' | '?') ) ->
    SYM (Sedlexing.Utf8.lexeme lexbuf)
  (* Whitespace *)
  | Plus (' ' | '\t') -> read lexbuf
  | '\r' | '\n' | "\r\n" -> update_pos_newline lexbuf
  (* Comments *)
  | '\'' -> comment lexbuf
  | "'''" -> comments lexbuf
  | eof -> EOF
  | _ ->
    raise (SyntaxError ("Unexpected character: " ^ Sedlexing.Utf8.lexeme lexbuf))

and read_string buf lexbuf =
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
    Buffer.add_string buf (Sedlexing.Utf8.lexeme lexbuf);
    read_string buf lexbuf
  | eof -> raise (SyntaxError "String is not terminated")
  | _ ->
    raise
      (SyntaxError ("Illegal string character: " ^ Sedlexing.Utf8.lexeme lexbuf))

and comment lexbuf =
  match%sedlex lexbuf with
  | '\r' | '\n' | "\r\n" -> EOL
  | eof -> EOF
  | _ -> comment lexbuf

and comments lexbuf =
  match%sedlex lexbuf with "'''" -> read lexbuf | _ -> comments lexbuf
