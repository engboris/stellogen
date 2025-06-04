%{
open Lsc_ast
%}

%token <string> VAR
%token <string> SYM
%token NEQ INCOMP
%token PLUS MINUS
%token PLACEHOLDER

%start <marked_constellation> constellation_file
%start <marked_constellation> marked_constellation

%%

let constellation_file :=
  | EOF; { [] }
  | mcs=marked_constellation; EOF; { mcs }

let marked_constellation :=
  | ~=star+; <>

let star :=
  | ~=pars(STAR; star_content);     <Unmarked>
  | ~=pars(AT; STAR; star_content); <Marked>

let star_content :=
  | l=ray*; bs=bans?;
    { { content=l; bans=Option.to_list bs |> List.concat } }

let bans :=
  | SLASH; ~=pars(ban)+; <>

let ban :=
  | NEQ; r1=ray; r2=ray;    { Ineq (r1, r2) }
  | INCOMP; r1=ray; r2=ray; { Incomp (r1, r2) }

%public let symbol :=
  | p=polarity; AMP; f=SYM; { noisy (p, f) }
  | p=polarity; AMP; PRINT; { noisy (p, "print") }
  | p=polarity; f=SYM;      { muted (p, f) }
  | f=SYM;                  { muted (Null, f) }

let polarity :=
  | PLUS;  { Pos }
  | MINUS; { Neg }

%public let ray :=
  | PLACEHOLDER; { to_var ("_"^(fresh_placeholder ())) }
  | ~=VAR; <to_var>
  | pf=symbol; { to_func (pf, []) }
  | LPAR; pf=symbol; ts=ray+; RPAR; { to_func (pf, ts) }
  | ~=blocks; <>

let blocks :=
  | LBRACK; AMP; pf=symbol; rs=ray+; RBRACK;
    { Base.List.reduce_exn (List.rev rs)
      ~f:(fun r1 r2 -> to_func (pf, [r2; r1]) ) }
  | LBRACK; rs=ray+; RBRACK;
    { Base.List.reduce_exn (List.rev rs)
      ~f:(fun r1 r2 -> to_func (muted (Null, "cons"), [r2; r1]) ) }
  | LANGLE; pfs=symbol+; SLASH; r=ray; RANGLE;
    { Base.List.fold_right pfs ~init:r ~f:(fun pf base ->
      to_func (pf, [base]) ) }
