(* terminal.ml - Shared terminal formatting and error presentation utilities *)

open Base

(* ANSI color codes *)
let red text = "\x1b[31m" ^ text ^ "\x1b[0m"

let green text = "\x1b[32m" ^ text ^ "\x1b[0m"

let yellow text = "\x1b[33m" ^ text ^ "\x1b[0m"

let magenta text = "\x1b[35m" ^ text ^ "\x1b[0m"

let cyan text = "\x1b[36m" ^ text ^ "\x1b[0m"

let bold text = "\x1b[1m" ^ text ^ "\x1b[0m"

let dim text = "\x1b[2m" ^ text ^ "\x1b[0m"

(* Standard error message labels *)
let error_label = bold (red "error")

let hint_label = yellow "hint"

(* Format a source location as filename:line:column *)
let format_location ~filename ~line ~column =
  Printf.sprintf "%s:%d:%d" (cyan filename) line column

(* Format a Lexing.position as filename:line:column (for parser integration) *)
let format_lexing_position (pos : Lexing.position) =
  let column = pos.pos_cnum - pos.pos_bol + 1 in
  format_location ~filename:pos.pos_fname ~line:pos.pos_lnum ~column

(* Format a source line with pointer for error display *)
let format_source_line ~line_num ~line_content ~column =
  let line_num_str = Printf.sprintf "%4d" line_num in
  let pointer = String.make (max 0 (column - 1)) ' ' ^ red "^" in
  Printf.sprintf "\n %s %s %s\n      %s %s\n" (cyan line_num_str) (cyan "|")
    line_content (cyan "|") pointer

(* Read a specific line from a file, returning None if unavailable *)
let get_source_line filename line_num =
  try
    Stdio.In_channel.with_file filename ~f:(fun ic ->
      let rec skip_lines n =
        if n <= 1 then ()
        else (
          ignore (Stdio.In_channel.input_line_exn ic);
          skip_lines (n - 1) )
      in
      skip_lines line_num;
      Stdio.In_channel.input_line ic )
  with _ -> None

(* Get formatted source context for a location *)
let get_source_context ~filename ~line ~column =
  match get_source_line filename line with
  | Some line_content -> format_source_line ~line_num:line ~line_content ~column
  | None -> ""

(* Format a complete error message with optional source and hint *)
let format_error ~message ~location ~source ~hint =
  let header = error_label ^ ": " ^ bold message in
  let loc_line = Printf.sprintf "  %s %s" (cyan "-->") location in
  let hint_line =
    match hint with
    | Some h -> Printf.sprintf "  %s: %s\n" hint_label h
    | None -> ""
  in
  Printf.sprintf "%s\n%s\n%s%s\n" header loc_line source hint_line

(* Convenience function for formatting errors with a location record *)
type location =
  { filename : string
  ; line : int
  ; column : int
  }

let format_error_at_location ~message ~location ~hint =
  let loc_str =
    format_location ~filename:location.filename ~line:location.line
      ~column:location.column
  in
  let source =
    get_source_context ~filename:location.filename ~line:location.line
      ~column:location.column
  in
  format_error ~message ~location:loc_str ~source ~hint

let format_error_at_location_opt ~message ~location ~hint =
  match location with
  | Some loc -> format_error_at_location ~message ~location:loc ~hint
  | None ->
    let loc_str = "<unknown location>" in
    format_error ~message ~location:loc_str ~source:"" ~hint

(* Format comparison errors (e.g., expected vs got) *)
let format_comparison_error ~message ~location ~label1 ~value1 ~label2 ~value2 =
  let loc_str =
    match location with
    | Some loc ->
      format_location ~filename:loc.filename ~line:loc.line ~column:loc.column
    | None -> "<unknown location>"
  in
  let source =
    match location with
    | Some loc ->
      get_source_context ~filename:loc.filename ~line:loc.line
        ~column:loc.column
    | None -> ""
  in
  Printf.sprintf "%s: %s\n  %s %s\n%s\n  %s %s\n  %s %s\n\n" error_label
    (bold message) (cyan "-->") loc_str source
    (bold (label1 ^ ":"))
    (green value1)
    (bold (label2 ^ ":"))
    (yellow value2)
