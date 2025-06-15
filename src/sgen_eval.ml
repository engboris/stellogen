open Base
open Lsc_ast
open Lsc_err
open Sgen_ast
open Sgen_err
open Pretty
open Out_channel

let ( let* ) x f = Result.bind x ~f

let add_obj env x e = List.Assoc.add ~equal:equal_ray env.objs x e

let get_obj env x = List.Assoc.find ~equal:equal_ray env.objs x

let add_type env x e = List.Assoc.add ~equal:equal_ray env.types x e

let get_type env x = List.Assoc.find ~equal:equal_ray env.types x

let rec map_galaxy env ~f : galaxy -> (galaxy, err) Result.t = function
  | Const mcs -> Const (f mcs) |> Result.return
  | Interface i -> Interface i |> Result.return
  | Galaxy g ->
    let* g' =
      List.map g ~f:(function
        | GTypeDef tdef -> GTypeDef tdef |> Result.return
        | GLabelDef (k, v) ->
          let* map_v = map_galaxy_expr env ~f v in
          GLabelDef (k, map_v) |> Result.return )
      |> Result.all
    in
    Galaxy g' |> Result.return

and map_galaxy_expr env ~f : galaxy_expr -> (galaxy_expr, err) Result.t =
  function
  | Raw g ->
    let* map_g = map_galaxy env ~f g in
    Raw map_g |> Result.return
  | Access (e, x) ->
    let* map_e = map_galaxy_expr env ~f e in
    Access (map_e, x) |> Result.return
  | Id x when is_reserved x -> Ok (Id x)
  | Id x -> begin
    match get_obj env x with
    | None -> Error (UnknownID (string_of_ray x))
    | Some g -> map_galaxy_expr env ~f g
  end
  | Exec e ->
    let* map_e = map_galaxy_expr env ~f e in
    Exec map_e |> Result.return
  | Kill e ->
    let* map_e = map_galaxy_expr env ~f e in
    Kill map_e |> Result.return
  | Clean e ->
    let* map_e = map_galaxy_expr env ~f e in
    Clean map_e |> Result.return
  | LinExec e ->
    let* map_e = map_galaxy_expr env ~f e in
    LinExec map_e |> Result.return
  | Union es ->
    let* map_es = List.map ~f:(map_galaxy_expr env ~f) es |> Result.all in
    Union map_es |> Result.return
  | Subst (e, Extend pf) ->
    let* map_e = map_galaxy_expr env ~f e in
    Subst (map_e, Extend pf) |> Result.return
  | Subst (e, Reduce pf) ->
    let* map_e = map_galaxy_expr env ~f e in
    Subst (map_e, Reduce pf) |> Result.return
  | Focus e ->
    let* map_e = map_galaxy_expr env ~f e in
    Focus map_e |> Result.return
  | Subst (e, SVar (x, r)) ->
    let* map_e = map_galaxy_expr env ~f e in
    Subst (map_e, SVar (x, r)) |> Result.return
  | Subst (e, SFunc (pf, pf')) ->
    let* map_e = map_galaxy_expr env ~f e in
    Subst (map_e, SFunc (pf, pf')) |> Result.return
  | Subst (e', SGal (x, e)) ->
    let* map_e = map_galaxy_expr env ~f e in
    let* map_e' = map_galaxy_expr env ~f e' in
    Subst (map_e', SGal (x, map_e)) |> Result.return
  | Process gs ->
    let* procs = List.map ~f:(map_galaxy_expr env ~f) gs |> Result.all in
    Process procs |> Result.return

let rec replace_id env (_from : ident) (_to : galaxy_expr) e :
  (galaxy_expr, err) Result.t =
  match e with
  | Id x when is_reserved x -> Ok (Id x)
  | Id x when equal_ray x _from -> Ok _to
  | Access (g, x) ->
    let* g' = replace_id env _from _to g in
    Access (g', x) |> Result.return
  | Exec e ->
    let* g = replace_id env _from _to e in
    Exec g |> Result.return
  | Kill e ->
    let* g = replace_id env _from _to e in
    Kill g |> Result.return
  | Clean e ->
    let* g = replace_id env _from _to e in
    Clean g |> Result.return
  | LinExec e ->
    let* g = replace_id env _from _to e in
    LinExec g |> Result.return
  | Union es ->
    let* gs = List.map ~f:(replace_id env _from _to) es |> Result.all in
    Union gs |> Result.return
  | Focus e ->
    let* g = replace_id env _from _to e in
    Focus g |> Result.return
  | Subst (e, subst) ->
    let* g = replace_id env _from _to e in
    Subst (g, subst) |> Result.return
  | Process gs ->
    let* procs = List.map ~f:(replace_id env _from _to) gs |> Result.all in
    Process procs |> Result.return
  | Raw _ | Id _ -> e |> Result.return

let subst_vars env _from _to =
  map_galaxy_expr env ~f:(subst_all_vars [ (_from, _to) ])

let subst_funcs env _from _to =
  map_galaxy_expr env ~f:(subst_all_funcs [ (_from, _to) ])

let group_galaxy :
     galaxy_declaration list
  -> type_declaration list * (StellarRays.term * galaxy_expr) list =
  List.fold_left ~init:([], []) ~f:(function types, fields ->
    (function
    | GTypeDef d -> (d :: types, fields)
    | GLabelDef (x, g') -> (types, (x, g') :: fields) ) )

let rec typecheck_galaxy ~notyping env (g : galaxy_declaration list) :
  (unit, err) Result.t =
  let types, fields = group_galaxy g in
  List.map types ~f:(function
    | TExp (x, g) ->
      let checker = expect g in
      let new_env = { types = env.types; objs = fields @ env.objs } in
      typecheck ~notyping new_env x (const "^empty") checker
    | TDef (x, ts) ->
      List.map ts ~f:(fun (t, ck) ->
        let* checker =
          match ck with
          | None -> Ok default_checker
          | Some xck -> begin
            match get_obj env xck with
            | None -> Error (UnknownID (string_of_ray xck))
            | Some g -> Ok g
          end
        in
        let new_env = { types = env.types; objs = fields @ env.objs } in
        typecheck ~notyping new_env x t checker )
      |> Result.all_unit )
  |> Result.all_unit

and pp_err ~notyping e : (string, err) Result.t =
  match e with
  | IllFormedChecker -> "Ill-formed checker.\n" |> Result.return
  | ExpectedGalaxy -> "Expected galaxy.\n" |> Result.return
  | ReservedWord x ->
    Printf.sprintf "%s: identifier '%s' is reserved.\n"
      (red "ReservedWord Error") x
    |> Result.return
  | UnknownField x ->
    Printf.sprintf "%s: field '%s' not found.\n" (red "UnknownField Error") x
    |> Result.return
  | UnknownID x ->
    Printf.sprintf "%s: identifier '%s' not found.\n" (red "UnknownID Error") x
    |> Result.return
  | TestFailed (x, t, id, got, expected) ->
    let* eval_got = galaxy_to_constellation ~notyping initial_env got in
    let* eval_exp = galaxy_to_constellation ~notyping initial_env expected in
    Printf.sprintf "%s: %s.\nChecking %s :: %s\n* got: %s\n* expected: %s\n"
      (red "TestFailed Error")
      ( if equal_string id "_" then "unique test of '" ^ t ^ "' failed"
        else "test '" ^ id ^ "' failed" )
      x t
      (eval_got |> List.map ~f:remove_mark |> string_of_constellation)
      (eval_exp |> List.map ~f:remove_mark |> string_of_constellation)
    |> Result.return
  | LscError e -> pp_err_effect e |> Result.return

and eval_galaxy_expr ~notyping (env : env) :
  galaxy_expr -> (galaxy, err) Result.t = function
  | Raw (Galaxy g) ->
    let* _ = if notyping then Ok () else typecheck_galaxy ~notyping env g in
    Ok (Galaxy g)
  | Raw (Const mcs) -> Ok (Const mcs)
  | Raw (Interface _) -> Ok (Interface [])
  | Access (e, x) -> begin
    match eval_galaxy_expr ~notyping env e with
    | Ok (Const _) -> Error (UnknownField (string_of_ray x))
    | Ok (Interface _) -> Error (UnknownField (string_of_ray x))
    | Ok (Galaxy g) -> (
      let _, fields = group_galaxy g in
      try
        fields |> fun g ->
        List.Assoc.find_exn ~equal:equal_ray g x
        |> eval_galaxy_expr ~notyping env
      with Not_found_s _ -> Error (UnknownField (string_of_ray x)) )
    | Error e -> Error e
  end
  | Id x -> begin
    begin
      match get_obj env x with
      | None -> Error (UnknownID (string_of_ray x))
      | Some g -> eval_galaxy_expr ~notyping env g
    end
  end
  | Union es ->
    let* eval_es =
      List.map ~f:(eval_galaxy_expr ~notyping env) es |> Result.all
    in
    let* mcs =
      eval_es
      |> List.map ~f:(galaxy_to_constellation ~notyping env)
      |> Result.all
    in
    Ok (Const (List.concat mcs))
  | Exec e ->
    let* eval_e = eval_galaxy_expr ~notyping env e in
    let* mcs = galaxy_to_constellation ~notyping env eval_e in
    begin
      match exec ~linear:false ~showtrace:false mcs with
      | Ok res -> Ok (Const (unmark_all res))
      | Error e -> Error (LscError e)
    end
  | LinExec e ->
    let* eval_e = eval_galaxy_expr ~notyping env e in
    let* mcs = galaxy_to_constellation ~notyping env eval_e in
    begin
      match exec ~linear:true ~showtrace:false mcs with
      | Ok mcs -> Ok (Const (unmark_all mcs))
      | Error e -> Error (LscError e)
    end
  | Focus e ->
    let* eval_e = eval_galaxy_expr ~notyping env e in
    let* mcs = galaxy_to_constellation ~notyping env eval_e in
    Const (mcs |> remove_mark_all |> focus) |> Result.return
  | Kill e ->
    let* eval_e = eval_galaxy_expr ~notyping env e in
    let* mcs = galaxy_to_constellation ~notyping env eval_e in
    Const (mcs |> remove_mark_all |> kill |> focus) |> Result.return
  | Clean e ->
    let* eval_e = eval_galaxy_expr ~notyping env e in
    let* mcs = galaxy_to_constellation ~notyping env eval_e in
    Const (mcs |> remove_mark_all |> clean |> focus) |> Result.return
  | Process [] -> Ok (Const [])
  | Process (h :: t) ->
    let* eval_e = eval_galaxy_expr ~notyping env h in
    let* mcs = galaxy_to_constellation ~notyping env eval_e in
    let init = mcs |> remove_mark_all |> focus in
    let* res =
      List.fold_left t ~init:(Ok init) ~f:(fun acc x ->
        let* acc = acc in
        match x with
        | Id (Func ((Muted, (Null, "kill")), [])) ->
          acc |> remove_mark_all |> kill |> focus |> Result.return
        | Id (Func ((Muted, (Null, "clean")), [])) ->
          acc |> remove_mark_all |> clean |> focus |> Result.return
        | _ ->
          let origin = acc |> remove_mark_all |> focus in
          let* ev =
            eval_galaxy_expr ~notyping env
              (Focus (Exec (Union [ x; Raw (Const origin) ])))
          in
          galaxy_to_constellation ~notyping env ev )
    in
    Const res |> Result.return
  | Subst (e, Extend pf) ->
    let* eval_e = eval_galaxy_expr ~notyping env e in
    let* mcs = galaxy_to_constellation ~notyping env eval_e in
    Const (List.map mcs ~f:(map_mstar ~f:(fun r -> gfunc pf [ r ])))
    |> Result.return
  | Subst (e, Reduce pf) ->
    let* eval_e = eval_galaxy_expr ~notyping env e in
    let* mcs = galaxy_to_constellation ~notyping env eval_e in
    Const
      (List.map mcs
         ~f:
           (map_mstar ~f:(fun r ->
              match r with
              | StellarRays.Func (pf', ts)
                when StellarSig.equal_idfunc (snd pf) (snd pf')
                     && List.length ts = 1 ->
                List.hd_exn ts
              | _ -> r ) ) )
    |> Result.return
  | Subst (e, SVar (x, r)) ->
    let* subst = subst_vars env (x, None) r e in
    eval_galaxy_expr ~notyping env subst
  | Subst (e, SFunc (pf1, pf2)) ->
    let* subst = subst_funcs env pf1 pf2 e in
    eval_galaxy_expr ~notyping env subst
  | Subst (e, SGal (x, _to)) ->
    let* fill = replace_id env x _to e in
    eval_galaxy_expr ~notyping env fill

and galaxy_to_constellation ~notyping env :
  galaxy -> (marked_constellation, err) Result.t = function
  | Const mcs -> Ok mcs
  | Interface _ -> Ok []
  | Galaxy g ->
    let _, fields = group_galaxy g in
    List.fold_left fields ~init:(Ok []) ~f:(fun acc (_, v) ->
      let* acc = acc in
      let* eval_v = eval_galaxy_expr ~notyping env v in
      let* mcs = galaxy_to_constellation ~notyping env eval_v in
      Ok (mcs @ acc) )

and equal_galaxy ~notyping env g g' =
  let* mcs = galaxy_to_constellation ~notyping env g in
  let* mcs' = galaxy_to_constellation ~notyping env g' in
  equal_mconstellation mcs mcs' |> Result.return

and check_interface ~notyping env x i =
  let* g =
    match get_obj env x with
    | Some (Raw (Galaxy g)) -> Ok g
    | Some _ -> Error ExpectedGalaxy
    | None -> Error (UnknownID (string_of_ray x))
  in
  let type_decls = List.map i ~f:(fun t -> GTypeDef t) in
  typecheck_galaxy ~notyping env (type_decls @ g)

and typecheck ~notyping env x (t : StellarRays.term) (ck : galaxy_expr) :
  (unit, err) Result.t =
  let* gtests : (StellarRays.term * galaxy_expr) list =
    match get_obj env t with
    | Some (Raw (Const mcs)) -> Ok [ (const "_", Raw (Const mcs)) ]
    | Some (Raw (Interface i)) ->
      let* _ = check_interface ~notyping env x i in
      Ok []
    | Some (Raw (Galaxy gtests)) -> group_galaxy gtests |> snd |> Result.return
    | Some e ->
      let* eval_e = eval_galaxy_expr ~notyping env e in
      let* mcs = galaxy_to_constellation ~notyping env eval_e in
      [ (const "test", Raw (Const mcs)) ] |> Result.return
    | None -> Error (UnknownID (string_of_ray t))
  in
  let testing =
    List.map gtests ~f:(fun (idtest, test) ->
      match ck with
      | Raw (Galaxy gck) ->
        let format =
          try
            List.Assoc.find_exn ~equal:equal_ray
              (group_galaxy gck |> snd)
              (const "interaction")
          with Not_found_s _ -> default_interaction
        in
        begin
          match get_obj env x with
          | None -> Error (UnknownID (string_of_ray x))
          | Some obj_x ->
            Ok
              ( idtest
              , Exec
                  (Subst
                     ( Subst (format, SGal (const "test", test))
                     , SGal (const "tested", obj_x) ) )
                |> eval_galaxy_expr ~notyping env )
        end
      | _ -> Error IllFormedChecker )
  in
  let expect = Access (ck, const "expect") in
  let* eval_exp = eval_galaxy_expr ~notyping env expect in
  List.map testing ~f:(function
    | Ok (idtest, got) ->
      let* got = got in
      let* eq = equal_galaxy ~notyping env got eval_exp in
      if not eq then
        Error
          (TestFailed
             ( string_of_ray x
             , string_of_ray t
             , string_of_ray idtest
             , got
             , eval_exp ) )
      else Ok ()
    | Error e -> Error e )
  |> Result.all_unit

and default_interaction =
  Union [ Focus (Id (const "tested")); Id (const "test") ]

and default_expect =
  Raw (Const [ Unmarked { content = [ func "ok" [] ]; bans = [] } ])

and default_checker : galaxy_expr =
  Raw
    (Galaxy
       [ GLabelDef (const "interaction", default_interaction)
       ; GLabelDef (const "expect", default_expect)
       ] )

and string_of_type_expr (t, ck) =
  match ck with
  | None -> Printf.sprintf "%s" (string_of_ray t)
  | Some xck -> Printf.sprintf "%s [%s]" (string_of_ray t) (string_of_ray xck)

and string_of_type_declaration ~notyping env = function
  | TDef (x, ts) ->
    let str_x = string_of_ray x in
    let str_ts = List.map ts ~f:string_of_type_expr in
    Printf.sprintf "  %s :: %s.\n" str_x (string_of_list Fn.id ";" str_ts)
  | TExp (x, g) -> (
    match eval_galaxy_expr ~notyping env g with
    | Error _ -> failwith "Error: string_of_type_declaration"
    | Ok eval_g ->
      let str_x = string_of_ray x in
      Printf.sprintf "%s :=: %s" str_x (string_of_galaxy ~notyping env eval_g) )

and string_of_galaxy_declaration ~notyping env = function
  | GLabelDef (k, v) -> begin
    match eval_galaxy_expr ~notyping env v with
    | Error _ -> failwith "Error: string_of_galaxy_declaration"
    | Ok eval_v ->
      let str_k = string_of_ray k in
      Printf.sprintf "  %s = %s\n" str_k (string_of_galaxy ~notyping env eval_v)
  end
  | GTypeDef decl -> string_of_type_declaration ~notyping env decl

and string_of_galaxy ~notyping env : galaxy -> string = function
  | Const mcs -> mcs |> remove_mark_all |> string_of_constellation
  | Interface i ->
    let content =
      string_of_list (string_of_type_declaration ~notyping env) "" i
    in
    Printf.sprintf "interface\n%send" content
  | Galaxy g ->
    Printf.sprintf "galaxy\n%send"
      (string_of_list (string_of_galaxy_declaration ~notyping env) "" g)

let rec eval_decl ~typecheckonly ~notyping env :
  declaration -> (env, err) Result.t = function
  | Def (x, _) when is_reserved x -> Error (ReservedWord (string_of_ray x))
  | Def (x, e) ->
    let env = { objs = add_obj env x e; types = env.types } in
    let* _ =
      if notyping then Ok ()
      else
        List.filter env.types ~f:(fun (y, _) -> equal_ray x y)
        |> List.map ~f:(fun (_, ts) ->
             List.map ts ~f:(fun (t, ck) ->
               match ck with
               | None -> typecheck ~notyping env x t default_checker
               | Some xck -> begin
                 match get_obj env xck with
                 | None -> Error (UnknownID (string_of_ray xck))
                 | Some obj_xck -> typecheck ~notyping env x t obj_xck
               end ) )
        |> List.concat |> Result.all_unit
    in
    Ok env
  | Show _ when typecheckonly -> Ok env
  | Show (Id x) ->
    begin match get_obj env x with
    | None -> Error (UnknownID (string_of_ray x))
    | Some g -> eval_decl ~typecheckonly ~notyping env (Show g)
    end
  | Show (Raw (Galaxy g)) ->
    Galaxy g |> string_of_galaxy ~notyping env |> Stdlib.print_string;
    Stdlib.print_newline ();
    Stdlib.flush Stdlib.stdout;
    Ok env
  | Show (Raw (Interface i)) ->
    Interface i |> string_of_galaxy ~notyping env |> Stdlib.print_string;
    Stdlib.print_newline ();
    Stdlib.flush Stdlib.stdout;
    Ok env
  | Show e ->
    let* eval_e = eval_galaxy_expr ~notyping env e in
    let* mcs = galaxy_to_constellation ~notyping env eval_e in
    List.map mcs ~f:remove_mark
    |> string_of_constellation |> Stdlib.print_string;
    Stdlib.print_newline ();
    Ok env
  | Trace _ when typecheckonly -> Ok env
  | Trace e ->
    let* eval_e = eval_galaxy_expr ~notyping env e in
    let* mcs = galaxy_to_constellation ~notyping env eval_e in
    begin
      match exec ~showtrace:true mcs with
      | Ok _ -> Ok env
      | Error e -> Error (LscError e)
    end
  | Run _ when typecheckonly -> Ok env
  | Run e ->
    let _ = eval_galaxy_expr ~notyping env (Exec e) in
    Ok env
  | TypeDef _ when notyping -> Ok env
  | TypeDef (TDef (x, ts)) -> Ok { objs = env.objs; types = add_type env x ts }
  | TypeDef (TExp (x, mcs)) ->
    Ok
      { objs = add_obj env (const "^expect") (expect mcs)
      ; types = add_type env x [ (const "^empty", Some (const "^expect")) ]
      }
  | Use path ->
    let path = List.map path ~f:string_of_ray in
    let formatted_filename = String.concat ~sep:"/" path ^ ".sg" in
    let lexbuf =
      Sedlexing.Utf8.from_channel (Stdlib.open_in formatted_filename)
    in
    let start_pos filename =
      { Lexing.pos_fname = filename; pos_lnum = 1; pos_bol = 0; pos_cnum = 0 }
    in
    Sedlexing.set_position lexbuf (start_pos formatted_filename);
    let expr = Sgen_parsing.parse_with_error lexbuf in
    let expanded = List.map ~f:Expr.expand_macro expr in
    let p = Expr.program_of_expr expanded in
    let* env = eval_program ~typecheckonly ~notyping p in
    Ok env

and eval_program ~typecheckonly ~notyping (p : program) =
  match
    List.fold_left
      ~f:(fun acc x ->
        let* acc = acc in
        eval_decl ~typecheckonly ~notyping acc x )
      ~init:(Ok initial_env) p
  with
  | Ok env -> Ok env
  | Error e ->
    let* pp = pp_err ~notyping e in
    output_string stderr pp;
    Error e
