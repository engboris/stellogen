open Base
open Cmdliner
open Stellogen

let create_start_pos filename =
  { Lexing.pos_fname = filename; pos_lnum = 1; pos_bol = 0; pos_cnum = 0 }

let parse input_file =
  let lexbuf = Sedlexing.Utf8.from_channel (Stdlib.open_in input_file) in
  Sedlexing.set_position lexbuf (create_start_pos input_file);
  Sgen_parsing.parse_with_error input_file lexbuf

let run input_file =
  let expr = parse input_file in
  let preprocessed = Expr.preprocess expr in
  match Expr.program_of_expr preprocessed with
  | Ok program ->
    let (_ : (Sgen_ast.env, Sgen_ast.err) Result.t) =
      Sgen_eval.eval_program program
    in
    ()
  | Error expr_error -> (
    match Sgen_eval.pp_err (ExprError (expr_error, None)) with
    | Ok error_msg -> Stdlib.Printf.eprintf "%s" error_msg
    | Error _ -> () )

let run_with_timeout input_file timeout =
  let pid = Unix.fork () in
  if pid = 0 then (
    (* Child process *)
    try
      run input_file;
      Stdlib.exit 0
    with e ->
      Stdlib.Printf.eprintf "Error: %s\n" (Exn.to_string e);
      Stdlib.exit 1 )
  else
    (* Parent process *)
    let start_time = Unix.time () in
    let rec wait_with_timeout () =
      let elapsed = Unix.time () -. start_time in
      if Float.(elapsed > timeout) then (
        (* Timeout - kill child process *)
        Unix.kill pid Stdlib.Sys.sigkill;
        let _ = Unix.waitpid [] pid in
        Stdlib.Printf.eprintf
          "\n[Timeout: execution exceeded %.1fs - killed]\n%!" timeout;
        false )
      else
        match Unix.waitpid [ Unix.WNOHANG ] pid with
        | 0, _ ->
          (* Still running *)
          Unix.sleepf 0.1;
          wait_with_timeout ()
        | _, status -> (
          match status with
          | Unix.WEXITED 0 -> true
          | Unix.WEXITED code ->
            Stdlib.Printf.eprintf "[Exited with code %d]\n%!" code;
            false
          | Unix.WSIGNALED signal ->
            Stdlib.Printf.eprintf "[Killed by signal %d]\n%!" signal;
            false
          | Unix.WSTOPPED signal ->
            Stdlib.Printf.eprintf "[Stopped by signal %d]\n%!" signal;
            false )
    in
    wait_with_timeout ()

let watch input_file timeout =
  let abs_path =
    if Stdlib.Filename.is_relative input_file then
      Stdlib.Filename.concat (Stdlib.Sys.getcwd ()) input_file
    else input_file
  in

  Stdlib.Printf.printf "Watching %s (timeout: %.1fs)\n%!" abs_path timeout;
  Stdlib.Printf.printf "Press Ctrl+C to stop.\n\n%!";

  (* Initial run *)
  let _ = run_with_timeout input_file timeout in

  (* Polling approach - check file modification time *)
  let rec poll_loop last_mtime attempt =
    Unix.sleepf 0.5;
    try
      let stat = Unix.stat abs_path in
      let current_mtime = stat.Unix.st_mtime in
      if Float.(current_mtime > last_mtime) then (
        Stdlib.Printf.printf
          "\n\n--- File changed, re-running (attempt #%d) ---\n%!" attempt;
        let _ = run_with_timeout input_file timeout in
        poll_loop current_mtime (attempt + 1) )
      else poll_loop last_mtime attempt
    with Unix.Unix_error _ ->
      Stdlib.Printf.eprintf "Error accessing file, retrying...\n%!";
      Unix.sleepf 1.0;
      poll_loop last_mtime attempt
  in

  let initial_stat = Unix.stat abs_path in
  poll_loop initial_stat.Unix.st_mtime 2

let preprocess_only input_file =
  let expr = parse input_file in
  let preprocessed = Expr.preprocess expr in
  preprocessed |> List.map ~f:(fun e -> Expr.to_string e.Expr.content) |> String.concat ~sep:"\n"
  |> Stdlib.print_endline

let input_file_arg =
  let doc = "Input file to process." in
  Arg.(required & pos 0 (some string) None & info [] ~docv:"FILENAME" ~doc)

let wrap f input_file =
  try Ok (f input_file) with e -> Error (`Msg (Exn.to_string e))

let run_cmd =
  let doc = "Run the Stellogen program" in
  let term = Term.(const (wrap run) $ input_file_arg |> term_result) in
  Cmd.v (Cmd.info "run" ~doc) term

let preprocess_cmd =
  let doc = "Show the preprocessed code" in
  let term =
    Term.(const (wrap preprocess_only) $ input_file_arg |> term_result)
  in
  Cmd.v (Cmd.info "preprocess" ~doc) term

let timeout_arg =
  let doc = "Timeout in seconds for each execution (default: 5.0)" in
  Arg.(value & opt float 5.0 & info [ "t"; "timeout" ] ~docv:"SECONDS" ~doc)

let watch_cmd =
  let doc = "Watch and re-run the Stellogen program on file changes" in
  let term =
    Term.(
      const (fun input timeout -> wrap (fun i -> watch i timeout) input)
      $ input_file_arg $ timeout_arg |> term_result )
  in
  Cmd.v (Cmd.info "watch" ~doc) term

let default_cmd =
  let doc = "Stellogen: code generator and evaluator" in
  Cmd.group (Cmd.info "sgen" ~doc) [ run_cmd; preprocess_cmd; watch_cmd ]

let () = Stdlib.exit (Cmd.eval default_cmd)
