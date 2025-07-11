open Base

let sgen filename () =
  let lexbuf = Sedlexing.Utf8.from_channel (Stdlib.open_in filename) in
  let expr = Stellogen.Sgen_parsing.parse_with_error filename lexbuf in
  let preprocessed = Stellogen.Expr.preprocess expr in
  let p = Stellogen.Expr.program_of_expr preprocessed in
  Stellogen.Sgen_eval.eval_program p

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

let () =
  Alcotest.run "Stellogen Test Suite"
    [ ("Stellogen examples", run_dir sgen "../examples/")
    ; (* ; ("Stellogen exercises solutions", run_dir sgen "../exercises/solutions/")
    ; *)
      ("Stellogen syntax", run_dir sgen "./subjects/")
    ]
