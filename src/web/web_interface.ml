open Base

(* Global output buffer *)
let output_buffer : string list ref = ref []

let add_output s = output_buffer := s :: !output_buffer

let get_output () = String.concat ~sep:"\n" (List.rev !output_buffer)

let clear_output () = output_buffer := []

(* Parse and preprocess a program from a string. The browser has no
   filesystem, so imports are not resolved; playground examples inline
   the prelude instead. *)
let parse_program (code : string) =
  let raw_exprs = Stellogen_parsing.parse_from_string code in
  let preprocessed = Stellogen_parsing.preprocess_without_imports raw_exprs in
  Expression.program_of_expr preprocessed

let format_err err =
  match Evaluator.pp_err err with
  | Ok msg -> msg
  | Error _ -> "Evaluation error"

(* Prepend buffered show output to a message so it is not lost when
   evaluation stops on an error. *)
let with_shows msg =
  let output = get_output () in
  if String.is_empty output then msg else output ^ "\n" ^ msg

let count_check_items program =
  List.count program ~f:(fun (item_phase, _) ->
    match item_phase with Syntax.CheckOnly -> true | _ -> false )

let eval_with_buffer (code : string)
  (eval : Syntax.program -> (string, string) Result.t) =
  try
    match parse_program code with
    | Error (expr_error, loc) ->
      Error (format_err (Syntax.ExprError (expr_error, loc, [])))
    | Ok program ->
      clear_output ();
      Evaluator.show_printer := add_output;
      eval program
  with
  | Stellogen_parsing.ParseError report -> Error report
  | Failure msg -> Error ("Error: " ^ msg)
  | exn -> Error ("Exception: " ^ Exn.to_string exn)

(* Run the run phase of a program, like 'sgen run' *)
let run_from_string (code : string) : (string, string) Result.t =
  eval_with_buffer code (fun program ->
    match Evaluator.eval_program_internal Syntax.initial_env program with
    | Ok _ ->
      let output = get_output () in
      let checked = count_check_items program in
      if String.is_empty output && checked > 0 then
        Ok
          (Printf.sprintf
             "No run-phase output. %d check-phase items were skipped; use \
              Check to evaluate them."
             checked )
      else Ok output
    | Error err -> Error (with_shows (format_err err)) )

(* Run the check phase of a program, like 'sgen check', with a summary
   line since the playground has no exit code to inspect *)
let check_from_string (code : string) : (string, string) Result.t =
  eval_with_buffer code (fun program ->
    let checked = count_check_items program in
    let _env, errors = Evaluator.eval_program_check program in
    match errors with
    | [] ->
      let summary =
        if checked = 0 then
          "Nothing to check: no check-phase items (marked with \xc2\xa7)."
        else Printf.sprintf "Check passed (%d check-phase items)." checked
      in
      Ok (with_shows summary)
    | _ ->
      let messages = List.map errors ~f:format_err |> String.concat ~sep:"\n" in
      Error (with_shows messages) )
