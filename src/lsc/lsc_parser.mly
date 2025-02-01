%{
open Lsc_ast
%}

%token BAR
%token NEQ
%token COMMA
%token <string> VAR
%token <string> SYM
%token PLUS MINUS
%token CONS
%token AT
%token SEMICOLON
%token PLACEHOLDER

%right CONS

%start <marked_constellation> constellation_file
%start <marked_constellation> marked_constellation

%%

let constellation_file :=
  | EOF; { [] }
  | ~=marked_constellation; EOF; <>

let marked_constellation :=
  | ~=separated_nonempty_list(pair(SEMICOLON, EOL*), star); SEMICOLON?; <>

%public let star :=
  | AT; ~=star_content; EOL*; <Marked>
  | ~=bracks_opt(star_content); EOL*; <Unmarked>

let star_content :=
  | LBRACK; RBRACK;
    { {content=[]; bans=[]} }
  | l=separated_nonempty_list(pair(COMMA?, EOL*), ray); bs=bans?;
    { {content=l; bans=Option.to_list bs |> List.concat } }

%public let bans :=
  | BAR; ~=ban+; <>

let ban :=
  | r1=ray; NEQ; r2=ray; { (r1, r2) }

%public let symbol :=
  | ~=pol_symbol; <>
  | ~=unpol_symbol; <>

%public let pol_symbol :=
  | PLUS; SHARP; f = SYM;  { noisy (Pos, f) }
  | PLUS; SHARP; PRINT;    { noisy (Pos, "print") }
  | PLUS; f = SYM;         { muted (Pos, f) }
  | MINUS; SHARP; f = SYM; { noisy (Neg, f) }
  | MINUS; SHARP; PRINT;   { noisy (Neg, "print") }
  | MINUS; f = SYM;        { muted (Neg, f) }

%public let unpol_symbol :=
  | f=SYM; { muted (Null, f) }

%public let args :=
  | ~=pars(separated_nonempty_list(COMMA?, ray)); <>

%public let ray :=
  | PLACEHOLDER; { to_var ("_"^(fresh_placeholder ())) }
  | ~=VAR; <to_var>
  | ~=func_expr; <>

let func_expr :=
  | ~=cons_expr; <>
  | pf=symbol; ts=args?; { to_func (pf, Option.to_list ts |> List.concat) }

let cons_expr :=
  | r1=ray; CONS; r2=ray;
    { to_func (noisy (Null, ":"), [r1; r2]) }
  | LPAR; r1=ray; CONS; r2=ray; RPAR;
    { to_func (noisy (Null, ":"), [r1; r2]) }
  | e=pars(cons_expr); CONS; r=ray;
    { to_func (muted (Null, ":"), [e; r]) }
