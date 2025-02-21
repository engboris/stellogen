open Base
open Lsc_ast
open Common.Format_exn
open Common.Pretty

type ident = string

type idvar = string * int option

type idfunc = polarity * string

type ray_prefix = StellarRays.fmark * idfunc

type type_declaration =
  | TDef of ident * ident list * ident option
  | TExp of ident * galaxy_expr

and galaxy =
  | Const of marked_constellation
  | Galaxy of galaxy_declaration list
  | Interface of type_declaration list

and galaxy_declaration =
  | GTypeDef of type_declaration
  | GLabelDef of ident * galaxy_expr

and galaxy_expr =
  | Raw of galaxy
  | Access of galaxy_expr * ident
  | Id of ident
  | Exec of galaxy_expr
  | Union of galaxy_expr * galaxy_expr
  | Subst of galaxy_expr * substitution
  | Focus of galaxy_expr
  | Process of galaxy_expr list
  | Token of ident

and substitution =
  | Extend of ray_prefix
  | Reduce of ray_prefix
  | SVar of ident * StellarRays.term
  | SFunc of (StellarRays.fmark * idfunc) * (StellarRays.fmark * idfunc)
  | SGal of ident * galaxy_expr

let reserved_words = [ "clean"; "kill" ]

let is_reserved = List.mem reserved_words ~equal:equal_string

exception IllFormedChecker

exception ExpectedGalaxy

exception ReservedWord of ident

exception UnknownField of ident

exception UnknownID of ident

exception EmptyProcess

exception TestFailed of ident * ident * ident * galaxy * galaxy

type env =
  { objs : (ident * galaxy_expr) list
  ; types : (ident * (ident list * ident option)) list
  }

let expect (g : galaxy_expr) : galaxy_expr =
  Raw (Galaxy [ GLabelDef ("expect", g) ])

let initial_env =
  { objs = [ ("^empty", Raw (Const [])) ]
  ; types = [ ("^empty", ([ "^empty" ], None)) ]
  }

type declaration =
  | Def of ident * galaxy_expr
  | Show of galaxy_expr
  | ShowExec of galaxy_expr
  | Trace of galaxy_expr
  | Run of galaxy_expr
  | TypeDef of type_declaration

type program = declaration list

let add_obj env x e = List.Assoc.add ~equal:equal_string env.objs x e

let get_obj env x =
  try List.Assoc.find_exn ~equal:equal_string env.objs x
  with Not_found_s _ -> raise (UnknownID x)

let add_type env x e = List.Assoc.add ~equal:equal_string env.types x e

let get_type env x =
  try List.Assoc.find_exn ~equal:equal_string env.types x
  with Not_found_s _ -> raise (UnknownID x)

let rec map_galaxy env ~f = function
  | Const mcs -> Const (f mcs)
  | Interface i -> Interface i
  | Galaxy g ->
    Galaxy
      (List.map g ~f:(function
        | GTypeDef tdef -> GTypeDef tdef
        | GLabelDef (k, v) -> GLabelDef (k, map_galaxy_expr env ~f v) ))

and map_galaxy_expr env ~f e =
  match e with
  | Raw g -> Raw (map_galaxy env ~f g)
  | Access (e, x) -> Access (map_galaxy_expr env ~f e, x)
  | Id x when is_reserved x -> Id x
  | Id x -> get_obj env x |> map_galaxy_expr env ~f
  | Exec e -> Exec (map_galaxy_expr env ~f e)
  | Union (e, e') -> Union (map_galaxy_expr env ~f e, map_galaxy_expr env ~f e')
  | Subst (e, Extend pf) -> Subst (map_galaxy_expr env ~f e, Extend pf)
  | Subst (e, Reduce pf) -> Subst (map_galaxy_expr env ~f e, Reduce pf)
  | Focus e -> Focus (map_galaxy_expr env ~f e)
  | Subst (e, SVar (x, r)) -> Subst (map_galaxy_expr env ~f e, SVar (x, r))
  | Subst (e, SFunc (pf, pf')) ->
    Subst (map_galaxy_expr env ~f e, SFunc (pf, pf'))
  | Subst (e', SGal (x, e)) ->
    Subst (map_galaxy_expr env ~f e', SGal (x, map_galaxy_expr env ~f e))
  | Process gs -> Process (List.map ~f:(map_galaxy_expr env ~f) gs)
  | Token _ -> e

let rec fill_token env (_from : ident) _to e =
  match e with
  | Id x when is_reserved x -> Id x
  | Id x -> get_obj env x |> fill_token env _from _to
  | Access (g, x) -> Access (fill_token env _from _to g, x)
  | Exec e -> Exec (fill_token env _from _to e)
  | Union (e, e') ->
    Union (fill_token env _from _to e, fill_token env _from _to e')
  | Focus e -> Focus (fill_token env _from _to e)
  | Subst (e, subst) -> Subst (fill_token env _from _to e, subst)
  | Process gs -> Process (List.map ~f:(fill_token env _from _to) gs)
  | Token x when equal_string x _from -> _to
  | Raw _ | Token _ -> e

let subst_vars env _from _to =
  map_galaxy_expr env ~f:(subst_all_vars [ (_from, _to) ])

let subst_funcs env _from _to =
  map_galaxy_expr env ~f:(subst_all_funcs [ (_from, _to) ])

let group_galaxy =
  List.fold_left ~init:([], []) ~f:(function types, fields ->
    (function
    | GTypeDef d -> (d :: types, fields)
    | GLabelDef (x, g') -> (types, (x, g') :: fields) ) )

let rec typecheck_galaxy env g : (unit, Lsc_ast.err_effect) Result.t =
  let types, fields = group_galaxy g in
  List.map types ~f:(function
    | TExp (x, g) ->
      let checker = expect g in
      let new_env = { types = env.types; objs = fields @ env.objs } in
      typecheck new_env x "^empty" checker
    | TDef (x, ts, ck) ->
      let checker =
        match ck with None -> default_checker | Some xck -> get_obj env xck
      in
      let new_env = { types = env.types; objs = fields @ env.objs } in
      List.map ts ~f:(fun t -> typecheck new_env x t checker) |> Result.all_unit )
  |> Result.all_unit

and eval_galaxy_expr (env : env) :
  galaxy_expr -> (galaxy, Lsc_ast.err_effect) Result.t = function
  | Raw (Galaxy g) ->
    let* _ = typecheck_galaxy env g in
    Ok (Galaxy g)
  | Raw (Const mcs) -> Ok (Const mcs)
  | Raw (Interface _) -> Ok (Interface [])
  | Token _ -> Ok (Const [])
  | Access (e, x) -> begin
    match eval_galaxy_expr env e with
    | Ok (Const _) -> raise (UnknownField x)
    | Ok (Interface _) -> raise (UnknownField x)
    | Ok (Galaxy g) -> (
      let _, fields = group_galaxy g in
      try
        fields |> fun g ->
        List.Assoc.find_exn ~equal:equal_string g x |> eval_galaxy_expr env
      with Not_found_s _ -> raise (UnknownField x) )
    | Error e -> Error e
  end
  | Id x -> begin
    try get_obj env x |> eval_galaxy_expr env
    with Sexplib0__Sexp.Not_found_s _ -> raise (UnknownID x)
  end
  | Union (e, e') ->
    let* eval_e = eval_galaxy_expr env e in
    let* eval_e' = eval_galaxy_expr env e' in
    let* mcs1 = eval_e |> galaxy_to_constellation env in
    let* mcs2 = eval_e' |> galaxy_to_constellation env in
    Ok (Const (mcs1 @ mcs2))
  | Exec e ->
    let* eval_e = eval_galaxy_expr env e in
    let* mcs = galaxy_to_constellation env eval_e in
    let* ex = exec ~showtrace:false mcs in
    Ok (Const (unmark_all ex))
  | Focus e ->
    let* eval_e = eval_galaxy_expr env e in
    let* mcs = galaxy_to_constellation env eval_e in
    Const (mcs |> remove_mark_all |> focus) |> Result.return
  | Process [] -> Ok (Const [])
  | Process (h :: t) ->
    let* eval_e = eval_galaxy_expr env h in
    let* mcs = galaxy_to_constellation env eval_e in
    let init = mcs |> remove_mark_all |> focus in
    let* res =
      List.fold_left t ~init:(Ok init) ~f:(fun acc x ->
        let* acc = acc in
        match x with
        | Id "kill" -> acc |> remove_mark_all |> kill |> focus |> Result.return
        | Id "clean" ->
          acc |> remove_mark_all |> clean |> focus |> Result.return
        | _ ->
          let origin = acc |> remove_mark_all |> focus in
          let* ev =
            eval_galaxy_expr env (Exec (Union (x, Raw (Const origin))))
          in
          galaxy_to_constellation env ev )
    in
    Const res |> Result.return
  | Subst (e, Extend pf) ->
    let* eval_e = eval_galaxy_expr env e in
    let* mcs = galaxy_to_constellation env eval_e in
    Const (List.map mcs ~f:(map_mstar ~f:(fun r -> gfunc pf [ r ])))
    |> Result.return
  | Subst (e, Reduce pf) ->
    let* eval_e = eval_galaxy_expr env e in
    let* mcs = galaxy_to_constellation env eval_e in
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
    subst_vars env (x, None) r e |> eval_galaxy_expr env
  | Subst (e, SFunc (pf1, pf2)) ->
    subst_funcs env pf1 pf2 e |> eval_galaxy_expr env
  | Subst (e, SGal (x, _to)) -> fill_token env x _to e |> eval_galaxy_expr env

and galaxy_to_constellation env :
  galaxy -> (marked_constellation, Lsc_ast.err_effect) Result.t = function
  | Const mcs -> Ok mcs
  | Interface _ -> Ok []
  | Galaxy g ->
    let _, fields = group_galaxy g in
    List.fold_left fields ~init:(Ok []) ~f:(fun acc (_, v) ->
      let* acc = acc in
      let* eval_v = eval_galaxy_expr env v in
      let* mcs = galaxy_to_constellation env eval_v in
      Ok (mcs @ acc) )

and string_of_exn e : (ident, Lsc_ast.err_effect) Result.t =
  match e with
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
    let* eval_got = galaxy_to_constellation initial_env got in
    let* eval_exp = galaxy_to_constellation initial_env expected in
    Printf.sprintf "%s: %s.\nChecking %s :: %s\n* got: %s\n* expected: %s\n"
      (red "TestFailed Error")
      ( if equal_string id "_" then "unique test of '" ^ t ^ "' failed"
        else "test '" ^ id ^ "' failed" )
      x t
      (eval_got |> List.map ~f:remove_mark |> string_of_constellation)
      (eval_exp |> List.map ~f:remove_mark |> string_of_constellation)
    |> Result.return
  | _ -> raise e

and equal_galaxy env g g' =
  let* mcs = galaxy_to_constellation env g in
  let* mcs' = galaxy_to_constellation env g' in
  equal_mconstellation mcs mcs' |> Result.return

and check_interface env x i =
  let g =
    match get_obj env x with Raw (Galaxy g) -> g | _ -> raise ExpectedGalaxy
  in
  let type_decls = List.map i ~f:(fun t -> GTypeDef t) in
  typecheck_galaxy env (type_decls @ g)

and typecheck env x t (ck : galaxy_expr) : (unit, Lsc_ast.err_effect) Result.t =
  let* gtests =
    match get_obj env t with
    | Raw (Const mcs) -> Ok [ ("_", Raw (Const mcs)) ]
    | Raw (Interface i) ->
      let* _ = check_interface env x i in
      Ok []
    | Raw (Galaxy gtests) -> group_galaxy gtests |> snd |> Result.return
    | e ->
      let* eval_e = eval_galaxy_expr env e in
      let* mcs = galaxy_to_constellation env eval_e in
      [ ("test", Raw (Const mcs)) ] |> Result.return
  in
  let testing =
    List.map gtests ~f:(fun (idtest, test) ->
      match ck with
      | Raw (Galaxy gck) ->
        Stdlib.print_string "[@@@]";
        Stdlib.flush Stdlib.stdout;
        let format =
          try
            List.Assoc.find_exn ~equal:equal_string
              (group_galaxy gck |> snd)
              "interaction"
          with Not_found_s _ -> default_interaction
        in
        ( idtest
        , Exec
            (Subst
               ( Subst (format, SGal ("test", test))
               , SGal ("tested", Exec (get_obj env x)) ) )
          |> eval_galaxy_expr env )
      | _weak73 -> raise IllFormedChecker )
  in
  let expect = Access (ck, "expect") in
  let* eval_exp = eval_galaxy_expr env expect in
  List.map testing ~f:(fun (idtest, got) ->
    let* got = got in
    let* eq = equal_galaxy env got eval_exp in
    if not eq then raise (TestFailed (x, t, idtest, got, eval_exp)) else Ok () )
  |> Result.all_unit

and default_interaction = Union (Token "tested", Token "test")

and default_expect =
  Raw (Const [ Unmarked { content = [ func "ok" [] ]; bans = [] } ])

and default_checker =
  Raw
    (Galaxy
       [ GLabelDef ("interaction", default_interaction)
       ; GLabelDef ("expect", default_expect)
       ] )

and string_of_type_declaration env = function
  | TDef (x, ts, None) ->
    Printf.sprintf "  %s :: %s.\n" x (string_of_list Fn.id "," ts)
  | TDef (x, ts, Some xck) ->
    Printf.sprintf "  %s :: %s [%s].\n" x (string_of_list Fn.id "," ts) xck
  | TExp (x, g) -> (
    match eval_galaxy_expr env g with
    | Error _ -> failwith "Error: string_of_type_declaration"
    | Ok eval_g -> Printf.sprintf "%s :=: %s" x (string_of_galaxy env eval_g) )

and string_of_galaxy_declaration env = function
  | GLabelDef (k, v) -> begin
    match eval_galaxy_expr env v with
    | Error _ -> failwith "Error: string_of_galaxy_declaration"
    | Ok eval_v -> Printf.sprintf "  %s = %s\n" k (string_of_galaxy env eval_v)
  end
  | GTypeDef decl -> string_of_type_declaration env decl

and string_of_galaxy env : galaxy -> ident = function
  | Const mcs -> mcs |> remove_mark_all |> string_of_constellation
  | Interface i ->
    let content = string_of_list (string_of_type_declaration env) "" i in
    Printf.sprintf "interface\n%send" content
  | Galaxy g ->
    Printf.sprintf "galaxy\n%send"
      (string_of_list (string_of_galaxy_declaration env) "" g)

let rec eval_decl env : declaration -> (env, Lsc_ast.err_effect) Result.t =
  function
  | Def (x, _) when is_reserved x -> raise (ReservedWord x)
  | Def (x, e) ->
    let env = { objs = add_obj env x e; types = env.types } in
    let* _ =
      List.filter env.types ~f:(fun (y, _) -> equal_string x y)
      |> List.map ~f:(fun (_, (ts, ck)) ->
           match ck with
           | None ->
             List.map ts ~f:(fun t -> typecheck env x t default_checker)
             |> Result.all_unit
           | Some xck ->
             List.map ts ~f:(fun t -> typecheck env x t (get_obj env xck))
             |> Result.all_unit )
      |> Result.all_unit
    in
    Ok env
  | Show (Id x) ->
    let e = get_obj env x in
    eval_decl env (Show e)
  | Show (Raw (Galaxy g)) ->
    Galaxy g |> string_of_galaxy env |> Stdlib.print_string;
    Stdlib.print_newline ();
    Stdlib.flush Stdlib.stdout;
    Ok env
  | Show (Raw (Interface i)) ->
    Interface i |> string_of_galaxy env |> Stdlib.print_string;
    Stdlib.print_newline ();
    Stdlib.flush Stdlib.stdout;
    Ok env
  | Show e ->
    let* eval_e = eval_galaxy_expr env e in
    let* mcs = galaxy_to_constellation env eval_e in
    List.map mcs ~f:remove_mark
    |> string_of_constellation |> Stdlib.print_string;
    Stdlib.print_newline ();
    Ok env
  | ShowExec e -> eval_decl env (Show (Exec e))
  | Trace e ->
    let* eval_e = eval_galaxy_expr env e in
    let* mcs = galaxy_to_constellation env eval_e in
    let _ = exec ~showtrace:true mcs in
    Ok env
  | Run e ->
    let _ = eval_galaxy_expr env (Exec e) in
    Ok env
  | TypeDef (TDef (x, ts, ck)) ->
    Ok { objs = env.objs; types = add_type env x (ts, ck) }
  | TypeDef (TExp (x, mcs)) ->
    Ok
      { objs = add_obj env "^expect" (expect mcs)
      ; types = add_type env x ([ "^empty" ], Some "^expect")
      }

let eval_program p =
  match
    List.fold_left
      ~f:(fun acc x ->
        let* acc = acc in
        eval_decl acc x )
      ~init:(Ok initial_env) p
  with
  | Ok _ -> ()
  | Error e ->
    Lsc_ast.string_of_err_effect e
    |> Out_channel.output_string Out_channel.stderr;
    Stdlib.exit 1
