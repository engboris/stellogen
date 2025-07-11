open Base
open Lsc_ast
open Lsc_ast.StellarRays

let string_of_polarity = function Pos -> "+" | Neg -> "-" | Null -> ""

let string_of_polsym (p, f) = string_of_polarity p ^ f

let string_of_var (x, i) =
  match i with None -> x | Some i' -> x ^ Int.to_string i'

let rec string_of_ray = function
  | Var xi -> string_of_var xi
  | Func (pf, []) -> string_of_polsym pf
  | Func (pf, ts) ->
    Printf.sprintf "(%s %s)" (string_of_polsym pf)
      (List.map ~f:string_of_ray ts |> String.concat ~sep:" ")

let string_of_subst sub =
  Printf.sprintf "{%s}"
    (List.fold sub ~init:"" ~f:(fun _ (x, r) ->
       string_of_var x ^ "->" ^ string_of_ray r ) )

let string_of_ban = function
  | Ineq (b1, b2) ->
    Printf.sprintf "(!= %s %s)" (string_of_ray b1) (string_of_ray b2)
  | Incomp (b1, b2) ->
    Printf.sprintf "(slice %s %s)" (string_of_ray b1) (string_of_ray b2)

let string_of_star s =
  match s.content with
  | [] -> "[]"
  | _ ->
    Printf.sprintf "[%s%s]"
      (List.map ~f:string_of_ray s.content |> String.concat ~sep:" ")
      ( if List.is_empty s.bans then ""
        else
          Printf.sprintf " || %s"
            (List.map ~f:string_of_ban s.bans |> String.concat ~sep:" ") )

let string_of_constellation = function
  | [] -> "{}"
  | [ x ] -> begin
    match x with
    | { content = [ x ]; bans = _ } -> Printf.sprintf "%s" (string_of_ray x)
    | _ -> Printf.sprintf "%s" (string_of_star x)
  end
  | h :: t ->
    let string_h = "{ " ^ string_of_star h ^ " " in
    List.fold_left t
      ~init:(List.length t, string_h, String.length string_h)
      ~f:(fun (i, acc, size) s ->
        let string_s = string_of_star s in
        let new_size = size + String.length string_s in
        if i = 1 then (0, acc ^ string_s, 0)
        else if new_size < 80 then (i - 1, acc ^ string_s ^ " ", new_size)
        else (i - 1, acc ^ string_s ^ "...\n", 0) )
    |> fun (_, x, _) ->
    x |> fun x -> String.append x " }"
