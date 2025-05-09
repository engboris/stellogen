%{
open Lsc_ast
%}

%token BAR
%token NEQ
%token BANG
%token COMMA
%token <string> VAR
%token <string> SYM
%token PLUS MINUS
%token CONS
%token SEMICOLON
%token PLACEHOLDER

%right CONS

%start <marked_constellation> constellation_file
%start <marked_constellation> marked_constellation

%%

let constellation_file :=
  | DOT?; EOL*; EOF;                               { [] }
  | ~=marked_constellation; EOL*; DOT?; EOL*; EOF; <>

let marked_constellation :=
  | ~=separated_nonempty_list(pair(SEMICOLON, EOL*), star);
    EOL*; SEMICOLON?; <>

let star :=
  | ~=bracks_opt(star_content);           <Unmarked>
  | ~=bracks_opt(AT; EOL*; star_content); <Marked>

let star_content :=
  | LBRACK; EOL*; RBRACK;
    { {content=[]; bans=[]} }
  | l=separated_nonempty_list(pair(COMMA?, EOL*), ray); bs=bans?;
    { {content=l; bans=Option.to_list bs |> List.concat } }

%public let bans :=
  | EOL*; BAR; EOL*; ~=separated_nonempty_list(COMMA?, ban); EOL*; <>

let ban :=
  | r1=ray; NEQ; r2=ray; EOL*;   { Ineq (r1, r2) }
  | r1=ray; CONS; r2=ray;  { Incomp (r1, r2) }

%public let symbol :=
  | p=polarity; PERCENT; f = SYM; { noisy (p, f) }
  | p=polarity; PERCENT; PRINT;   { noisy (p, "print") }
  | p=polarity; f = SYM;          { muted (p, f) }
  | f=SYM; { muted (Null, f) }

let polarity :=
  | PLUS;  { Pos }
  | MINUS; { Neg }

%public let ray :=
  | PLACEHOLDER;         { to_var ("_"^(fresh_placeholder ())) }
  | ~=VAR;               <to_var>
  | pf=symbol; ts=args?; { to_func (pf, Option.to_list ts |> List.concat) }

let ray_internal :=
  | ~=ray;       <>
  | ~=cons_expr; <>

let args :=
  | ~=pars(separated_nonempty_list(COMMA?, ray_internal)); <>

let cons_expr :=
  | r1=ray_internal; CONS; r2=ray_internal;
    { to_func (muted (Null, ":"), [r1; r2]) }
  | LPAR; r1=ray_internal; CONS; r2=ray_internal; RPAR;
    { to_func (muted (Null, ":"), [r1; r2]) }
  | e=pars(cons_expr); CONS; r=ray_internal;
    { to_func (muted (Null, ":"), [e; r]) }
