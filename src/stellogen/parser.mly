%{
open Ast
%}

%token SHOW SHOWEXEC
%token EXEC
%token INTERFACE
%token RUN
%token TRACE
%token PROCESS
%token GALAXY
%token RARROW DRARROW
%token EQ
%token DOT
%token END

%start <Sgen_ast.program> program

%%

let program :=
  | EOL*; EOF;                            { [] }
  | EOL*; d=declaration; EOL+; p=program; { d::p }
  | EOL*; d=declaration; EOF;             { [d] }

let declaration :=
  | ~=SYM; EOL*; EQ; EOL*; ~=galaxy_expr; <Def>
  | SHOW; EOL*; ~=galaxy_expr;            <Show>
  | SHOWEXEC; EOL*; ~=galaxy_expr;        <ShowExec>
  | TRACE; EOL*; ~=galaxy_expr;           <Trace>
  | RUN; EOL*; ~=galaxy_expr;             <Run>
  | ~=type_declaration;                   <TypeDef>

let type_declaration :=
  | x=SYM; CONS; CONS; ts=separated_list(COMMA, SYM);
    EOL*; ck=bracks(SYM)?; EOL*; DOT;
    { TDef (x, ts, ck) }
  | x=SYM; CONS; EQ; CONS; EOL*; g=galaxy_expr;
    { TExp (x, g) }

let galaxy_expr :=
  | ~=galaxy_content; EOL*; DOT; <>
  | ~=galaxy_block; END;         <>
  | ~=raw_galaxy_expr;           <Raw>

let raw_galaxy_expr :=
  | ~=non_neutral_start_mcs; EOL*; DOT;      <Const>
  | ~=galaxy_def; END;                       <Galaxy>
  | INTERFACE; EOL*; ~=interface_item*; END; <Interface>

let interface_item :=
  | ~=type_declaration; EOL*; <>

let raw_galaxy_content :=
  | ~=pars(non_neutral_start_mcs);   <Const>
  | braces(EOL*);                    { Const [] }
  | ~=braces(neutral_start_mcs);     <Const>
  | ~=braces(non_neutral_start_mcs); <Const>

let galaxy_content :=
  | ~=pars(galaxy_content);           <>
  | ~=SYM;                            <Id>
  | ~=raw_galaxy_content;             <Raw>
  | SHARP; ~=SYM;                     <Token>
  | g=galaxy_content; EOL*;
    h=galaxy_content; EOL*;           { Union (g, h) }
  | ~=galaxy_content; RARROW; ~=SYM;  <Access>
  | LPAR; EOL*; AT; EOL*;
    ~=galaxy_content; RPAR;           <Focus>
  | ~=galaxy_content;
    ~=bracks(substitution);           <Subst>

let substitution ==
  | DRARROW; ~=symbol;                              <Extend>
  | ~=symbol; DRARROW;                              <Reduce>
  | ~=VAR; DRARROW; ~=ray;                          <SVar>
  | f=symbol; DRARROW; g=symbol;                    { SFunc (f, g) }
  | SHARP; ~=SYM; DRARROW; ~=galaxy_content;        <SGal>
  | SHARP; x=SYM; DRARROW; h=non_neutral_start_mcs; { SGal (x, Raw (Const h)) }

%public let non_neutral_start_mcs :=
  (* single star *)
  | bracks(EOL*); EOL*; bs=bans?;
    { [ Unmarked { content = [];
        bans = Option.to_list bs |> List.concat } ]
    }
  | marked=AT?; EOL*; pf=pol_symbol; ts=args?; EOL*;
    rs=separated_list(pair(COMMA?, EOL*), ray); EOL*; bs=bans?;
    {
      [ { content = ((to_func (pf, Option.to_list ts |> List.concat)) :: rs);
          bans = Option.to_list bs |> List.concat }
        |> if Option.is_some marked then mark else unmark ]
    }
  | LBRACK; EOL*; marked=AT?; EOL*; pf=pol_symbol; ts=args?; EOL*;
    rs=separated_list(pair(COMMA?, EOL*), ray); EOL*; RBRACK; EOL*;
    bs=bans?;
    {
      [ { content = ((to_func (pf, Option.to_list ts |> List.concat)) :: rs);
          bans = Option.to_list bs |> List.concat }
        |> if Option.is_some marked then mark else unmark ]
    }
  (* more than one star *)
  | nmcs=non_neutral_start_mcs; EOL*; SEMICOLON; EOL*;
    mcs=marked_constellation;
    { nmcs @ mcs }

let neutral_start_mcs :=
  (* single ray *)
  | marked=AT?; EOL*; pf=unpol_symbol; ts=args?; EOL*; bs=bans?;
    {
      [ { content = [to_func (pf, Option.to_list ts |> List.concat)];
          bans = Option.to_list bs |> List.concat }
        |> if Option.is_some marked then mark else unmark ]
    }
  | LBRACK; EOL*; marked=AT?; EOL*; pf=unpol_symbol; ts=args?; EOL*;
    RBRACK; EOL*; bs=bans?;
    {
      [ { content = [to_func (pf, Option.to_list ts |> List.concat)];
          bans = Option.to_list bs |> List.concat }
        |> if Option.is_some marked then mark else unmark ]
    }
  (* single star *)
  | marked=AT?; EOL*; pf=unpol_symbol; ts=args?; EOL*;
    rs=separated_nonempty_list(pair(COMMA?, EOL*), ray); EOL*; bs=bans?;
    {
      [ { content = ((to_func (pf, Option.to_list ts |> List.concat)) :: rs);
          bans = Option.to_list bs |> List.concat }
        |> if Option.is_some marked then mark else unmark ]
    }
  | LBRACK; EOL*; marked=AT?; EOL*; pf=unpol_symbol; ts=args?; EOL*;
    rs=separated_nonempty_list(pair(COMMA?, EOL*), ray); EOL*; bs=bans?;
    EOL*; RBRACK;
    {
      [ { content = ((to_func (pf, Option.to_list ts |> List.concat)) :: rs);
          bans = Option.to_list bs |> List.concat }
        |> if Option.is_some marked then mark else unmark ]
    }
  (* general constellation *)
  | marked=AT?; EOL*; pf=unpol_symbol; ts=args?; EOL*;
    rs=separated_list(pair(COMMA?, EOL*), ray); EOL*;
    bs=bans?; EOL*; SEMICOLON; EOL*;
    cs=separated_nonempty_list(pair(SEMICOLON, EOL*), star);
    {
      ({ content = ((to_func (pf, Option.to_list ts |> List.concat)) :: rs);
         bans = Option.to_list bs |> List.concat }
         |> if Option.is_some marked then mark else unmark) :: cs
    }
  | LBRACK; EOL*; marked=AT?; EOL*; pf=unpol_symbol; ts=args?; EOL*;
    rs=separated_list(pair(COMMA?, EOL*), ray); EOL*; bs=bans?; EOL*;
    RBRACK; EOL*; SEMICOLON; EOL*;
    cs=separated_nonempty_list(pair(SEMICOLON, EOL*), star);
    {
      ({ content = ((to_func (pf, Option.to_list ts |> List.concat)) :: rs);
         bans = Option.to_list bs |> List.concat }
         |> if Option.is_some marked then mark else unmark) :: cs
    }

let raw_constellation :=
  | ~=braces(neutral_start_mcs); <>
  | ~=braces_opt(non_neutral_start_mcs); <>

let galaxy_def :=
  | GALAXY; EOL*; ~=galaxy_item*; <>

let galaxy_item :=
  | ~=SYM; EQ; EOL*; ~=galaxy_content; DOT; EOL*; <GLabelDef>
  | x=SYM; EQ; EOL*; mcs=non_neutral_start_mcs;
    DOT; EOL*;
    { GLabelDef (x, Raw (Const mcs)) }
  | ~=SYM; EQ; EOL*; ~=galaxy_block; END; EOL*;   <GLabelDef>
  | ~=type_declaration; EOL*;                     <GTypeDef>

let galaxy_block :=
  | PROCESS; EOL*;                         { Process [] }
  | PROCESS; EOL*; ~=process_item+;        <Process>
  | EXEC; EOL*; ~=galaxy_content;          <Exec>
  | EXEC; EOL*; mcs=non_neutral_start_mcs; { Exec (Raw (Const mcs)) }

let process_item :=
  | ~=galaxy_content; DOT; EOL*;          <>
  | mcs=non_neutral_start_mcs; DOT; EOL*; { Raw (Const mcs) }
