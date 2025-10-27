open Base
open Lsc_ast
open Lsc_ast.StellarRays
open Lsc_ast.Raw

let string_of_polarity = function Pos -> "+" | Neg -> "-" | Null -> ""

let string_of_polsym (p, f) = string_of_polarity p ^ f

let string_of_var (x, index_opt) =
  match index_opt with None -> x | Some i -> x ^ Int.to_string i

let rec string_of_ray = function
  | Var var -> string_of_var var
  | Func (pf, []) -> string_of_polsym pf
  | Func (pf, terms) ->
    Printf.sprintf "(%s %s)" (string_of_polsym pf)
      (List.map terms ~f:string_of_ray |> String.concat ~sep:" ")

let string_of_subst substitution =
  substitution
  |> List.map ~f:(fun (var, ray) ->
    Printf.sprintf "%s->%s" (string_of_var var) (string_of_ray ray) )
  |> String.concat ~sep:", " |> Printf.sprintf "{%s}"

let string_of_ban = function
  | Ineq (b1, b2) ->
    Printf.sprintf "(!= %s %s)" (string_of_ray b1) (string_of_ray b2)
  | Incomp (b1, b2) ->
    Printf.sprintf "(slice %s %s)" (string_of_ray b1) (string_of_ray b2)

let string_of_star star =
  match star.content with
  | [] -> "[]"
  | content ->
    let rays_str =
      List.map content ~f:string_of_ray |> String.concat ~sep:" "
    in
    let bans_str =
      if List.is_empty star.bans then ""
      else
        Printf.sprintf " || %s"
          (List.map star.bans ~f:string_of_ban |> String.concat ~sep:" ")
    in
    Printf.sprintf "[%s%s]" rays_str bans_str

let string_of_constellation = function
  | [] -> "{}"
  | [ { content = [ single_ray ]; bans = _ } ] -> string_of_ray single_ray
  | [ single_star ] -> string_of_star single_star
  | head :: tail ->
    let max_line_length = 80 in
    let init_str = "{ " ^ string_of_star head ^ " " in
    let _, result_str, _ =
      List.fold_left tail
        ~init:(List.length tail, init_str, String.length init_str)
        ~f:(fun (remaining, acc, current_line_len) star ->
          let star_str = string_of_star star in
          let star_len = String.length star_str in
          let new_len = current_line_len + star_len in
          if remaining = 1 then (0, acc ^ star_str, 0)
          else if new_len < max_line_length then
            (remaining - 1, acc ^ star_str ^ " ", new_len)
          else (remaining - 1, acc ^ star_str ^ "...\n", 0) )
    in
    result_str ^ " }"
