open Base

type polarity =
  | Pos
  | Neg
  | Null
[@@deriving eq]

module StellarSig = struct
  type idvar = string * int option

  type idfunc = polarity * string

  let string_of_idvar (s, index_opt) =
    match index_opt with None -> s | Some j -> s ^ Int.to_string j

  let equal_idvar x y = String.equal (string_of_idvar x) (string_of_idvar y)

  let equal_idfunc (p1, f1) (p2, f2) =
    equal_polarity p1 p2 && String.equal f1 f2

  let compatible (p1, f1) (p2, f2) =
    String.equal f1 f2
    &&
    match (p1, p2) with
    | Pos, Neg | Neg, Pos | Null, Null -> true
    | _ -> false
end

module MatchableSig = struct
  type idvar = string * int option

  type idfunc = polarity * string

  let string_of_idvar (s, index_opt) =
    match index_opt with None -> s | Some j -> s ^ Int.to_string j

  let equal_idvar x y = String.equal (string_of_idvar x) (string_of_idvar y)

  let equal_idfunc (p1, f1) (p2, f2) =
    equal_polarity p1 p2 && String.equal f1 f2

  (* Matchable: only checks function name equality, ignores polarity *)
  let compatible (_p1, f1) (_p2, f2) = String.equal f1 f2
end

module StellarRays = Unification.Make (StellarSig)
module MatchableRays = Unification.Make (MatchableSig)
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

let inject i : StellarSig.idvar -> StellarSig.idvar = function
  | x, None -> (x, Some i)
  | x, Some i -> (x, Some i)

let replace_indices (i : int) : ray -> ray =
  map Fn.id (fun (x, _) -> Var (x, Some i))

let raymatcher r r' : substitution option =
  if is_polarised r && is_polarised r' then solution [ (r, r') ] else None

(* Convert StellarRays.term to MatchableRays.term *)
let rec to_matchable_term : StellarRays.term -> MatchableRays.term = function
  | StellarRays.Var x -> MatchableRays.Var x
  | StellarRays.Func (f, ts) ->
    MatchableRays.Func (f, List.map ~f:to_matchable_term ts)

(* Check if two rays can unify using term unification (ignoring polarity) *)
let terms_unifiable r r' =
  let r_match = to_matchable_term r in
  let r'_match = to_matchable_term r' in
  MatchableRays.solution [ (r_match, r'_match) ] |> Option.is_some

let fresh_var vars =
  let rec find_fresh_index i =
    if List.mem vars ("X", Some i) ~equal:StellarSig.equal_idvar then
      find_fresh_index (i + 1)
    else ("X", Some i)
  in
  find_fresh_index 0

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
  mcs
  |> List.concat_map ~f:(function Marked.State s | Marked.Action s ->
    List.concat_map s.content ~f:StellarRays.vars )

let normalize_vars (mcs : Marked.constellation) =
  let vars = all_vars mcs in
  let new_var_name, new_start_index = fresh_var vars in
  let start_index = Option.value new_start_index ~default:0 in
  let new_vars =
    List.mapi vars ~f:(fun offset _ ->
      Var (new_var_name, Some (start_index + offset)) )
  in
  let substitution = List.zip_exn vars new_vars in
  subst_all_vars substitution mcs
