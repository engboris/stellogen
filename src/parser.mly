%{
open Expr.Raw
%}

%token <string> VAR
%token <string> SYM
%token STRMARK
%token AT
%token BAR
%token LPAR RPAR
%token LBRACK RBRACK
%token LANGLE RANGLE
%token UNQUOTE
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
  | BAR; ~=expr+; <>

let expr :=
  | ~=SYM; <Symbol>
  | ~=VAR; <Var>
  | UNQUOTE; ~=expr; <Unquote>
  | AT; ~=expr; <Focus>
  | ~=pars(expr+); <List>
  | LANGLE; es=revlist(expr); RANGLE; <Stack>
  | LBRACK; es=revlist(expr); RBRACK; <Cons>
  | LBRACK; ~=revlist(expr); ~=params; RBRACK; <ConsWithParams>
