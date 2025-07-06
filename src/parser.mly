%{
open Expr.Raw
%}

%token <string> VAR
%token <string> SYM
%token <string> STRING
%token AT
%token BAR
%token LPAR RPAR
%token LBRACK RBRACK
%token LBRACE RBRACE
%token LANGLE RANGLE
%token SHARP
%token EOF

%start <Expr.Raw.t list> expr_file

%%

let delimited_opt(l, x, r) :=
  | ~=x; <>
  | ~=delimited(l, x, r); <>

let revlist(x) :=
  | { [] }
  | t=revlist(x); h=x; { h::t }

let pars(x) == ~=delimited(LPAR, x, RPAR); <>
let bracks(x) == ~=delimited(LBRACK, x, RBRACK); <>
let bracks_opt(x) == ~=delimited_opt(LBRACK, x, RBRACK); <>

let expr_file :=
  | EOF; { [] }
  | es=expr+; EOF; { es }

let params :=
  | BAR; BAR; ~=expr+; <>

let expr :=
  | ~=SYM; <Symbol>
  | ~=VAR; <Var>
  | ~=STRING; <String>
  | SHARP; ~=expr; <Call>
  | AT; ~=expr; <Focus>
  | ~=pars(expr+); <List>
  | LANGLE; es=revlist(expr); RANGLE; <Stack>
  | LBRACK; es=revlist(expr); RBRACK; <Cons>
  | LBRACE; es=revlist(expr); RBRACE; <Group>
  | LBRACK; ~=revlist(expr); ~=params; RBRACK; <ConsWithParams>
  | LBRACK; ~=revlist(expr); BAR; ~=expr; RBRACK; <ConsWithBase>
