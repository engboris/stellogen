open Base
open Lsc.Lsc_ast
open Lsc.Lsc_err
open Out_channel

let usage_msg = "exec [-linear] [-show-trace] <filename>"

let unfincomp = ref false

let showtrace = ref false

let linear = ref false

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
  ; ("-linear", Stdlib.Arg.Set linear, "Actions which are used are consummed.")
  ]

let () =
  Stdlib.Arg.parse speclist anon_fun usage_msg;
  let lexbuf = Sedlexing.Utf8.from_channel (Stdlib.open_in !input_file) in
  let lexer = Sedlexing.with_tokenizer Lsc.Lsc_lexer.read lexbuf in
  let parser =
    MenhirLib.Convert.Simplified.traditional2revised
      Lsc.Lsc_parser.constellation_file
  in
  let mcs = parser lexer in
  let result =
    match exec ~linear:!linear ~showtrace:!showtrace mcs with
    | Ok result -> result
    | Error e ->
      pp_err_effect e |> Out_channel.output_string Out_channel.stderr;
      Stdlib.exit 1
  in
  if not !showtrace then
    result
    |> (if !unfincomp then kill else Fn.id)
    |> string_of_constellation |> Stdlib.print_endline
  else output_string stdout "No interaction left.\n"
