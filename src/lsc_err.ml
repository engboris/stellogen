open Base

let red text = "\x1b[31m" ^ text ^ "\x1b[0m"

type err_effect =
  | TooFewArgs of string
  | TooManyArgs of string
  | UnknownEffect of string

let pp_err_effect = function
  | TooFewArgs x when equal_string x "print" ->
    Printf.sprintf "%s: effect '%s' expects 1 arguments.\n"
      (red "Missing argument") x
  | TooFewArgs x ->
    Printf.sprintf "%s: for effect '%s'.\n" (red "Missing argument") x
  | TooManyArgs x when equal_string x "print" ->
    Printf.sprintf "%s: effect '%s' expects 1 arguments.\n"
      (red "Too many arguments") x
  | TooManyArgs x ->
    Printf.sprintf "%s: for effect '%s'.\n" (red "Too many arguments") x
  | UnknownEffect x -> Printf.sprintf "%s '%s'.\n" (red "UnknownEffect") x
