%{
open Sgen_ast
%}

%token SHOW SHOWEXEC
(* %token INTERFACE *)
%token USE
%token RUN
%token CONS
%token SPEC
%token CONST
%token GET
%token DEF
%token PROCESS
%token DRARROW
%token TRACE
%token UNION
%token SHARP
%token KILL CLEAN
%token EXEC LINEXEC
(* %token PROCESS *)
%token GALAXY
%token EQ

%start <Sgen_ast.program> program
%start <Sgen_ast.declaration> declaration

%%

let program := ~=pars(declaration)*; EOF; <>
let ident := ~=ray; <>

let declaration :=
  | SPEC; ~=ident; ~=galaxy_expr; <Def>
  | DEF; ~=ident; ~=galaxy_expr;  <Def>
  | SHOW; ~=galaxy_expr;          <Show>
  | SHOWEXEC; ~=galaxy_expr;      <ShowExec>
  | TRACE; ~=galaxy_expr;         <Trace>
  | RUN; ~=galaxy_expr;           <Run>
  | ~=type_declaration;          <TypeDef>
  | USE; ~=ident+;                <Use>
  (* | INTERFACE; EOL*; x=ident; EOL*; i=interface_item*; END; INTERFACE?;
    { Def (x, Raw (Interface i)) } *)

let type_declaration :=
  | CONS; CONS; x=ident; ts=type_expr+; { TDef (x, ts) }
  | EQ; EQ; x=ident; g=galaxy_expr;     { TExp (x, g) }

let type_expr :=
  | t=ident;                              { (t, None) }
  | LPAR; t=ident; SLASH; ck=ident; RPAR; { (t, Some ck) }

let galaxy_expr :=
  | ~=galaxy_content;   <>
  | ~=pars(process);    <>

(* let interface_item := ~=pars(type_declaration); <> *)

let raw_galaxy :=
  | CONST;                         { Const [] }
  | CONST; ~=marked_constellation; <Const>
  | GALAXY; ~=pars(galaxy_item)*;  <Galaxy>

let prefixed_id := SHARP; ~=ident; <Id>

let galaxy_content :=
  | ~=pars(raw_galaxy);                         <Raw>
  | ~=pars(galaxy_access);                      <>
  | AT; ~=galaxy_content;                       <Focus>
  | ~=galaxy_content; ~=bracks(substitution);   <Subst>
  | ~=pars(galaxy_block);                       <>
  | ~=prefixed_id;                              <>
  | LPAR; UNION; g1=galaxy_content; g2=galaxy_content; RPAR;
    { Union (g1, g2) }

let galaxy_block :=
  | EXEC; ~=galaxy_content;    <Exec>
  | LINEXEC; ~=galaxy_content; <LinExec>
  | KILL; ~=galaxy_content;    <Kill>
  | CLEAN; ~=galaxy_content;   <Clean>
  | EXEC; g=raw_galaxy;        { Exec (Raw g) }
  | LINEXEC; g=raw_galaxy;     { LinExec (Raw g) }
  | KILL; g=raw_galaxy;        { Kill (Raw g) }
  | CLEAN; g=raw_galaxy;       { Clean (Raw g) }

let galaxy_access :=
  | GET; x=ident; y=ident;               { Access (Id x, y) }
  | GET; ~=pars(galaxy_access); y=ident; <Access>

let substitution :=
  | DRARROW; ~=symbol;                      <Extend>
  | ~=symbol; DRARROW;                      <Reduce>
  | ~=VAR; DRARROW; ~=ray;                  <SVar>
  | f=symbol; DRARROW; g=symbol;            { SFunc (f, g) }
  | SHARP; ~=ident; DRARROW; ~=galaxy_expr; <SGal>
  | SHARP; x=ident; DRARROW;
    h=marked_constellation;                 { SGal (x, Raw (Const h)) }

let galaxy_item :=
  | ~=ident; ~=galaxy_content; <GLabelDef>
  | ~=ident; ~=pars(process);  <GLabelDef>
  | ~=type_declaration;        <GTypeDef>

let process :=
  | PROCESS;                  { Process [] }
  | PROCESS; ~=process_item+; <Process>

let process_item :=
  | ~=galaxy_content; <>
  | AMP; KILL;        { Id (const "kill") }
  | AMP; CLEAN;       { Id (const "clean") }
