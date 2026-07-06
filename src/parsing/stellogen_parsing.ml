open Base
open Stdio
open Lexing
open Lexer
open Expression_error
open Terminal

exception ImportError of expr_err

let get_line filename line_num =
  try
    In_channel.with_file filename ~f:(fun ic ->
      let rec skip_lines n =
        if n <= 0 then ()
        else
          match In_channel.input_line ic with
          | None -> ()
          | Some _ -> skip_lines (n - 1)
      in
      skip_lines (line_num - 1);
      In_channel.input_line ic )
  with Sys_error _ -> None

let format_location filename pos =
  let column = pos.pos_cnum - pos.pos_bol + 1 in
  Terminal.format_location ~filename ~line:pos.pos_lnum ~column

let show_source_location filename pos =
  match get_line filename pos.pos_lnum with
  | Some line ->
    let column = pos.pos_cnum - pos.pos_bol + 1 in
    Terminal.format_source_line ~line_num:pos.pos_lnum ~line_content:line
      ~column
  | None -> ""

let print_syntax_error pos error_msg filename =
  let header = error_label ^ ": " ^ bold error_msg in
  let loc_str = format_location filename pos in
  let source = show_source_location filename pos in
  Stdlib.Printf.eprintf "%s\n  %s %s\n%s\n" header (cyan "-->") loc_str source

(* Report a single parse error and exit *)
let report_error filename error =
  let hint_msg =
    match error.Parse_error.hint with
    | Some h -> "\n  " ^ hint_label ^ ": " ^ h
    | None -> ""
  in
  print_syntax_error error.position error.message filename;
  if Option.is_some error.hint then Stdlib.Printf.eprintf "%s\n" hint_msg;
  Stdlib.Printf.eprintf "\n%s\n" (bold (red "found 1 error(s)"));
  Stdlib.exit 1

(* Drive Menhir's incremental parser to completion, stopping and reporting
   at the first error (fail-fast, no error recovery) *)
let parse_with_error filename lexbuf =
  Parser_context.current_filename := filename;

  let lex_next () =
    let token = read lexbuf in
    let start_pos, end_pos = Sedlexing.lexing_positions lexbuf in
    (token, start_pos, end_pos)
  in

  let rec drive checkpoint =
    match checkpoint with
    | Parser.MenhirInterpreter.InputNeeded _env ->
      let token, start_pos, end_pos = lex_next () in
      let checkpoint =
        Parser.MenhirInterpreter.offer checkpoint (token, start_pos, end_pos)
      in
      drive checkpoint
    | Parser.MenhirInterpreter.Shifting _
    | Parser.MenhirInterpreter.AboutToReduce _ ->
      let checkpoint = Parser.MenhirInterpreter.resume checkpoint in
      drive checkpoint
    | Parser.MenhirInterpreter.HandlingError env ->
      let error =
        Parse_error.error_from_env env !last_token !delimiters_stack
      in
      report_error filename error
    | Parser.MenhirInterpreter.Accepted result -> result
    | Parser.MenhirInterpreter.Rejected ->
      report_error filename
        (Parse_error.create_error ~position:Lexing.dummy_pos
           ~message:"parse rejected" () )
  in

  try drive (Parser.Incremental.expr_file Lexing.dummy_pos)
  with LexerError (msg, pos) ->
    report_error filename
      (Parse_error.create_error ~position:pos ~message:msg ())

(* ---------------------------------------
   Macro Import Handling
   --------------------------------------- *)

(* Resolve a path relative to a base file *)
let resolve_path (base_file : string) (relative_path : string) : string =
  if Stdlib.Filename.is_relative relative_path then
    let base_dir = Stdlib.Filename.dirname base_file in
    Stdlib.Filename.concat base_dir relative_path
  else relative_path

(* Load a file and extract its macro definitions *)
let rec load_macro_file (filename : string) (current_file : string)
  (visited : string list) : Expression.macro_env =
  (* Resolve the filename relative to the current file *)
  let resolved_filename = resolve_path current_file filename in

  (* Check for circular imports *)
  if List.mem visited resolved_filename ~equal:String.equal then
    raise (ImportError (CircularImport resolved_filename));

  let visited = resolved_filename :: visited in

  let expr =
    try
      In_channel.with_file resolved_filename ~f:(fun ic ->
        let lexbuf = Sedlexing.Utf8.from_channel ic in
        Sedlexing.set_filename lexbuf resolved_filename;
        parse_with_error resolved_filename lexbuf )
    with Sys_error msg ->
      raise
        (ImportError
           (FileLoadError { filename = resolved_filename; message = msg }) )
  in

  (* First, recursively load imports from this file *)
  let nested_imports = Expression.collect_macro_imports expr in
  let nested_macros =
    List.concat_map nested_imports ~f:(fun import_path ->
      load_macro_file import_path resolved_filename visited )
  in

  (* Then extract macros from this file *)
  let file_macros = Expression.extract_macros expr in

  (* Combine nested macros with this file's macros *)
  (* Later imports override earlier ones *)
  nested_macros @ file_macros

(* Preprocess with macro imports *)
let preprocess_with_imports (source_file : string)
  (raw_exprs : Expression.Raw.t list) : Expression.expr Expression.loc list =
  (* Phase 1: Collect and load all imported macros *)
  let import_files = Expression.collect_macro_imports raw_exprs in
  let macro_env =
    List.concat_map import_files ~f:(fun import_path ->
      load_macro_file import_path source_file [] )
  in

  (* Phase 2: Preprocess with the macro environment *)
  Expression.preprocess_with_macro_env macro_env raw_exprs

(* ---------------------------------------
   String-based API for Web Playground
   --------------------------------------- *)

let create_start_pos_for_string () =
  { Lexing.pos_fname = "<playground>"; pos_lnum = 1; pos_bol = 0; pos_cnum = 0 }

(* Parse from string instead of file *)
let parse_from_string (code : string) : Expression.Raw.t list =
  let lexbuf = Sedlexing.Utf8.from_string code in
  Sedlexing.set_position lexbuf (create_start_pos_for_string ());
  parse_with_error "<playground>" lexbuf

(* Preprocess without file imports (for web playground) *)
let preprocess_without_imports (raw_exprs : Expression.Raw.t list) :
  Expression.expr Expression.loc list =
  (* Just expand macros defined in the code itself, no file imports *)
  Expression.preprocess_with_macro_env [] raw_exprs
