open Base

type ident = string

type 'a loc =
  { content : 'a
  ; loc : string
  }

type expr =
  | Var of ident
  | Fun of (ident loc * expr loc)
  | App of (expr loc * expr loc)

type env = (ident * expr) list

type declaration =
  | Let of ident * expr loc
  | Print of ident

type program = declaration list

let rec to_string e =
  match e.content with
  | Var x -> x
  | Fun (x, t) -> Printf.sprintf "fun %s -> %s" x.content (to_string t)
  | App (t1, t2) -> Printf.sprintf "(%s %s)" (to_string t1) (to_string t2)

let rec free_vars e =
  match e.content with
  | Var x -> [ x ]
  | Fun (x, t) ->
    List.filter (free_vars t) ~f:(fun y -> not @@ equal_string x.content y)
  | App (t1, t2) -> free_vars t1 @ free_vars t2

let rec is_linear e =
  match e.content with
  | Var _ -> true
  | Fun (x, t) ->
    is_linear t
    && List.length
         (List.filter (free_vars t) ~f:(fun y -> equal_string x.content y))
       = 1
  | App (t1, t2) -> is_linear t1 && is_linear t2
