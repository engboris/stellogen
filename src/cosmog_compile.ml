(** Compiler from linear lambda calculus to Stellogen

    This module compiles a mini-ML language with linear lambda calculus
    to Stellogen's interaction net representation. *)

open Base

(** {1 Helper functions for building Stellogen expressions} *)

(** Create a positive polarity symbol *)
let pos x = Expr.Raw.Symbol ("+" ^ x)

(** Create a negative polarity symbol *)
let neg x = Expr.Raw.Symbol ("-" ^ x)

(** Add "_out" suffix to a location identifier *)
let out x = x ^ "_out"

(** Create a function application node *)
let func es = Expr.Raw.List es

(** Create a variable *)
let var x = Expr.Raw.Var x

(** Create a star (constellation) *)
let star es = Expr.Raw.Cons es

(** Create an interact expression *)
let interact e = Expr.Raw.List [ Expr.Raw.Symbol "interact"; e ]

(** Create a group expression *)
let group es = Expr.Raw.Group es

(** Create a definition *)
let def x t = Expr.Raw.List [ Expr.Raw.Symbol ":="; Expr.Raw.Symbol x; t ]

(** Create a show expression *)
let show x = Expr.Raw.List [ Expr.Raw.Symbol "show"; x ]

(** Create an identifier call *)
let id x = Expr.Raw.Call (Expr.Raw.Symbol x)

(** Add a symbol to the front of a constellation *)
let add_to_star s = function
  | Expr.Raw.Cons es -> Expr.Raw.Cons (Expr.Raw.Symbol s :: es)
  | e -> Expr.Raw.Cons [ Expr.Raw.Symbol s; e ]

(** Inject left/right labels into a binary constellation for lambda abstraction *)
let inject_lr expr =
  match expr with
  | Expr.Raw.Cons [ Expr.Raw.List [ h1; a1 ]; Expr.Raw.List [ h2; a2 ] ] ->
    Expr.Raw.Cons
      [ Expr.Raw.List [ h1; add_to_star "l" a1 ]
      ; Expr.Raw.List [ h2; add_to_star "r" a2 ]
      ]
  | _ ->
    failwith
      (Printf.sprintf
         "Internal compiler error: inject_lr expects a binary constellation, got: %s"
         (Expr.Raw.to_string expr))

(** {1 Compilation functions} *)

(** Compile a linear lambda expression to Stellogen interaction nets

    @param e The lambda expression to compile (must be linear)
    @raise Failure if the expression is not linear *)
let rec compile_expr e =
  (* Verify linearity constraint *)
  if not (Lambda.is_linear e) then
    failwith
      (Printf.sprintf
         "Compilation error: term '%s' is not linear.\n\
          Linear lambda calculus requires each variable to be used exactly once."
         (Lambda.to_string e));

  match e.content with
  | Lambda.Var _ ->
    (* Variable: wire connecting input to output *)
    [ star [ func [ pos e.loc; var "X" ]; func [ pos (out e.loc); var "X" ] ] ]

  | Lambda.Fun (_x, _t) ->
    (* Lambda abstraction: labeled wire for left/right distinction *)
    [ star [ func [ pos e.loc; var "X" ]; func [ pos (out e.loc); var "X" ] ]
      |> inject_lr
    ]

  | Lambda.App (t1, t2) ->
    (* Application: connect outputs of subterms and create final output *)
    let cuts =
      star
        [ func [ neg (out t1.loc); var "X" ]
        ; func [ neg (out t2.loc); var "X" ]
        ]
    in
    let output = star [ func [ pos (out e.loc); var "X" ] ] in
    [ cuts; output ] @ compile_expr t1 @ compile_expr t2

(** Compile a declaration (let binding or print statement) *)
let compile_decl = function
  | Lambda.Let (x, t) -> [ def x (group (compile_expr t)) ]
  | Lambda.Print x -> [ show (interact (id x)) ]

(** Compile a complete program

    @param program The lambda calculus program to compile
    @return A list of Stellogen expressions *)
let compile : Lambda.program -> Expr.Raw.t list =
  fun program -> List.concat_map ~f:compile_decl program
