open Base
open Stellogen.Sgen_ast
open Stellogen.Sgen_parser
open Stellogen.Sgen_lexer

let test filename () =
  let lexbuf = Lexing.from_channel (Stdlib.open_in filename) in
  let p = program read lexbuf in
  let _ = eval_program p in
  ()

let run_dir directory =
  Stdlib.Sys.readdir directory
  |> Array.to_list
  |> List.filter ~f:(fun f ->
       not @@ Stdlib.Sys.is_directory (Stdlib.Filename.concat directory f) )
  |> List.map ~f:(fun x -> (x, `Quick, test (directory ^ x)))

let () =
  Alcotest.run "Stellogen Test Suite"
    [ ("Stellogen examples", run_dir "../examples/")
    ; ("Stellogen exercises solutions", run_dir "../exercises/solutions/")
    ; ("Stellogen syntax", run_dir "./syntax/")
    ; ("Stellogen behavior", run_dir "./behavior/")
    ]
