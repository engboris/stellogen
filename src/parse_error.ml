(* Error recovery and reporting for the incremental parser *)

open Base
open Lexing

(* Structured parse error *)
type parse_error =
  { position : Lexing.position
  ; end_position : Lexing.position option
  ; message : string
  ; hint : string option
  ; severity : [ `Error | `Warning ]
  }

(* Error recovery strategy *)
type recovery_action =
  | Skip of int (* Skip n tokens *)
  | SkipUntil of Parser.token (* Skip until we see this token *)
  | SkipToDelimiter (* Skip to next top-level delimiter *)
  | Abort (* Cannot recover *)

(* Error collection *)
type error_collector =
  { mutable errors : parse_error list
  ; max_errors : int
  }

let create_collector ?(max_errors = 10) () = { errors = []; max_errors }

let add_error collector error =
  if List.length collector.errors < collector.max_errors then
    collector.errors <- error :: collector.errors

let has_errors collector = not (List.is_empty collector.errors)

let get_errors collector = List.rev collector.errors

(* Format error position *)
let format_position pos =
  let column = pos.pos_cnum - pos.pos_bol + 1 in
  Printf.sprintf "%s:%d:%d" pos.pos_fname pos.pos_lnum column

(* Create a parse error from parser state *)
let create_error ~position ?end_position ~message ?hint ?(severity = `Error) ()
    =
  { position; end_position; message; hint; severity }

(* Determine recovery action based on error context *)
let recovery_strategy last_token delimiters_depth =
  match last_token with
  | Some Parser.EOF ->
    (* At EOF, can't recover by skipping *)
    Abort
  | Some (Parser.RPAR | Parser.RBRACK | Parser.RBRACE | Parser.RANGLE) ->
    (* Extra closing delimiter - skip it and try to continue *)
    Skip 1
  | Some Parser.LPAR ->
    (* Opening paren error - skip until we balance or find next top-level *)
    SkipUntil Parser.LPAR
  | Some _ when delimiters_depth > 0 ->
    (* Inside delimiters - skip to closing of current level *)
    SkipToDelimiter
  | Some _ ->
    (* Top level error - skip until we see opening paren (start of new expr) *)
    SkipUntil Parser.LPAR
  | None -> Abort

(* Check if token is a delimiter *)
let is_delimiter = function
  | Parser.LPAR | Parser.RPAR | Parser.LBRACK | Parser.RBRACK | Parser.LBRACE
  | Parser.RBRACE | Parser.LANGLE | Parser.RANGLE ->
    true
  | _ -> false

(* Check if token could start a new top-level expression *)
let is_top_level_start = function
  | Parser.LPAR -> true (* Most top-level expressions start with ( *)
  | _ -> false

(* Convert token to string for error messages *)
let string_of_token = function
  | Parser.VAR s | Parser.SYM s | Parser.STRING s -> s
  | Parser.AT -> "@"
  | Parser.BAR -> "|"
  | Parser.LPAR -> "("
  | Parser.RPAR -> ")"
  | Parser.LBRACK -> "["
  | Parser.RBRACK -> "]"
  | Parser.LBRACE -> "{"
  | Parser.RBRACE -> "}"
  | Parser.LANGLE -> "<"
  | Parser.RANGLE -> ">"
  | Parser.SHARP -> "#"
  | Parser.EOF -> "EOF"

(* Generate helpful error message based on context *)
let contextualize_error last_token delimiters_stack =
  match last_token with
  | Some Parser.EOF when not (List.is_empty delimiters_stack) ->
    let delim_char, _ = List.hd_exn delimiters_stack in
    ( Printf.sprintf "unclosed delimiter '%c'" delim_char
    , Some "add the missing closing delimiter" )
  | Some Parser.EOF -> ("unexpected end of file", Some "the input is incomplete")
  | Some ((Parser.RPAR | Parser.RBRACK | Parser.RBRACE | Parser.RANGLE) as tok)
    ->
    let tok_str =
      match tok with
      | Parser.RPAR -> ")"
      | Parser.RBRACK -> "]"
      | Parser.RBRACE -> "}"
      | Parser.RANGLE -> ">"
      | _ -> "?"
    in
    ( Printf.sprintf "no opening delimiter for '%s'" tok_str
    , Some "remove this delimiter or add a matching opening delimiter" )
  | Some tok ->
    let tok_str = string_of_token tok in
    ( Printf.sprintf "unexpected symbol '%s'" tok_str
    , Some "check if this symbol is in the right place" )
  | None -> ("unexpected end of input", None)

(* Extract error information from parser environment *)
let error_from_env env last_token delimiters_stack =
  let error_pos, end_pos = Parser.MenhirInterpreter.positions env in
  let message, hint = contextualize_error last_token delimiters_stack in

  create_error ~position:error_pos ~end_position:end_pos ~message ?hint ()
