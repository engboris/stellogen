open Base

let rec loop env =
  let lexbuf = Lexing.from_channel Stdlib.stdin in
  let d = Stellogen.Sgen_parser.declaration Stellogen.Sgen_lexer.read lexbuf in
  let wrapped_env =
    Stellogen.Sgen_eval.eval_decl ~typecheckonly:false ~notyping:false env d
  in
  match wrapped_env with
  | Ok env' -> loop env'
  | Error e ->
    let ( let* ) x f = Result.bind x ~f in
    let* pp = Stellogen.Sgen_eval.pp_err ~notyping:false e in
    Stdlib.output_string Stdlib.stderr pp;
    Error e

let () =
  let _ = loop Stellogen.Sgen_ast.initial_env in
  ()
