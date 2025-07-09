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
let braces(x) == ~=delimited(LBRACE, x, RBRACE); <>
let angles(x) == ~=delimited(LANGLE, x, RANGLE); <>

let expr_file :=
  | EOF; { [] }
  | es=expr_ext+; EOF; { es }

let params :=
  | BAR; BAR; ~=expr_ext+; <>

let expr_ext :=
  | ~=pars(expr_int+); <List>
  | ~=angles(revlist(expr_int)); <Stack>
  | ~=bracks(revlist(expr_int)); <Cons>
  | ~=braces(revlist(expr_int)); <Group>
  | LBRACK; ~=revlist(expr_int); ~=params; RBRACK; <ConsWithParams>
  | LBRACK; ~=revlist(expr_int); BAR; ~=expr_int; RBRACK; <ConsWithBase>

let expr_int :=
  | ~=expr_ext; <>
  | SHARP; ~=expr_int; <Call>
  | AT; ~=expr_int; <Focus>
  | ~=SYM; <Symbol>
  | ~=VAR; <Var>
  | ~=STRING; <String>
