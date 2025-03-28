open Base

let lsc filename () =
  let lexbuf = Lexing.from_channel (Stdlib.open_in filename) in
  let mcs = Lsc.Lsc_parser.constellation_file Lsc.Lsc_lexer.read lexbuf in
  match Lsc.Lsc_ast.exec ~showtrace:false mcs with
  | Error e -> Lsc.Lsc_err.pp_err_effect e
  | Ok res -> Lsc.Lsc_ast.string_of_constellation res

let sgen filename () =
  let lexbuf = Lexing.from_channel (Stdlib.open_in filename) in
  let p = Stellogen.Sgen_parser.program Stellogen.Sgen_lexer.read lexbuf in
  Stellogen.Sgen_eval.eval_program ~typecheckonly:false ~notyping:false p

let make_expect_test name path f expected =
  let test got expected () =
    Alcotest.(check string) "same string" got expected
  in
  (name, `Quick, test (f (path ^ name) ()) expected)

let make_ok_test name path f =
  let test got () =
    Alcotest.(check bool) "ending with success" true (Result.is_ok got)
  in
  (name, `Quick, test (f (path ^ name) ()))

let run_dir test_f directory =
  Stdlib.Sys.readdir directory
  |> Array.to_list
  |> List.filter ~f:(fun f ->
       not @@ Stdlib.Sys.is_directory (Stdlib.Filename.concat directory f) )
  |> List.map ~f:(fun x -> make_ok_test x directory test_f)

let lsc_test_suite () =
  let path = "./lsc/" in
  [ make_expect_test "empty.stellar" path lsc "{}"
  ; make_expect_test "basic.stellar" path lsc "a."
  ; make_expect_test "prolog.stellar" path lsc "s(s(s(s(0))))."
  ]

let () =
  Alcotest.run "Stellogen Test Suite"
    [ ("LSC test suite", lsc_test_suite ())
    ; ("Stellogen examples", run_dir sgen "../examples/")
    ; ("Stellogen exercises solutions", run_dir sgen "../exercises/solutions/")
    ; ("Stellogen syntax", run_dir sgen "./syntax/")
    ; ("Stellogen behavior", run_dir sgen "./behavior/")
    ]
