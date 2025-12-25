(*
 * lsc_exec.ml - Queue-based execution engine for star fusion
 *
 * This module implements the core execution algorithm using an explicit
 * work queue approach for clarity and efficiency.
 *)

open Base
open Lsc_ast
open Lsc_ast.StellarRays
open Lsc_ast.Raw

(* ============================================================
   Type Definitions
   ============================================================ *)

(** A candidate fusion between a state ray and an action ray *)
type fusion_candidate =
  { state_idx : int
  ; state_ray_idx : int
  ; action_idx : int
  ; action_ray_idx : int
  ; theta : substitution
  ; state_star : star
  ; action_star : star
  ; other_action_rays : ray list (* rays before the matching one *)
  }

(** Result of searching for fusions *)
type fusion_result =
  { new_stars : star list
  ; remaining_actions : star list
  }

(** Configuration for execution *)
type exec_config =
  { linear : bool
  ; mutable var_counter : int
  }

(** Observable events during execution (for tracing) *)
type exec_event =
  | StepStart of
      { step : int
      ; actions : constellation
      ; states : constellation
      }
  | FusionFound of fusion_candidate
  | StepComplete of
      { step : int
      ; result : constellation
      }
  | ExecutionDone of constellation

(** Event handler type *)
type event_handler = exec_event -> unit

(* ============================================================
   Core Fusion Logic
   ============================================================ *)

let fmap_ban ~f = function
  | Ineq (b1, b2) -> Ineq (f b1, f b2)
  | Incomp (b1, b2) -> Incomp (f b1, f b2)

(** Perform fusion of two stars along matched rays *)
let perform_fusion ~repl1 ~repl2 ~other_state_rays ~other_action_rays
  ~state_bans ~action_bans ~theta : star =
  let new_state = List.map other_state_rays ~f:repl1 in
  let new_action = List.map other_action_rays ~f:repl2 in
  let nbans1 = List.map state_bans ~f:(fmap_ban ~f:repl1) in
  let nbans2 = List.map action_bans ~f:(fmap_ban ~f:repl2) in
  { content = List.map (new_state @ new_action) ~f:(subst theta)
  ; bans = List.map (nbans1 @ nbans2) ~f:(fmap_ban ~f:(subst theta))
  }

(** Check if bans are coherent (no contradictions) *)
let coherent_bans bans =
  let inequalities, incompatibles =
    List.fold bans ~init:([], []) ~f:(fun (ineqs, incomps) ban ->
      match ban with
      | Ineq (b1, b2) -> ((b1, b2) :: ineqs, incomps)
      | Incomp (b1, b2) -> (ineqs, (b1, b2) :: incomps) )
  in
  let ineqs_ok =
    List.for_all inequalities ~f:(fun (b1, b2) -> not (equal_ray b1 b2))
  in
  let incomps_ok =
    let rec check = function
      | [] -> true
      | (box, slice) :: rest ->
        let conflict =
          List.exists rest ~f:(fun (b, s) ->
            equal_ray box b && not (equal_ray slice s) )
        in
        (not conflict) && check rest
    in
    check incompatibles
  in
  ineqs_ok && incomps_ok

(* ============================================================
   Candidate Finding - Queue-Based Approach
   ============================================================ *)

(** Find all fusion candidates between a state ray and an action star. Returns
    list of (action_ray_idx, rays_before, theta) *)
let find_action_matches ~repl1 ~repl2 (state_ray : ray) (action : star) :
  (int * ray list * substitution) list =
  let rec scan idx before = function
    | [] -> []
    | r :: rest when not (is_polarised r) ->
      (* Skip unpolarized rays *)
      scan (idx + 1) (r :: before) rest
    | r :: rest -> (
      match raymatcher (repl1 state_ray) (repl2 r) with
      | None -> scan (idx + 1) (r :: before) rest
      | Some theta ->
        (* Found match, continue scanning for more *)
        let remaining = scan (idx + 1) (r :: before) rest in
        (idx, List.rev before @ rest, theta) :: remaining )
  in
  scan 0 [] action.content

(** Find all fusions for a given state ray against all actions. This is the core
    work queue processor for a single ray. *)
let find_ray_fusions ~config ~emit_event ~state_idx ~state_ray_idx ~state_ray
  ~other_state_rays ~state_bans (actions : star list) : fusion_result =
  let repl1 = replace_indices config.var_counter in
  let results = ref [] in
  let consumed_actions = ref [] in

  List.iteri actions ~f:(fun action_idx action ->
    let repl2 = replace_indices (config.var_counter + 1) in
    let matches = find_action_matches ~repl1 ~repl2 state_ray action in

    List.iter matches ~f:(fun (action_ray_idx, other_action_rays, theta) ->
      let candidate =
        { state_idx
        ; state_ray_idx
        ; action_idx
        ; action_ray_idx
        ; theta
        ; state_star =
            { content = state_ray :: other_state_rays; bans = state_bans }
        ; action_star = action
        ; other_action_rays
        }
      in
      emit_event (FusionFound candidate);

      let fused =
        perform_fusion ~repl1 ~repl2 ~other_state_rays ~other_action_rays
          ~state_bans ~action_bans:action.bans ~theta
      in
      if coherent_bans fused.bans then (
        results := fused :: !results;
        config.var_counter <- config.var_counter + 2;
        if config.linear then
          consumed_actions := action_idx :: !consumed_actions ) ) );

  let remaining =
    if config.linear then
      List.filter_mapi actions ~f:(fun i a ->
        if List.mem !consumed_actions i ~equal:Int.equal then None else Some a )
    else actions
  in
  { new_stars = List.rev !results; remaining_actions = remaining }

(** Try to find fusions for any ray in a state star *)
let try_state_star ~config ~emit_event ~state_idx (state : star)
  (actions : star list) : (star list * star list) option =
  let rec try_ray ray_idx before = function
    | [] -> None
    | r :: rest when not (is_polarised r) ->
      try_ray (ray_idx + 1) (r :: before) rest
    | state_ray :: rest ->
      let other_rays = List.rev_append before rest in
      let result =
        find_ray_fusions ~config ~emit_event ~state_idx ~state_ray_idx:ray_idx
          ~state_ray ~other_state_rays:other_rays ~state_bans:state.bans actions
      in
      if List.is_empty result.new_stars then
        try_ray (ray_idx + 1) (state_ray :: before) rest
      else Some (result.new_stars, result.remaining_actions)
  in
  try_ray 0 [] state.content

(* ============================================================
   Main Execution Loop
   ============================================================ *)

(** Process the work queue: find first state that can interact *)
let rec process_queue ~config ~emit_event ~queue_idx ~before actions = function
  | [] -> None
  | state :: rest -> (
    match
      try_state_star ~config ~emit_event ~state_idx:queue_idx state actions
    with
    | None ->
      process_queue ~config ~emit_event ~queue_idx:(queue_idx + 1)
        ~before:(state :: before) actions rest
    | Some (new_stars, new_actions) ->
      let new_states = List.rev_append before rest @ new_stars in
      Some (new_states, new_actions) )

(** Main execution function *)
let exec ?(linear = false) ?(on_event = fun _ -> ()) mcs : constellation =
  let config = { linear; var_counter = 0 } in

  (* Separate into actions and states *)
  let actions, states =
    let rec classify acts sts = function
      | [] -> (List.rev acts, List.rev sts)
      | Marked.State s :: rest -> classify acts (s :: sts) rest
      | Marked.Action s :: rest -> classify (s :: acts) sts rest
    in
    classify [] [] mcs
  in

  let rec loop step actions states =
    on_event (StepStart { step; actions; states });

    match
      process_queue ~config ~emit_event:on_event ~queue_idx:0 ~before:[] actions
        states
    with
    | None ->
      on_event (ExecutionDone states);
      states
    | Some (new_states, new_actions) ->
      on_event (StepComplete { step; result = new_states });
      loop (step + 1) new_actions new_states
  in

  loop 1 actions states
  |> List.filter ~f:(fun s -> not @@ List.is_empty s.content)
