%{
open Lsc_ast
%}

%token COMMA
%token LBRACK RBRACK
%token LPAR RPAR
%token <string> VAR
%token <string> SYM
%token PLUS MINUS
%token CONS
%token AT
%token SHARP
%token SEMICOLON
%token PLACEHOLDER

%right CONS

%start <marked_constellation> constellation_file
%start <marked_constellation> marked_constellation

%%

constellation_file:
| EOF { [] }
| cs = marked_constellation; EOF { cs }

marked_constellation:
| cs = star+ { cs }

star:
| AT; s = star_content; SEMICOLON; EOL* { Marked s }
| s = star_content; SEMICOLON; EOL* { Unmarked s }

star_content:
| LBRACK; RBRACK { [] }
| rs = separated_nonempty_list(pair(COMMA?, EOL*), ray) { rs }

%public symbol:
| PLUS; SHARP; f = SYM { noisy (Pos, f) }
| PLUS; f = SYM { muted (Pos, f) }
| MINUS; SHARP; f = SYM { noisy (Neg, f) }
| MINUS; f = SYM { muted (Neg, f) }
| f = SYM { muted (Null, f) }

%public ray:
| PLACEHOLDER { to_var ("_"^(fresh_placeholder ())) }
| x = VAR { to_var x }
| e = func_expr { e }

func_expr:
| e = cons_expr { e }
| pf = symbol; LPAR; ts = separated_nonempty_list(COMMA?, ray); RPAR
	{ to_func (pf, ts) }
| pf = symbol { to_func (pf, []) }

cons_expr:
| r1 = ray; CONS; r2 = ray { to_func (noisy (Null, ":"), [r1; r2]) }
| LPAR; e = cons_expr; RPAR; CONS; r = ray
	{ to_func (muted (Null, ":"), [e; r]) }
