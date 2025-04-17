%{
open Sgen_ast
%}

%token SHOW SHOWEXEC
%token EXEC
%token INTERFACE
%token RUN
%token SPEC
%token TRACE
%token SHARP
%token LINEXEC
%token PROCESS
%token GALAXY
%token RARROW DRARROW
%token EQ
%token END

%left RARROW
%nonassoc AT

%start <Sgen_ast.program> program

%%

let program :=
  | EOL*; EOF;                            { [] }
  | EOL*; d=declaration; EOL+; p=program; { d::p }
  | EOL*; d=declaration; EOF;             { [d] }

let declaration :=
  | SPEC; ~=SYM; EOL*; EQ; EOL*;
    ~=galaxy_expr;                 <Def>
  | ~=SYM; EOL*; EQ; EOL*;
    ~=galaxy_expr;                 <Def>
  | INTERFACE; EOL*; x=SYM; EOL*;
    i=interface_item*;
    END; INTERFACE?;               { Def (x, Raw (Interface i)) }
  | SHOW; EOL*; ~=galaxy_expr;     <Show>
  | SHOWEXEC; EOL*; ~=galaxy_expr; <ShowExec>
  | TRACE; EOL*; ~=galaxy_expr;    <Trace>
  | RUN; EOL*; ~=galaxy_expr;      <Run>
  | ~=type_declaration;            <TypeDef>

let type_declaration :=
  | x=SYM; CONS; CONS; ts=separated_list(COMMA, SYM);
    EOL*; ck=bracks(SYM)?; EOL*; DOT;                 { TDef (x, ts, ck) }
  | x=SYM; CONS; EQ; CONS; EOL*; g=galaxy_expr;       { TExp (x, g) }

let galaxy_expr :=
  | ~=galaxy_content; EOL*; DOT; <>
  | ~=process;                   <>
  | ~=undelimited_raw_galaxy;    <Raw>

let interface_item :=
  | ~=type_declaration; EOL*; <>

let undelimited_raw_galaxy :=
  | ~=marked_constellation; EOL*; DOT;                <Const>
  | GALAXY; EOL*; ~=galaxy_item*; EOL*; END; GALAXY?; <Galaxy>

let delimited_raw_galaxy :=
  | ~=pars(marked_constellation);   <Const>
  | braces(EOL*);                   { Const [] }
  | ~=braces(marked_constellation); <Const>

let galaxy_content :=
  | ~=pars(galaxy_content);                   <>
  | SHARP; ~=SYM;                             <Id>
  | ~=delimited_raw_galaxy;                   <Raw>
  | g=galaxy_content; h=galaxy_content;       { Union (g, h) }
  | ~=galaxy_access;                          <>
  | AT; ~=focussed_galaxy_content;            <Focus>
  | ~=galaxy_content; ~=bracks(substitution); <Subst>
  | ~=galaxy_block;                           <>

let focussed_galaxy_content :=
  | ~=pars(galaxy_content); <>
  | ~=galaxy_access;        <>
  | SHARP; ~=SYM;           <Id>
  | ~=delimited_raw_galaxy; <Raw>
  | ~=galaxy_block;         <>

let galaxy_block :=
  | EXEC; EOL*; ~=galaxy_content; EOL*; END; EXEC?;
    <Exec>
  | LINEXEC; EOL*; ~=galaxy_content; EOL*; END; LINEXEC?;
    <LinExec>
  | EXEC; EOL*; mcs=marked_constellation; EOL*; END; EXEC?;
    { Exec (Raw (Const mcs)) }
  | LINEXEC; EOL*; mcs=marked_constellation; EOL*; END; LINEXEC?;
    { LinExec (Raw (Const mcs)) }

let galaxy_access :=
  | SHARP; x=SYM; RARROW; y=SYM;    { Access (Id x, y) }
  | ~=galaxy_access; RARROW; y=SYM; <Access>

let substitution :=
  | DRARROW; ~=symbol;                    <Extend>
  | ~=symbol; DRARROW;                    <Reduce>
  | ~=VAR; DRARROW; ~=ray;                <SVar>
  | f=symbol; DRARROW; g=symbol;          { SFunc (f, g) }
  | SHARP; ~=SYM; DRARROW; ~=galaxy_expr; <SGal>
  | SHARP; x=SYM; DRARROW;
    h=marked_constellation;               { SGal (x, Raw (Const h)) }

let galaxy_item :=
  | ~=SYM; EQ; EOL*; ~=galaxy_content; DOT; EOL*; <GLabelDef>
  | x=SYM; EQ; EOL*; mcs=marked_constellation; EOL*; DOT; EOL*;
    { GLabelDef (x, Raw (Const mcs)) }
  | x=SYM; EQ; EOL*; g=undelimited_raw_galaxy; EOL*; DOT; EOL*;
    { GLabelDef (x, Raw g) }
  | ~=SYM; EQ; EOL*; ~=process; EOL*;             <GLabelDef>
  | ~=type_declaration; EOL*;                     <GTypeDef>

let process :=
  | PROCESS; EOL*; END; PROCESS?;
    { Process [] }
  | PROCESS; EOL*; ~=process_item+; END; PROCESS?;
    <Process>

let process_item :=
  | ~=galaxy_content; DOT; EOL*;    <>
  | ~=undelimited_raw_galaxy; EOL*; <Raw>
