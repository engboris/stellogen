open Base
open Lsc.Lsc_ast
open Lsc.Lsc_parser
open Lsc.Lsc_lexer
open Out_channel

let usage_msg =
  "exec [-allow-unfinished-computation] [-show-steps] [-show-trace] <filename>"

let unfincomp = ref false

let showtrace = ref false

let input_file = ref ""

let anon_fun filename = input_file := filename

let speclist =
  [ ( "-allow-unfinished-computation"
    , Stdlib.Arg.Set unfincomp
    , "Show stars containing polarities which are left after execution\n\
      \      (they correspond to unfinished computation and are omitted by \
       default)." )
  ; ( "-show-trace"
    , Stdlib.Arg.Set showtrace
    , "Interactively show steps of selection and unification." )
  ]

let () =
  Stdlib.Arg.parse speclist anon_fun usage_msg;
  let lexbuf = Lexing.from_channel (Stdlib.open_in !input_file) in
  let mcs = constellation_file read lexbuf in
  let result = exec ~showtrace:!showtrace mcs in
  if not !showtrace then
    result
    |> (if !unfincomp then kill else Fn.id)
    |> string_of_constellation |> Stdlib.print_endline
  else output_string stdout "No interaction left.\n"
