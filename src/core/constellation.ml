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

(* Rename each distinct variable of [rays] to a fresh index starting at
   [base]. Injective on variables: same-named variables with different
   indices stay distinct. Returns the renaming and the number of
   indices consumed. *)
let injective_renaming (base : int) (rays : ray list) : (ray -> ray) * int =
  let distinct =
    List.concat_map rays ~f:vars
    |> List.fold ~init:[] ~f:(fun acc v ->
      if List.mem acc v ~equal:StellarSig.equal_idvar then acc else v :: acc )
    |> List.rev
  in
  let renamed =
    List.mapi distinct ~f:(fun k (x, _) -> Var (x, Some (base + k)))
  in
  let assoc = List.zip_exn distinct renamed in
  let rename v =
    match List.Assoc.find assoc ~equal:StellarSig.equal_idvar v with
    | Some t -> t
    | None -> Var v
  in
  (map Fn.id rename, List.length distinct)

let raymatcher r r' : substitution option =
  if is_polarised r && is_polarised r' then solution [ (r, r') ] else None

(* Base observation for ~= : structural unifiability, ignoring polarity.
   Polarities are normalized to Null so that the regular unification
   decides matchability (Null/Null symbols are compatible). *)
let strip_polarities : ray -> ray =
  map (fun (_, f) -> (Null, f)) (fun v -> Var v)

let terms_unifiable r r' =
  solution [ (strip_polarities r, strip_polarities r') ] |> Option.is_some

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
  (* The bool on each variant tracks whether the star is consumable
     (linear): used at most once per execution. It is orthogonal to the
     State/Action tag, so the two can vary independently. *)
  type star =
    | State of Raw.star * bool
    | Action of Raw.star * bool
  [@@deriving eq]

  type constellation = star list [@@deriving eq]

  let map ~f : star -> star = function
    | State (s, l) ->
      State ({ content = List.map ~f s.content; bans = s.bans }, l)
    | Action (s, l) ->
      Action ({ content = List.map ~f s.content; bans = s.bans }, l)

  let make_action s = Action (s, false)

  let make_state s = State (s, false)

  let make_action_all = List.map ~f:make_action

  let make_state_all = List.map ~f:make_state

  let remove : star -> Raw.star = function State (s, _) | Action (s, _) -> s

  let remove_all = List.map ~f:remove

  let is_linear : star -> bool = function State (_, l) | Action (_, l) -> l

  let set_linear (l : bool) : star -> star = function
    | State (s, _) -> State (s, l)
    | Action (s, _) -> Action (s, l)

  let set_linear_all (l : bool) = List.map ~f:(set_linear l)

  (* Force State, preserving whatever linear flag the star already had -
     this is what @ does: it overrides State/Action, not linearity. *)
  let refocus : star -> star = function
    | State (s, l) -> State (s, l)
    | Action (s, l) -> State (s, l)

  let refocus_all = List.map ~f:refocus

  let normalize_all x = x |> remove_all |> make_action_all
end

let subst_all_vars sub = List.map ~f:(Marked.map ~f:(subst sub))

let all_vars mcs : StellarSig.idvar list =
  mcs
  |> List.concat_map ~f:(function
    | Marked.State (s, _) | Marked.Action (s, _) ->
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
