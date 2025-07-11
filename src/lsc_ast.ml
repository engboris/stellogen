open Base

type polarity =
  | Pos
  | Neg
  | Null
[@@deriving eq]

module StellarSig = struct
  type idvar = string * int option

  type idfunc = polarity * string

  let string_of_idvar (s, i) =
    match i with None -> s | Some j -> s ^ Int.to_string j

  let equal_idvar x y = equal_string (string_of_idvar x) (string_of_idvar y)

  let equal_idfunc ((p, f) : idfunc) ((p', f') : idfunc) =
    equal_polarity p p' && equal_string f f'

  let compatible (p1, f1) (p2, f2) =
    let ( = ) = equal_polarity in
    equal_string f1 f2
    && ( (p1 = Pos && p2 = Neg)
       || (p1 = Neg && p2 = Pos)
       || (p1 = Null && p2 = Null) )
end

module StellarRays = Unification.Make (StellarSig)
open StellarRays

(* ---------------------------------------
   Stars and Constellations
   --------------------------------------- *)

let counter_placeholder = ref 0

let fresh_placeholder () =
  let r = !counter_placeholder in
  counter_placeholder := !counter_placeholder + 1;
  Int.to_string r

type ray = term [@@deriving eq]

type ban =
  | Ineq of ray * ray
  | Incomp of ray * ray
[@@deriving eq]

module Raw = struct
  type star =
    { content : ray list
    ; bans : ban list
    }
  [@@deriving eq]

  type constellation = star list [@@deriving eq]
end

let to_var x = Var (x, None)

let to_func (pf, ts) = Func (pf, ts)

let pos f = (Pos, f)

let neg f = (Neg, f)

let null f = (Null, f)

let gfunc c ts = Func (c, ts)

let pfunc f ts = gfunc (pos f) ts

let nfunc f ts = gfunc (neg f) ts

let func f ts = gfunc (null f) ts

let var x = Var x

let pconst f = pfunc f []

let nconst f = nfunc f []

let const f = func f []

let is_polarised r : bool =
  let aux = function Pos, _ | Neg, _ -> true | _ -> false in
  exists_func aux r

let replace_indices (i : int) : ray -> ray =
  map Fn.id (fun (x, _) -> Var (x, Some i))

let raymatcher r r' : substitution option =
  if is_polarised r && is_polarised r' then solution [ (r, r') ] else None

let fresh_var vars =
  let rec aux i =
    if not @@ List.mem vars ("X", Some i) ~equal:StellarSig.equal_idvar then
      ("X", Some i)
    else aux (i + 1)
  in
  aux 0

(* ---------------------------------------
   Operation on marked stars
   --------------------------------------- *)

module Marked = struct
  type star =
    | State of Raw.star
    | Action of Raw.star
  [@@deriving eq]

  type constellation = star list [@@deriving eq]

  let map ~f : star -> star = function
    | State s -> State { content = List.map ~f s.content; bans = s.bans }
    | Action s -> Action { content = List.map ~f s.content; bans = s.bans }

  let make_action s = Action s

  let make_state s = State s

  let make_action_all = List.map ~f:make_action

  let make_state_all = List.map ~f:make_state

  let remove : star -> Raw.star = function State s -> s | Action s -> s

  let remove_all = List.map ~f:remove

  let normalize_all x = x |> remove_all |> make_action_all
end

let subst_all_vars sub = List.map ~f:(Marked.map ~f:(subst sub))

let all_vars mcs : StellarSig.idvar list =
  List.map mcs ~f:(function Marked.State s | Marked.Action s ->
    List.map s.content ~f:StellarRays.vars |> List.concat )
  |> List.concat

let normalize_vars (mcs : Marked.constellation) =
  let vars = all_vars mcs in
  let new_x, new_i = fresh_var vars in
  let new_vars =
    List.mapi vars ~f:(fun i _ ->
      Var (new_x, Some (Option.value new_i ~default:0 + i)) )
  in
  let sub = List.zip_exn vars new_vars in
  subst_all_vars sub mcs
