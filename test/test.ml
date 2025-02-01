open Base
open Stellogen.Sgen_ast
open Stellogen.Sgen_parser
open Stellogen.Sgen_lexer

let test filename () =
  let lexbuf = Lexing.from_channel (Stdlib.open_in filename) in
  let p = program read lexbuf in
  let _ = eval_program p in
  ()

let examples =
  let directory = "../examples/" in
  let file x = directory ^ x in
  Stdlib.Sys.readdir directory
  |> Array.to_list
  |> List.filter ~f:(fun f -> not @@ Stdlib.Sys.is_directory (Stdlib.Filename.concat directory f))
  |> List.map ~f:(fun x ->
  ("Example " ^ x, `Quick, test (file x)))

let syntax =
  let file x = "./syntax/" ^ x in
  [ ("definitions", `Quick, test (file "definitions.sg")) ]

let behavior =
  let file x = "./behavior/" ^ x in
  [ ("Automata", `Quick, test (file "automata.sg"))
  ; ("Prolog", `Quick, test (file "prolog.sg"))
  ]

let () =
  Alcotest.run "Stellogen Test Suite"
    [ ("Stellogen examples test suite", examples)
    ; ("Stellogen syntax test suite", syntax)
    ; ("Stellogen behavior test suite", behavior)
    ]
