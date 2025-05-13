open Base

let rec loop env =
  let lexbuf = Sedlexing.Utf8.from_channel Stdlib.stdin in
  let lexer = Sedlexing.with_tokenizer Stellogen.Sgen_lexer.read lexbuf in
  let parser =
    MenhirLib.Convert.Simplified.traditional2revised
      Stellogen.Sgen_parser.declaration
  in
  let d = parser lexer in
  let wrapped_env =
    Stellogen.Sgen_eval.eval_decl ~typecheckonly:false ~notyping:false env d
  in
  match wrapped_env with
  | Ok env' -> loop env'
  | Error e ->
    let ( let* ) x f = Result.bind x ~f in
    let* pp = Stellogen.Sgen_eval.pp_err ~notyping:false e in
    Stdlib.output_string Stdlib.stderr pp;
    Stdlib.flush Stdlib.stderr;
    loop env

let () =
  let _ = loop Stellogen.Sgen_ast.initial_env in
  ()
