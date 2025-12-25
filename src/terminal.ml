(* terminal.ml - Shared terminal formatting utilities *)

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

(* Format a source line with pointer for error display *)
let format_source_line ~line_num ~line_content ~column =
  let line_num_str = Printf.sprintf "%4d" line_num in
  let pointer = String.make (max 0 (column - 1)) ' ' ^ red "^" in
  Printf.sprintf "\n %s %s %s\n      %s %s\n" (cyan line_num_str) (cyan "|")
    line_content (cyan "|") pointer

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
