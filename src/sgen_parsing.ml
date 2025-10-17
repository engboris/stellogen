open Base
open Lexing
open Lexer
open Parser

let red text = "\x1b[31m" ^ text ^ "\x1b[0m"

let bold text = "\x1b[1m" ^ text ^ "\x1b[0m"

let cyan text = "\x1b[36m" ^ text ^ "\x1b[0m"

let yellow text = "\x1b[33m" ^ text ^ "\x1b[0m"

let string_of_token = function
  | VAR s | SYM s | STRING s -> s
  | AT -> "@"
  | BAR -> "|"
  | LPAR -> "("
  | RPAR -> ")"
  | LBRACK -> "["
  | RBRACK -> "]"
  | LBRACE -> "{"
  | RBRACE -> "}"
  | LANGLE -> "<"
  | RANGLE -> ">"
  | SHARP -> "#"
  | EOF -> "EOF"

let is_end_delimiter = function
  | RPAR | RANGLE | RBRACK | RBRACE -> true
  | _ -> false

let get_line filename line_num =
  let ic = Stdlib.open_in filename in
  let rec skip_lines n =
    if n <= 0 then ()
    else
      match Stdlib.input_line ic with
      | exception End_of_file -> ()
      | _ -> skip_lines (n - 1)
  in
  skip_lines (line_num - 1);
  let result = try Some (Stdlib.input_line ic) with End_of_file -> None in
  Stdlib.close_in ic;
  result

let unexpected_token_msg () =
  match !last_token with
  | Some tok when is_end_delimiter tok ->
    Printf.sprintf "no opening delimiter for '%s'" (string_of_token tok)
  | Some tok -> Printf.sprintf "unexpected symbol '%s'" (string_of_token tok)
  | None -> "unexpected end of input"

let format_location filename pos =
  let column = pos.pos_cnum - pos.pos_bol + 1 in
  Printf.sprintf "%s:%d:%d" (cyan filename) pos.pos_lnum column

let show_source_location filename pos =
  match get_line filename pos.pos_lnum with
  | Some line ->
    let line_num_str = Printf.sprintf "%4d" pos.pos_lnum in
    let column = pos.pos_cnum - pos.pos_bol + 1 in
    let pointer = String.make (column - 1) ' ' ^ red "^" in
    Printf.sprintf "\n %s %s %s\n      %s %s\n" (cyan line_num_str) (cyan "|")
      line (cyan "|") pointer
  | None -> ""

let print_syntax_error pos error_msg filename =
  let header = bold (red "error") ^ ": " ^ bold error_msg in
  let loc_str = format_location filename pos in
  let source = show_source_location filename pos in
  Stdlib.Printf.eprintf "%s\n  %s %s\n%s\n" header (cyan "-->") loc_str source

let handle_unclosed_delimiter c pos filename =
  let error_msg = Printf.sprintf "unclosed delimiter '%c'" c in
  print_syntax_error pos error_msg filename;
  Stdlib.exit 1

let handle_unexpected_token start_pos filename =
  let error_msg = unexpected_token_msg () in
  print_syntax_error start_pos error_msg filename;
  Stdlib.exit 1

let handle_lexer_error msg pos filename =
  print_syntax_error pos msg filename;
  Stdlib.exit 1

(* Parse with error recovery - collects multiple errors *)
let parse_with_error_recovery filename lexbuf =
  Parser_context.current_filename := filename;

  (* Error collector *)
  let error_collector = Parse_error.create_collector ~max_errors:20 () in

  (* Token buffer for recovery *)
  let token_buffer = ref [] in
  let lex_next () =
    match !token_buffer with
    | tok :: rest ->
      token_buffer := rest;
      tok
    | [] ->
      let token = read lexbuf in
      let start_pos, end_pos = Sedlexing.lexing_positions lexbuf in
      (token, start_pos, end_pos)
  in

  (* Start incremental parsing *)
  let initial_checkpoint = Parser.Incremental.expr_file Lexing.dummy_pos in

  (* Attempt error recovery by skipping tokens *)
  let rec attempt_recovery checkpoint skip_count =
    if skip_count <= 0 then checkpoint
    else
      let token, _, _ = lex_next () in
      match token with
      | EOF -> checkpoint (* Don't skip EOF *)
      | _ -> attempt_recovery checkpoint (skip_count - 1)
  in

  (* Drive the incremental parser with error recovery *)
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
    | Parser.MenhirInterpreter.HandlingError env -> (
      (* Collect the error *)
      let error =
        Parse_error.error_from_env env !last_token !delimiters_stack
      in
      Parse_error.add_error error_collector error;

      (* Determine recovery strategy *)
      let recovery =
        Parse_error.recovery_strategy !last_token
          (List.length !delimiters_stack)
      in

      match recovery with
      | Parse_error.Abort ->
        (* Cannot recover - return empty list and report errors *)
        []
      | Parse_error.Skip n ->
        (* Skip n tokens and restart from initial state *)
        let _ = attempt_recovery checkpoint n in
        let new_checkpoint = Parser.Incremental.expr_file Lexing.dummy_pos in
        drive new_checkpoint
      | Parse_error.SkipToDelimiter ->
        (* Skip until we find a delimiter at current nesting level *)
        let target_depth = List.length !delimiters_stack in
        let rec skip_to_matching () =
          let token, _, _ = lex_next () in
          match token with
          | EOF -> ()
          | _ when List.length !delimiters_stack = target_depth -> ()
          | _ -> skip_to_matching ()
        in
        skip_to_matching ();
        let new_checkpoint = Parser.Incremental.expr_file Lexing.dummy_pos in
        drive new_checkpoint
      | Parse_error.SkipUntil target_token ->
        (* Skip until we see target token *)
        let rec skip_until () =
          let token, _, _ = lex_next () in
          if (not (Poly.equal token target_token)) && not (Poly.equal token EOF)
          then skip_until ()
        in
        skip_until ();
        let new_checkpoint = Parser.Incremental.expr_file Lexing.dummy_pos in
        drive new_checkpoint )
    | Parser.MenhirInterpreter.Accepted result -> result
    | Parser.MenhirInterpreter.Rejected ->
      let error =
        Parse_error.create_error ~position:Lexing.dummy_pos
          ~message:"parse rejected" ()
      in
      Parse_error.add_error error_collector error;
      []
  in

  let result =
    try drive initial_checkpoint
    with LexerError (msg, pos) ->
      let error = Parse_error.create_error ~position:pos ~message:msg () in
      Parse_error.add_error error_collector error;
      []
  in

  (* Report all collected errors *)
  if Parse_error.has_errors error_collector then begin
    let errors = Parse_error.get_errors error_collector in
    List.iter errors ~f:(fun error ->
      let hint_msg =
        match error.hint with
        | Some h -> "\n  " ^ yellow "hint" ^ ": " ^ h
        | None -> ""
      in
      print_syntax_error error.position error.message filename;
      if Option.is_some error.hint then Stdlib.Printf.eprintf "%s\n" hint_msg );
    Stdlib.Printf.eprintf "\n%s\n"
      (bold (red (Printf.sprintf "found %d error(s)" (List.length errors))));
    Stdlib.exit 1
  end;

  result

(* Original parse function for backward compatibility - now uses error recovery *)
let parse_with_error filename lexbuf = parse_with_error_recovery filename lexbuf

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
  (visited : string list) : Expr.macro_env =
  (* Resolve the filename relative to the current file *)
  let resolved_filename = resolve_path current_file filename in

  (* Check for circular imports *)
  if List.mem visited resolved_filename ~equal:String.equal then
    failwith
      (Printf.sprintf "Circular macro import detected: %s" resolved_filename);

  let visited = resolved_filename :: visited in

  try
    let ic = Stdlib.open_in resolved_filename in
    let lexbuf = Sedlexing.Utf8.from_channel ic in
    Sedlexing.set_filename lexbuf resolved_filename;

    let expr = parse_with_error resolved_filename lexbuf in
    Stdlib.close_in ic;

    (* First, recursively load imports from this file *)
    let nested_imports = Expr.collect_macro_imports expr in
    let nested_macros =
      List.concat_map nested_imports ~f:(fun import_path ->
        load_macro_file import_path resolved_filename visited )
    in

    (* Then extract macros from this file *)
    let file_macros = Expr.extract_macros expr in

    (* Combine nested macros with this file's macros *)
    (* Later imports override earlier ones *)
    nested_macros @ file_macros
  with Sys_error msg ->
    failwith
      (Printf.sprintf "Error loading macro file '%s': %s" resolved_filename msg)

(* Preprocess with macro imports *)
let preprocess_with_imports (source_file : string) (raw_exprs : Expr.Raw.t list)
  : Expr.expr Expr.loc list =
  (* Phase 1: Collect and load all imported macros *)
  let import_files = Expr.collect_macro_imports raw_exprs in
  let macro_env =
    List.concat_map import_files ~f:(fun import_path ->
      load_macro_file import_path source_file [] )
  in

  (* Phase 2: Preprocess with the macro environment *)
  Expr.preprocess_with_macro_env macro_env raw_exprs
