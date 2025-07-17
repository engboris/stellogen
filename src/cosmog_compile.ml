open Base

let pos x = Expr.Raw.Symbol ("+" ^ x)

let neg x = Expr.Raw.Symbol ("-" ^ x)

let out x = x ^ "_out"

let func es = Expr.Raw.List es

let var x = Expr.Raw.Var x

let star es = Expr.Raw.Cons es

let interact e = Expr.Raw.List [ Expr.Raw.Symbol "interact"; e ]

let group es = Expr.Raw.Group es

let def x t = Expr.Raw.List [ Expr.Raw.Symbol ":="; Expr.Raw.Symbol x; t ]

let show x = Expr.Raw.List [ Expr.Raw.Symbol "show"; x ]

let id x = Expr.Raw.Call (Expr.Raw.Symbol x)

let add s = function
  | Expr.Raw.Cons es -> Expr.Raw.Cons (Expr.Raw.Symbol s :: es)
  | e -> Expr.Raw.Cons [ Expr.Raw.Symbol s; e ]

let inject_lr = function
  | Expr.Raw.Cons [ Expr.Raw.List [ h1; a1 ]; Expr.Raw.List [ h2; a2 ] ] ->
    Expr.Raw.Cons
      [ Expr.Raw.List [ h1; add "l" a1 ]; Expr.Raw.List [ h2; add "r" a2 ] ]
  | _ -> failwith "Compiler error: could not apply inject_lr"

(* FIXME *)
let rec compile_expr e =
  if not @@ Lambda.is_linear e then
    failwith
      (Printf.sprintf "Compiler error: term '%s' is not linear."
         (Lambda.to_string e) );
  match e.content with
  | Lambda.Var _ ->
    [ star [ func [ pos e.loc; var "X" ]; func [ pos (out e.loc); var "X" ] ] ]
  | Lambda.Fun (_x, _t) ->
    [ star [ func [ pos e.loc; var "X" ]; func [ pos (out e.loc); var "X" ] ]
      |> inject_lr
    ]
  | Lambda.App (t1, t2) ->
    let cuts =
      star
        [ func [ neg (t1.loc ^ "_out"); var "X" ]
        ; func [ neg (t2.loc ^ "_out"); var "X" ]
        ]
    in
    let out = star [ func [ pos (e.loc ^ "_out"); var "X" ] ] in
    [ cuts; out ] @ compile_expr t1 @ compile_expr t2

let compile_decl = function
  | Lambda.Let (x, t) -> [ def x (group (compile_expr t)) ]
  | Lambda.Print x -> [ show (interact (id x)) ]

let compile : Lambda.program -> Expr.Raw.t list =
 fun e -> List.map ~f:compile_decl e |> List.concat
