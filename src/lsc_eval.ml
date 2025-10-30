open Base
open Lsc_ast
open Lsc_ast.StellarRays
open Lsc_ast.Raw

let ( let* ) x f = Result.bind x ~f

(* ----------------------------------------
   Trace mode support
   ---------------------------------------- *)

type source_location =
  { filename : string
  ; line : int
  ; column : int
  }

type trace_step =
  { step_num : int
  ; actions : constellation
  ; states : constellation
  ; selected_state_idx : int option
  ; selected_ray_idx : int option
  ; selected_action_idx : int option
  ; partner_ray : ray option
  ; substitution : substitution option
  ; is_final : bool
  ; location : source_location option
  }

type trace_config =
  { enabled : bool
  ; mutable step_count : int
  ; mutable steps : trace_step list
  ; web_mode : bool
  ; mutable current_location : source_location option
  ; mutable current_states : constellation
  ; mutable current_actions : constellation
  ; mutable fusion_detected : bool
  }

let make_trace_config ?(web_mode = false) enabled =
  { enabled
  ; step_count = 0
  ; steps = []
  ; web_mode
  ; current_location = None
  ; current_states = []
  ; current_actions = []
  ; fusion_detected = false
  }

let set_trace_location cfg loc = cfg.current_location <- loc

let add_trace_step cfg step = if cfg.enabled then cfg.steps <- step :: cfg.steps

let get_trace_steps cfg = List.rev cfg.steps

let get_source_line filename line_num =
  try
    (* In web mode or when file access fails, gracefully return None *)
    let ic = Stdlib.open_in filename in
    let rec skip_lines n =
      if n <= 1 then ()
      else
        let _ = Stdlib.input_line ic in
        skip_lines (n - 1)
    in
    skip_lines line_num;
    let line = Stdlib.input_line ic in
    Stdlib.close_in ic;
    Some line
  with
  | Sys_error _ -> None (* File system not available (e.g., web mode) *)
  | End_of_file -> None
  | _ -> None

let format_trace_steps_html steps =
  let open Lsc_pretty in
  let buffer = Buffer.create 1024 in

  let add_html str = Buffer.add_string buffer str in
  let add_line str =
    add_html str;
    add_html "\n"
  in

  let escape_html s =
    String.substr_replace_all s ~pattern:"&" ~with_:"&amp;"
    |> String.substr_replace_all ~pattern:"<" ~with_:"&lt;"
    |> String.substr_replace_all ~pattern:">" ~with_:"&gt;"
    |> String.substr_replace_all ~pattern:"\"" ~with_:"&quot;"
  in

  List.iteri steps ~f:(fun _i step ->
    add_line "<div class='trace-step'>";
    if step.is_final then (
      add_line
        (Printf.sprintf
           "<div class='step-header final'>Execution Complete (Step %d)</div>"
           step.step_num );
      add_line "<div class='step-content'>";
      ( match step.location with
      | Some loc -> (
        add_line
          (Printf.sprintf "<div class='location'>%s:%d:%d</div>" loc.filename
             loc.line loc.column );
        match get_source_line loc.filename loc.line with
        | Some line ->
          let trimmed = String.strip line in
          if not (String.is_empty trimmed) then
            add_line
              (Printf.sprintf "<div class='source-line'>%s</div>"
                 (escape_html trimmed) )
        | None -> () )
      | None -> () );
      add_line "<div class='result-label'>Final Result:</div>";
      add_line "<div class='constellation'>";
      List.iteri step.states ~f:(fun idx star ->
        add_line
          (Printf.sprintf "<div class='star'>[%d] %s</div>" idx
             (string_of_star star) ) );
      add_line "</div>";
      add_line "</div>" )
    else (
      add_line
        (Printf.sprintf "<div class='step-header'>Step %d</div>" step.step_num);
      add_line "<div class='step-content'>";
      ( match step.location with
      | Some loc -> (
        add_line
          (Printf.sprintf "<div class='location'>%s:%d:%d</div>" loc.filename
             loc.line loc.column );
        match get_source_line loc.filename loc.line with
        | Some line ->
          let trimmed = String.strip line in
          if not (String.is_empty trimmed) then
            add_line
              (Printf.sprintf "<div class='source-line'>%s</div>"
                 (escape_html trimmed) )
        | None -> () )
      | None -> () );

      add_line "<div class='section'>";
      add_line "<div class='label'>Actions:</div>";
      if List.is_empty step.actions then add_line "<div class='empty'>{ }</div>"
      else (
        add_line "<div class='constellation'>";
        List.iteri step.actions ~f:(fun idx star ->
          add_line
            (Printf.sprintf "<div class='star action-star'>[%d] %s</div>" idx
               (string_of_star star) ) );
        add_line "</div>" );
      add_line "</div>";

      add_line "<div class='section'>";
      add_line "<div class='label'>States:</div>";
      if List.is_empty step.states then add_line "<div class='empty'>{ }</div>"
      else (
        add_line "<div class='constellation'>";
        List.iteri step.states ~f:(fun idx star ->
          add_line
            (Printf.sprintf "<div class='star state-star'>[%d] %s</div>" idx
               (string_of_star star) ) );
        add_line "</div>" );
      add_line "</div>";

      add_line "</div>" );
    add_line "</div>" );

  Buffer.contents buffer

let wait_for_keypress () =
  (* Simple version that works everywhere including web *)
  let _ = Stdlib.input_line Stdlib.stdin in
  ()

let cyan text = "\x1b[36m" ^ text ^ "\x1b[0m"

let green text = "\x1b[32m" ^ text ^ "\x1b[0m"

let yellow text = "\x1b[33m" ^ text ^ "\x1b[0m"

let magenta text = "\x1b[35m" ^ text ^ "\x1b[0m"

let bold text = "\x1b[1m" ^ text ^ "\x1b[0m"

let dim text = "\x1b[2m" ^ text ^ "\x1b[0m"

let print_trace_header step_num location status_msg =
  Stdlib.Printf.printf "\n%s\n" (String.make 80 '=');
  Stdlib.Printf.printf "%s %s"
    (bold (cyan "Step"))
    (bold (yellow (Int.to_string step_num)));
  ( match status_msg with
  | Some msg -> Stdlib.Printf.printf " - %s" (bold msg)
  | None -> () );
  ( match location with
  | Some loc -> (
    Stdlib.Printf.printf "\n%s %s:%d:%d" (dim "at") loc.filename loc.line
      loc.column;
    (* Print the source line content *)
    match get_source_line loc.filename loc.line with
    | Some line ->
      let trimmed = String.strip line in
      if not (String.is_empty trimmed) then
        Stdlib.Printf.printf "\n  %s %s" (dim "│") (dim trimmed)
    | None -> () )
  | None -> () );
  Stdlib.Printf.printf "\n%s\n" (String.make 80 '=')

let print_trace_constellation ?(selected_star = None) ?(selected_ray = None)
  ?(partner_star = None) ?(partner_ray = None) label constellation =
  let open Lsc_pretty in
  if List.is_empty constellation then
    Stdlib.Printf.printf "%s %s\n" (bold label) (dim "{}")
  else begin
    Stdlib.Printf.printf "%s\n" (bold label);
    List.iteri constellation ~f:(fun i star ->
      let is_selected =
        match selected_star with Some idx -> idx = i | None -> false
      in
      let is_partner =
        match partner_star with Some idx -> idx = i | None -> false
      in
      let selected_ray_idx = if is_selected then selected_ray else None in
      let partner_ray_idx = if is_partner then partner_ray else None in
      let marker =
        if is_selected then magenta "◄ "
        else if is_partner then green "◄ "
        else "  "
      in
      let index_str =
        if is_selected then magenta (Printf.sprintf "[%d]" i)
        else if is_partner then green (Printf.sprintf "[%d]" i)
        else dim (Printf.sprintf "[%d]" i)
      in
      (* If this star has a selected ray, print rays individually with arrow *)
      match (selected_ray_idx, partner_ray_idx) with
      | Some ray_idx, _ | _, Some ray_idx ->
        Stdlib.Printf.printf "%s%s [" marker index_str;
        List.iteri star.content ~f:(fun j ray ->
          if j > 0 then Stdlib.Printf.printf " ";
          Stdlib.Printf.printf "%s" (string_of_ray ray) );
        if not (List.is_empty star.bans) then
          Stdlib.Printf.printf " || %s"
            (List.map star.bans ~f:string_of_ban |> String.concat ~sep:" ");
        Stdlib.Printf.printf "]\n";
        (* Print arrow pointing to the selected ray *)
        let arrow_color = if is_selected then magenta else green in
        (* Calculate visual width (accounting for ANSI codes in marker/index_str) *)
        let visual_marker_width = 2 in
        (* "◄ " or "  " *)
        let visual_index_width = String.length (Printf.sprintf "[%d]" i) in
        let prefix_len = visual_marker_width + visual_index_width + 2 in
        (* +2 for " [" *)
        let spaces = ref prefix_len in
        List.iteri star.content ~f:(fun j ray ->
          if j < ray_idx then
            (* Add this ray's width + space to position *)
            spaces := !spaces + String.length (string_of_ray ray) + 1
          else if j = ray_idx then
            (* Print arrow at current position *)
            Stdlib.Printf.printf "%s%s\n" (String.make !spaces ' ')
              (arrow_color "^")
          else () )
      | None, None ->
        Stdlib.Printf.printf "%s%s %s\n" marker index_str (string_of_star star) )
  end

let print_trace_ray label ray =
  let open Lsc_pretty in
  Stdlib.Printf.printf "%s %s\n" (bold label) (green (string_of_ray ray))

let print_trace_fusion_visual step_num location states actions state_idx ray_idx
  action_idx action_ray_idx theta =
  let open Lsc_pretty in
  print_trace_header step_num location (Some (magenta "Fusion detected!"));
  Stdlib.Printf.printf "\n";
  print_trace_constellation ~selected_star:(Some state_idx)
    ~selected_ray:(Some ray_idx) (cyan "States:") states;
  Stdlib.Printf.printf "\n";
  print_trace_constellation ~partner_star:(Some action_idx)
    ~partner_ray:(Some action_ray_idx) (cyan "Actions:") actions;
  if not (List.is_empty theta) then
    Stdlib.Printf.printf "\n  %s %s\n" (dim "Substitution:")
      (yellow (string_of_subst theta))

let print_trace_footer () =
  Stdlib.Printf.printf "\n%s\n" (dim "Press Enter to continue...");
  Stdlib.flush Stdlib.stdout;
  wait_for_keypress ()

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

let group_bans bans =
  List.fold bans ~init:([], []) ~f:(fun (inequalities, incompatibles) ban ->
    match ban with
    | Ineq (b1, b2) -> ((b1, b2) :: inequalities, incompatibles)
    | Incomp (b1, b2) -> (inequalities, (b1, b2) :: incompatibles) )

let exists_conflicting_incomp_pair (box, slice) incomp_list =
  List.exists incomp_list ~f:(fun (other_box, other_slice) ->
    equal_ray box other_box && not (equal_ray slice other_slice) )

let coherent_incomp incompatible_pairs =
  let rec check_all = function
    | [] -> true
    | head :: tail ->
      (not (exists_conflicting_incomp_pair head tail)) && check_all tail
  in
  check_all incompatible_pairs

let coherent_bans bans =
  let inequalities, incompatibles = group_bans bans in
  List.for_all inequalities ~f:(fun (b1, b2) -> not (equal_ray b1 b2))
  && coherent_incomp incompatibles

let ident_counter = ref 0

let classify marked_constellation =
  let rec separate_actions_and_states actions states = function
    | [] -> (List.rev actions, List.rev states)
    | Marked.State s :: rest ->
      separate_actions_and_states actions (s :: states) rest
    | Marked.Action s :: rest ->
      separate_actions_and_states (s :: actions) states rest
  in
  separate_actions_and_states [] [] marked_constellation

let extract_intspace (mcs : Marked.constellation) =
  ident_counter := 0;
  classify mcs

(* interaction between one selected ray and one selected action *)
let rec interaction ~queue ~trace ~state_idx ~ray_idx ~action_idx repl1 repl2
  (selected_action, other_actions) (selected_ray, other_rays, bans) :
  constellation =
  match selected_action.content with
  | [] -> []
  | r' :: s' when not (is_polarised r') ->
    interaction ~queue:(r' :: queue) ~trace ~state_idx ~ray_idx ~action_idx
      repl1 repl2
      ({ content = s'; bans }, other_actions)
      (selected_ray, other_rays, bans)
  | r' :: s' -> (
    match raymatcher (repl1 selected_ray) (repl2 r') with
    | None ->
      interaction ~queue:(r' :: queue) ~trace ~state_idx ~ray_idx ~action_idx
        repl1 repl2
        ({ content = s'; bans }, other_actions)
        (selected_ray, other_rays, bans)
    (* if there is an actual connection between rays *)
    | Some theta ->
      let action_ray_idx = List.length queue in
      ( match trace with
      | Some cfg when cfg.enabled && not cfg.web_mode ->
        if not cfg.fusion_detected then (
          cfg.fusion_detected <- true;
          print_trace_fusion_visual cfg.step_count cfg.current_location
            cfg.current_states cfg.current_actions state_idx ray_idx action_idx
            action_ray_idx theta )
      | _ -> () );
      (* action is consumed when execution is linear *)
      let next =
        interaction ~queue:(r' :: queue) ~trace ~state_idx ~ray_idx ~action_idx
          repl1 repl2
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
let search_partners ~linear ~trace ~state_idx ~ray_idx
  (selected_ray, other_rays, bans) actions : star list * star list =
  let repl1 = replace_indices !ident_counter in
  let rec try_actions acc action_idx actions_list = function
    | [] -> ([], acc)
    | selected_action :: other_actions ->
      let repl2 = replace_indices (!ident_counter + 1) in
      let res =
        interaction ~queue:[] ~trace ~state_idx ~ray_idx ~action_idx repl1 repl2
          (selected_action, other_actions)
          (selected_ray, other_rays, bans)
      in
      if (not @@ List.is_empty res) && linear then
        let next, new_actions =
          try_actions acc (action_idx + 1) actions_list other_actions
        in
        (res @ next, new_actions)
      else
        let next, new_actions =
          try_actions (selected_action :: acc) (action_idx + 1) actions_list
            other_actions
        in
        (res @ next, new_actions)
  in
  try_actions [] 0 actions actions

let rec select_ray ~linear ~trace ~state_idx ~ray_idx ~queue actions
  other_states (selected_state, bans) : star list option * star list =
  match selected_state with
  | [] -> (None, actions)
  (* if unpolarized, no need to try, try other stars *)
  | r :: rs when not (is_polarised r) ->
    select_ray ~linear ~trace ~state_idx ~ray_idx:(ray_idx + 1)
      ~queue:(r :: queue) actions other_states (rs, bans)
  | selected_ray :: other_rays -> (
    (* look for partners for the selected rays in actions *)
    match
      search_partners ~linear ~trace ~state_idx ~ray_idx
        (selected_ray, queue @ other_rays, bans)
        actions
    with
    (* interaction did nothing (no partner), try other rays *)
    | [], new_actions ->
      select_ray ~linear ~trace ~state_idx ~ray_idx:(ray_idx + 1)
        ~queue:(selected_ray :: queue) new_actions other_states
        (other_rays, bans)
    (* interaction returns a result, keep it for the next round *)
    | new_stars, new_actions ->
      ( match trace with
      | Some cfg when cfg.enabled && not cfg.web_mode -> print_trace_footer ()
      | _ -> () );
      (Some new_stars, new_actions) )

let rec select_star ~linear ~trace ~queue actions :
  star list -> star list option * star list = function
  | [] -> (None, actions)
  (* select a state star and try finding a partner for each ray *)
  | selected_state :: other_states -> (
    let state_idx = List.length queue in
    match
      select_ray ~linear ~trace ~state_idx ~ray_idx:0 ~queue:[] actions
        other_states
        (selected_state.content, selected_state.bans)
    with
    (* no success with this star, try other stars *)
    | None, new_actions ->
      select_star ~linear ~trace new_actions ~queue:(selected_state :: queue)
        other_states
    (* got new stars to add, construct the result for the next round *)
    | Some new_stars, new_actions ->
      (Some (List.rev queue @ other_states @ new_stars), new_actions) )

let exec ?(linear = false) ?(trace = None) mcs : constellation =
  (* do a sequence of rounds with a single interaction on state per round *)
  let rec loop (actions, states) =
    let trace_step_start () =
      match trace with
      | Some cfg when cfg.enabled ->
        cfg.step_count <- cfg.step_count + 1;
        cfg.fusion_detected <- false;
        (* Store current constellations for fusion visualization *)
        cfg.current_states <- states;
        cfg.current_actions <- actions;
        (* Record trace step for web mode *)
        if cfg.web_mode then
          add_trace_step cfg
            { step_num = cfg.step_count
            ; actions
            ; states
            ; selected_state_idx = None
            ; selected_ray_idx = None
            ; selected_action_idx = None
            ; partner_ray = None
            ; substitution = None
            ; is_final = false
            ; location = cfg.current_location
            }
      | _ -> ()
    in
    trace_step_start ();
    match select_star ~linear ~trace ~queue:[] actions states with
    | None, _ ->
      ( match trace with
      | Some cfg when cfg.enabled ->
        if cfg.web_mode then
          add_trace_step cfg
            { step_num = cfg.step_count + 1
            ; actions
            ; states
            ; selected_state_idx = None
            ; selected_ray_idx = None
            ; selected_action_idx = None
            ; partner_ray = None
            ; substitution = None
            ; is_final = true
            ; location = cfg.current_location
            }
        else (
          print_trace_header cfg.step_count cfg.current_location
            (Some (green "Execution complete"));
          Stdlib.Printf.printf "\n";
          print_trace_constellation (cyan "Final result:") states;
          if not cfg.web_mode then print_trace_footer () )
      | _ -> () );
      states (* no more possible interaction *)
    | Some res, new_actions -> loop (new_actions, res)
  in
  let cfg = extract_intspace mcs in
  ( match trace with
  | Some cfg when cfg.enabled && not cfg.web_mode ->
    Stdlib.Printf.printf "%s\n" (bold (magenta "Starting execution trace..."));
    Stdlib.Printf.printf "\n"
  | _ -> () );
  loop cfg |> List.filter ~f:(fun s -> not @@ List.is_empty s.content)
