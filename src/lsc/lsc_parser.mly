%{
open Lsc_ast
%}

%token <string> VAR
%token <string> SYM
%token STAR CONST
%token BANS
%token SLASH
%token NEQ INCOMP
%token PLUS MINUS
%token PLACEHOLDER

%start <marked_constellation> constellation_file
%start <marked_constellation> marked_constellation

%%

let constellation_file :=
  | EOF;                         { [] }
  | ~=marked_constellation; EOF; <>

let marked_constellation :=
  | ~=star+; <>

let star :=
  | ~=pars(STAR; star_content);     <Unmarked>
  | ~=pars(AT; STAR; star_content); <Marked>

let star_content :=
  | l=ray*; bs=pars(bans)?;
    { { content=l; bans=Option.to_list bs |> List.concat } }

%public let bans :=
  | BANS; ~=ban+; <>

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
  | LPAR; pf=symbol; ts=ray_internal+; RPAR; { to_func (pf, ts) }

let ray_internal :=
  | ~=ray; <>
  | LBRACK; AMP; pf=symbol; rs=ray_internal+; RBRACK;
    { Base.List.reduce_exn rs ~f:(fun r1 r2 -> to_func (pf, [r2; r1]) ) }
  | LBRACK; rs=ray_internal+; RBRACK;
    { Base.List.reduce_exn rs ~f:(fun r1 r2 ->
      to_func (muted (Null, "cons"), [r2; r1]) ) }
  | LANGLE; pfs=symbol+; SLASH; r=ray; RANGLE;
    { Base.List.fold_left pfs ~init:r ~f:(fun acc pf -> to_func (pf, [acc]) ) }
