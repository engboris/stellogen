open Base
open Lsc_pretty
open Sgen_ast

(* Global output buffer *)
let output_buffer : string list ref = ref []

let add_output s =
  output_buffer := s :: !output_buffer

let get_output () =
  String.concat ~sep:"\n" (List.rev !output_buffer)

let clear_output () =
  output_buffer := []

(* Simple show implementation that writes to buffer *)
let show_to_buffer constellation =
  let output = string_of_constellation constellation in
  add_output output

(* Simplified eval that uses buffer for output *)
let eval_program_with_buffer (p : program) =
  clear_output ();

  let rec eval_term env = function
    | Sgen_ast.Show expr ->
        (* Evaluate and print to buffer *)
        (match Sgen_eval.eval_sgen_expr env expr with
        | Ok (env', constellation) ->
            show_to_buffer (List.map constellation ~f:Lsc_ast.Marked.remove);
            Ok env'
        | Error e -> Error e)
    | term ->
        (* For all other terms, use standard eval but discard constellation result *)
        (match Sgen_eval.eval_sgen_expr env term with
        | Ok (env', _) -> Ok env'
        | Error e -> Error e)
  in

  let rec eval_program_internal env = function
    | [] -> Ok env
    | term :: rest ->
        (match eval_term env term with
        | Ok env' -> eval_program_internal env' rest
        | Error e -> Error e)
  in

  match eval_program_internal Sgen_ast.initial_env p with
  | Ok _env -> Ok ()
  | Error e -> Error e

(* Run Stellogen code from a string and return output *)
let run_from_string (code : string) : (string, string) Result.t =
  try
    (* Parse from string *)
    let raw_exprs = Sgen_parsing.parse_from_string code in

    (* Preprocess without imports *)
    let preprocessed = Sgen_parsing.preprocess_without_imports raw_exprs in

    (* Convert to program *)
    match Expr.program_of_expr preprocessed with
    | Error (expr_error, loc) ->
        (match Sgen_eval.pp_err (Sgen_ast.ExprError (expr_error, loc)) with
        | Ok error_msg -> Error error_msg
        | Error _ -> Error "Parse error")
    | Ok program ->
        (* Evaluate with buffered output *)
        (match eval_program_with_buffer program with
        | Ok () -> Ok (get_output ())
        | Error err ->
            (match Sgen_eval.pp_err err with
            | Ok error_msg ->
                let output = get_output () in
                if String.is_empty output then
                  Error error_msg
                else
                  Error (output ^ "\n" ^ error_msg)
            | Error _ -> Error "Evaluation error"))
  with
  | Failure msg -> Error ("Error: " ^ msg)
  | exn -> Error ("Exception: " ^ Exn.to_string exn)
