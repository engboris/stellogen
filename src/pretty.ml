open Base

let surround first last s = first ^ s ^ last

let rec string_of_list printer sep = function
  | [] -> ""
  | [ x ] -> printer x
  | h :: t -> printer h ^ sep ^ string_of_list printer sep t
