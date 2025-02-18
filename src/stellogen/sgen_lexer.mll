{
  open Sgen_parser
  exception SyntaxError of string
}

let alpha    = ['a'-'z' 'A'-'Z']
let num      = ['0'-'9']
let alphanum = alpha | num
let ident    = ['a'-'z' '0'-'9'] (alphanum | [ '_' '?'])*
let var_id   = ['A'-'Z'] (alphanum | ['_' '-'])*
let space    = [' ' '\t']+
let newline  = '\r' | '\n' | "\r\n"

rule read = parse
  (* Stellogen *)
  | '{'         { LBRACE }
  | '}'         { RBRACE }
  | "end"       { END }
  | "exec"      { EXEC }
  | "run"       { RUN }
  | "interface" { INTERFACE }
  | "show"      { SHOW }
  | "trace"     { TRACE }
  | "show-exec" { SHOWEXEC }
  | "galaxy"    { GALAXY }
  | "process"   { PROCESS }
  | "->"        { RARROW }
  | "=>"        { DRARROW }
  | "."         { DOT }
  | "#"         { SHARP }
  | '"'         { read_string (Buffer.create 255) lexbuf }
  (* Stellar resolution *)
  | '|'         { BAR }
  | "!="        { NEQ }
  | '_'         { PLACEHOLDER }
  | '['         { LBRACK }
  | ']'         { RBRACK }
  | '('         { LPAR }
  | ')'         { RPAR }
  | ','         { COMMA }
  | '@'         { AT }
  | '+'         { PLUS }
  | '-'         { MINUS }
  | '='         { EQ }
  | ':'         { CONS }
  | ';'         { SEMICOLON }
  | var_id      { VAR (Lexing.lexeme lexbuf) }
  | ident       { SYM (Lexing.lexeme lexbuf) }
  (* Common *)
  | '\''        { comment lexbuf }
  | "'''"       { comments lexbuf }
  | space       { read lexbuf }
  | newline     {
    let pos = lexbuf.lex_curr_p in
    lexbuf.lex_curr_p <- {
      lexbuf.lex_curr_p with
      pos_lnum = pos.pos_lnum+1;
      pos_bol = lexbuf.lex_curr_pos
    };
    EOL
  }
  | eof       { EOF }
  | _         {
    raise (SyntaxError
      ("unexpected character '" ^
      (Lexing.lexeme lexbuf) ^
      "' during lexing"))
  }

and read_string buf = parse
  | '"'       { SYM ("\""^(Buffer.contents buf)^"\"") }
  | '\\' '/'  { Buffer.add_char buf '/'; read_string buf lexbuf }
  | '\\' '\\' { Buffer.add_char buf '\\'; read_string buf lexbuf }
  | '\\' 'b'  { Buffer.add_char buf '\b'; read_string buf lexbuf }
  | '\\' 'f'  { Buffer.add_char buf '\012'; read_string buf lexbuf }
  | '\\' 'n'  { Buffer.add_char buf '\n'; read_string buf lexbuf }
  | '\\' 'r'  { Buffer.add_char buf '\r'; read_string buf lexbuf }
  | '\\' 't'  { Buffer.add_char buf '\t'; read_string buf lexbuf }
  | [^ '"' '\\']+
    { Buffer.add_string buf (Lexing.lexeme lexbuf);
      read_string buf lexbuf
    }
  | _ {
    raise (SyntaxError
      ("Illegal string character: " ^ Lexing.lexeme lexbuf))
    }
  | eof { raise (SyntaxError ("String is not terminated")) }

and comment = parse
  | newline        { EOL }
  | eof            { EOF }
  | _              { comment lexbuf }

and comments = parse
  | "'''"    { read lexbuf }
  | _        { comments lexbuf }
