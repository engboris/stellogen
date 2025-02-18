{
  open Lsc_parser
  exception SyntaxError of string
}

let func_id  = ['a'-'z' '0'-'9'] ['a'-'z' 'A'-'Z' '0'-'9' '_' '?']*
let var_id   = ['A'-'Z'] ['A'-'Z' 'a'-'z' '0'-'9' '_' '-']*
let space    = [' ' '\t']+
let newline  = '\r' | '\n' | "\r\n"

rule read = parse
  | var_id   { VAR (Lexing.lexeme lexbuf) }
  | func_id  { SYM (Lexing.lexeme lexbuf) }
  | '\''     { comment lexbuf }
  | "'''"    { comments lexbuf }
  | '_'      { PLACEHOLDER }
  | '|'      { BAR }
  | '['      { LBRACK }
  | ']'      { RBRACK }
  | '('      { LPAR }
  | ')'      { RPAR }
  | ','      { COMMA }
  | '@'      { AT }
  | '#'      { SHARP }
  | '+'      { PLUS }
  | '-'      { MINUS }
  | ':'      { CONS }
  | ';'      { SEMICOLON }
  | '"'      { read_string (Buffer.create 255) lexbuf }
  | space    { read lexbuf }
  | newline  { read lexbuf }
  | eof      { EOF }
  | _        {
    raise (SyntaxError
      ("Unexpected character '" ^
      (Lexing.lexeme lexbuf) ^
      "' during lexing"))
  }

and read_string buf =
  parse
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
      ("illegal string character: " ^ Lexing.lexeme lexbuf))
    }
  | eof { raise (SyntaxError ("String is not terminated")) }


and comment = parse
  | (newline|eof)  { read lexbuf }
  | _              { comment lexbuf }

and comments = parse
  | "'''"    { read lexbuf }
  | _        { comments lexbuf }
