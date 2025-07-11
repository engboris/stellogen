open Base
open Lsc_ast
open Lsc_ast.StellarRays
open Lsc_ast.Raw

let ( let* ) x f = Result.bind x ~f

type configuration = constellation * constellation


let fmap_ban ~f = function
  | Ineq (b1, b2) -> Ineq (f b1, f b2)
  | Incomp (b1, b2) -> Incomp (f b1, f b2)

let fusion repl1 repl2 s1 s2 bans1 bans2 theta : star =
  let new1 = List.map s1 ~f:repl1 in
  let new2 = List.map s2 ~f:repl2 in
  let nbans1 = List.map bans1 ~f:(fmap_ban ~f:repl1) in
  let nbans2 = List.map bans2 ~f:(fmap_ban ~f:repl2) in
  { content = List.map (new1 @ new2) ~f:(subst theta)
  ; bans = List.map (nbans1 @ nbans2) ~f:(fmap_ban ~f:(subst theta))
  }

let group_bans =
  List.fold_left ~init:([], []) ~f:(function ineq, incomp ->
    (function
    | Ineq (b1, b2) -> ((b1, b2) :: ineq, incomp)
    | Incomp (b1, b2) -> (ineq, (b1, b2) :: incomp) ) )

let exists_incomp_pair (box, slice) =
  List.exists ~f:(fun (box', slice') ->
    equal_ray box box' && (not @@ equal_ray slice slice') )

let coherent_incomp incomp =
  let aux others res = function
    | [] -> res
    | h :: t -> res && (not @@ exists_incomp_pair h (others @ t))
  in
  aux [] true incomp

let coherent_bans bans =
  let ineq, incomp = group_bans bans in
  List.for_all ineq ~f:(fun (b1, b2) -> not @@ equal_ray b1 b2)
  && coherent_incomp incomp

let ident_counter = ref 0

let classify =
  let rec aux (cs, space) = function
    | [] -> (List.rev cs, List.rev space)
    | Marked.State s :: t -> aux (cs, s :: space) t
    | Marked.Action s :: t -> aux (s :: cs, space) t
  in
  aux ([], [])

let extract_intspace (mcs : Marked.constellation) =
  ident_counter := 0;
  classify mcs

(* interaction between one selected ray and one selected action *)
let rec interaction ~queue repl1 repl2 (selected_action, other_actions)
  (selected_ray, other_rays, bans) : constellation =
  match selected_action.content with
  | [] -> []
  | r' :: s' when not (is_polarised r') ->
    interaction ~queue:(r' :: queue) repl1 repl2
      ({ content = s'; bans }, other_actions)
      (selected_ray, other_rays, bans)
  | r' :: s' -> (
    match raymatcher (repl1 selected_ray) (repl2 r') with
    | None ->
      interaction ~queue:(r' :: queue) repl1 repl2
        ({ content = s'; bans }, other_actions)
        (selected_ray, other_rays, bans)
    (* if there is an actual connection between rays *)
    | Some theta ->
      (* action is consumed when execution is linear *)
      let next =
        interaction ~queue:(r' :: queue) repl1 repl2
          ({ content = s'; bans }, other_actions)
          (selected_ray, other_rays, bans)
      in
      let other_rays' = queue @ s' in
      let after_fusion =
        fusion repl1 repl2 other_rays other_rays' bans selected_action.bans
          theta
      in
      let res =
        if coherent_bans after_fusion.bans then after_fusion :: next else next
      in
      ident_counter := !ident_counter + 2;
      res )

(* search partner for a selected ray within a set of available actions *)
let search_partners ~linear (selected_ray, other_rays, bans) actions :
  star list * star list =
  let repl1 = replace_indices !ident_counter in
  let rec try_actions acc = function
    | [] -> ([], acc)
    | selected_action :: other_actions ->
      let repl2 = replace_indices (!ident_counter + 1) in
      let res =
        interaction ~queue:[] repl1 repl2
          (selected_action, other_actions)
          (selected_ray, other_rays, bans)
      in
      if (not @@ List.is_empty res) && linear then
        let next, new_actions = try_actions acc other_actions in
        (res @ next, new_actions)
      else
        let next, new_actions =
          try_actions (selected_action :: acc) other_actions
        in
        (res @ next, new_actions)
  in
  try_actions [] actions

let rec select_ray ~linear ~queue actions other_states (selected_state, bans) :
  star list option * star list =
  match selected_state with
  | [] -> (None, actions)
  (* if unpolarized, no need to try, try other stars *)
  | r :: rs when not (is_polarised r) ->
    select_ray ~linear ~queue:(r :: queue) actions other_states (rs, bans)
  | selected_ray :: other_rays -> (
    (* look for partners for the selected rays in actions *)
    match
      search_partners ~linear (selected_ray, queue @ other_rays, bans) actions
    with
    (* interaction did nothing (no partner), try other rays *)
    | [], new_actions ->
      select_ray ~linear ~queue:(selected_ray :: queue) new_actions other_states
        (other_rays, bans)
    (* interaction returns a result, keep it for the next round *)
    | new_stars, new_actions -> (Some new_stars, new_actions) )

let rec select_star ~linear ~queue actions :
  star list -> star list option * star list = function
  | [] -> (None, actions)
  (* select a state star and try finding a partner for each ray *)
  | selected_state :: other_states -> (
    match
      select_ray ~linear ~queue:[] actions other_states
        (selected_state.content, selected_state.bans)
    with
    (* no success with this star, try other stars *)
    | None, new_actions ->
      select_star ~linear new_actions ~queue:(selected_state :: queue)
        other_states
    (* got new stars to add, construct the result for the next round *)
    | Some new_stars, new_actions ->
      (Some (List.rev queue @ other_states @ new_stars), new_actions) )

let exec ?(linear = false) mcs : constellation =
  (* do a sequence of rounds with a single interaction on state per round *)
  let rec loop (actions, states) =
    match select_star ~linear ~queue:[] actions states with
    | None, _ -> states (* no more possible interaction *)
    | Some res, new_actions -> loop (new_actions, res)
  in
  let cfg = extract_intspace mcs in
  loop cfg |> List.filter ~f:(fun s -> not @@ List.is_empty s.content)
