open Sgen_parser

exception SyntaxError of string

let update_pos_newline lexbuf = Sedlexing.new_line lexbuf

let rec read lexbuf =
  match%sedlex lexbuf with
  (* Stellogen *)
  | "exec" -> EXEC
  | "run" -> RUN
  | "const" -> CONST
  | "union" -> UNION
  | "process" -> PROCESS
  | "get" -> GET
  (* | "interface" -> INTERFACE *)
  | "show" -> SHOW
  | "spec" -> SPEC
  | "def" -> DEF
  | "kill" -> KILL
  | "clean" -> CLEAN
  | "use" -> USE
  | "trace" -> TRACE
  | "linear-exec" -> LINEXEC
  | "show-exec" -> SHOWEXEC
  | "galaxy" -> GALAXY
  | "#" -> SHARP
  | "&" -> AMP
  | ':' -> CONS
  | '=' -> EQ
  | '"' -> read_string (Buffer.create 255) lexbuf
  (* Stellar resolution *)
  | "!=" -> NEQ
  | "!@" -> INCOMP
  | "=>" -> DRARROW
  | "star" -> STAR
  | "bans" -> BANS
  | '_' -> PLACEHOLDER
  | '[' -> LBRACK
  | ']' -> RBRACK
  | '<' -> LANGLE
  | '>' -> RANGLE
  | '(' -> LPAR
  | ')' -> RPAR
  | '@' -> AT
  | '/' -> SLASH
  | '+' -> PLUS
  | '-' -> MINUS
  | '=' -> EQ
  (* Identifiers *)
  | Plus 'A' .. 'Z', Star ('a' .. 'z' | 'A' .. 'Z' | '0' .. '9' | '_' | '-') ->
    VAR (Sedlexing.Utf8.lexeme lexbuf)
  | ( ('a' .. 'z' | '0' .. '9')
    , Star ('a' .. 'z' | 'A' .. 'Z' | '0' .. '9' | '_' | '?') ) ->
    SYM (Sedlexing.Utf8.lexeme lexbuf)
  (* Whitespace *)
  | Plus (' ' | '\t') -> read lexbuf
  | '\r' | '\n' | "\r\n" ->
    update_pos_newline lexbuf;
    read lexbuf
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
  | eof -> EOF
  | '\r' | '\n' | "\r\n" -> read lexbuf
  | _ ->
    ignore (Sedlexing.next lexbuf);
    comment lexbuf

and comments lexbuf =
  match%sedlex lexbuf with
  | "'''" -> read lexbuf
  | _ ->
    ignore (Sedlexing.next lexbuf);
    comments lexbuf
