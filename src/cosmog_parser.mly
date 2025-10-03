%{
open Lambda

let counter = ref 0

let fresh_loc content =
  let n = !counter in
  counter := n + 1;
  { content; loc = string_of_int n }
%}

%token <string> IDENT
%token <string> STRING
%token FUN
%token RARROW
%token EQ
%token LET
%token PRINT
%token LPAR RPAR
%token EOF

%start <Lambda.program> expr_file

%%

let delimited_opt(l, x, r) :=
  | ~=x; <>
  | ~=delimited(l, x, r); <>

let pars(x) == ~=delimited(LPAR, x, RPAR); <>

let expr_file :=
  | EOF; { [] }
  | es=decl+; EOF; { es }

let decl :=
  | LET; x=IDENT; EQ; e=expr; { Let (x, fresh_loc e) }
  | PRINT; ~=IDENT; <Print>

let expr :=
  | ~=pars(expr); <>
  | x=IDENT;
    { Var x }
  | FUN; x=IDENT; RARROW; e=expr;
    { Fun (fresh_loc x, fresh_loc e) }
  | LPAR; e1=expr; e2=expr; RPAR;
    { App (fresh_loc e1, fresh_loc e2) }
