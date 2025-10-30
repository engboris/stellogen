open Js_of_ocaml
open Stellogen

(* Strip ANSI color codes from error messages for web display *)
let strip_ansi_codes str =
  let re = Regexp.regexp "\027\\[[0-9;]*m" in
  Regexp.global_replace re str ""

(* Main function that runs Stellogen code and returns output *)
let run_stellogen code_js =
  Console.console##log (Js.string "run_stellogen called");
  let code = Js.to_string code_js in
  Console.console##log (Js.string ("Code: " ^ code));

  try
    let result = Web_interface.run_from_string code in
    Console.console##log (Js.string "run_from_string returned");

    match result with
    | Ok output ->
      Console.console##log (Js.string ("Success: " ^ output));
      Js.string (strip_ansi_codes output)
    | Error err ->
      Console.console##log (Js.string ("Error: " ^ err));
      Js.string ("ERROR: " ^ strip_ansi_codes err)
  with e ->
    let msg = "Exception in run_stellogen: " ^ Printexc.to_string e in
    Console.console##log (Js.string msg);
    Js.string msg

(* Function that runs Stellogen code with trace and returns output *)
let trace_stellogen code_js =
  Console.console##log (Js.string "trace_stellogen called");
  let code = Js.to_string code_js in
  Console.console##log (Js.string ("Code: " ^ code));

  try
    let result = Web_interface.trace_from_string code in
    Console.console##log (Js.string "trace_from_string returned");

    match result with
    | Ok output ->
      Console.console##log (Js.string ("Success: " ^ output));
      Js.string output (* Don't strip ANSI codes from HTML *)
    | Error err ->
      Console.console##log (Js.string ("Error: " ^ err));
      Js.string ("ERROR: " ^ strip_ansi_codes err)
  with e ->
    let msg = "Exception in trace_stellogen: " ^ Printexc.to_string e in
    Console.console##log (Js.string msg);
    Js.string msg

(* Export to JavaScript *)
let () =
  Console.console##log (Js.string "Stellogen playground loaded");
  Js.export "Stellogen"
    object%js
      method run code = run_stellogen code

      method trace code = trace_stellogen code
    end
