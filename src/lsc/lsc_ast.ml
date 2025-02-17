open Base
open Pretty
open Format_exn

type polarity =
  | Pos
  | Neg
  | Null

module StellarSig = struct
  type idvar = string * int option

  type idfunc = polarity * string

  let equal_idvar (s, i) (s', i') =
    match (i, i') with
    | None, None -> equal_string s s'
    | Some j, Some j' ->
      equal_string (s ^ Int.to_string j) (s' ^ Int.to_string j')
    | None, Some j' -> equal_string s (s' ^ Int.to_string j')
    | Some j, None -> equal_string (s ^ Int.to_string j) s'

  let equal_idfunc (p, f) (p', f') =
    match (p, p') with
    | Pos, Pos | Neg, Neg | Null, Null -> equal_string f f'
    | _ -> false

  let compatible f g =
    match (f, g) with
    | (Pos, f), (Neg, g) | (Neg, f), (Pos, g) -> equal_string f g
    | (Null, f), (Null, g) -> equal_string f g
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

type ray = term

type ban = ray * ray

type star =
  { content : ray list
  ; bans : ban list
  }

type constellation = star list

let rec compare_ray r1 r2 =
  match (r1, r2) with
  | Var (x, i), Var (y, j) ->
    let i' = Option.value (Option.map i ~f:Int.to_string) ~default:"" in
    let j' = Option.value (Option.map j ~f:Int.to_string) ~default:"" in
    String.compare (x ^ i') (y ^ j')
  | Func _, Var _ -> 1
  | Var _, Func _ -> -1
  | Func ((_, pf1), args1), Func ((_, pf2), args2) -> begin
    match (pf1, pf2) with
    | pf1, pf2 when StellarSig.equal_idfunc pf1 pf2 ->
      List.compare compare_ray args1 args2
    | (Null, f1), (Null, f2) | (Neg, f1), (Neg, f2) | (Pos, f1), (Pos, f2) ->
      String.compare f1 f2
    | (Null, _), (_, _) -> -1
    | (Pos, _), (_, _) -> 1
    | (Neg, _), (Null, _) -> 1
    | (Neg, _), (Pos, _) -> -1
  end

let compare_star = List.compare compare_ray

let equal_ray = equal_term

let sort_rays = List.sort ~compare:compare_ray

let equal_star s1 s2 =
  let s1 = sort_rays s1.content in
  let s2 = sort_rays s2.content in
  List.equal equal_ray s1 s2

let to_var x = Var (x, None)

let to_func (pf, ts) = Func (pf, ts)

let pos f = (Pos, f)

let neg f = (Neg, f)

let null f = (Null, f)

let muted pf = (Muted, pf)

let noisy pf = (Noisy, pf)

let gfunc c ts = Func (c, ts)

let pfunc f ts = gfunc (muted (pos f)) ts

let nfunc f ts = gfunc (muted (neg f)) ts

let func f ts = gfunc (muted (null f)) ts

let var x = Var x

let pconst f = pfunc f []

let nconst f = nfunc f []

let const f = func f []

let is_polarised r : bool =
  let aux = function _, (Pos, _) | _, (Neg, _) -> true | _ -> false in
  exists_func aux r

let replace_indices (i : int) : ray -> ray =
  map Fn.id (fun (x, _) -> Var (x, Some i))

let raymatcher r r' : substitution option =
  if is_polarised r && is_polarised r' then solution [ (r, r') ] else None

(* ---------------------------------------
   Pretty Printer
   --------------------------------------- *)

let string_of_polarity = function Pos -> "+" | Neg -> "-" | Null -> ""

let string_of_polsym (m, (p, f)) =
  match m with
  | Noisy -> string_of_polarity p ^ "#" ^ f
  | Muted -> string_of_polarity p ^ f

let string_of_var (x, i) =
  match i with None -> x | Some i' -> x ^ Int.to_string i'

let rec string_of_ray = function
  | Var xi -> string_of_var xi
  | Func (pf, []) -> string_of_polsym pf
  | Func ((_, (Null, ":")), [ Func ((_, (Null, ":")), [ r1; r2 ]); r3 ]) ->
    "(" ^ string_of_ray r1 ^ ":" ^ string_of_ray r2 ^ "):" ^ string_of_ray r3
  | Func ((_, (Null, ":")), [ r1; r2 ]) ->
    string_of_ray r1 ^ ":" ^ string_of_ray r2
  | Func (pf, ts) ->
    string_of_polsym pf ^ surround "(" ")"
    @@ string_of_list string_of_ray " " ts

let string_of_subst sub =
  List.fold sub ~init:"" ~f:(fun _ (x, r) ->
    string_of_var x ^ "->" ^ string_of_ray r )
  |> surround "{" "}"

let string_of_ban (b1, b2) =
  Printf.sprintf "%s!=%s" (string_of_ray b1) (string_of_ray b2)

let string_of_raylist : ray list -> string = string_of_list string_of_ray " "

let string_of_star s =
  if List.is_empty s.content then "[]"
  else
    string_of_list string_of_ray " " s.content
    ^
    if List.is_empty s.bans then ""
    else " | " ^ string_of_list string_of_ban " " s.bans

let string_of_constellation = function
  | [] -> "{}"
  | [ h ] -> string_of_star h ^ "."
  | h :: t ->
    let string_h = string_of_star h ^ "; " in
    List.fold_left t
      ~init:(List.length t, string_h, String.length string_h)
      ~f:(fun (i, acc, size) s ->
        let string_s = string_of_star s in
        let new_size = size + String.length string_s in
        if equal_int i 1 then (0, acc ^ string_s, 0)
        else if new_size < 80 then (i - 1, acc ^ string_s ^ "; ", new_size)
        else (i - 1, acc ^ string_s ^ ";\n", 0) )
    |> fun (_, x, _) ->
    x |> fun x -> String.append x "."

(* ---------------------------------------
   Operation on marked stars
   --------------------------------------- *)

type marked_star =
  | Marked of star
  | Unmarked of star

type marked_constellation = marked_star list

let compare_mstar ms ms' =
  match (ms, ms') with
  | Marked _, Unmarked _ -> 1
  | Unmarked _, Marked _ -> -1
  | Marked s, Marked s' | Unmarked s, Unmarked s' ->
    compare_star s.content s'.content

let equal_mstar ms ms' = equal_int (compare_mstar ms ms') 0

let fresh_var vars =
  let rec aux i =
    if not @@ List.mem vars ("X", Some i) ~equal:StellarSig.equal_idvar then
      ("X", Some i)
    else aux (i + 1)
  in
  aux 0

let map_mstar ~f : marked_star -> marked_star = function
  | Marked s -> Marked { content = List.map ~f s.content; bans = s.bans }
  | Unmarked s -> Unmarked { content = List.map ~f s.content; bans = s.bans }

let subst_all_vars sub = List.map ~f:(map_mstar ~f:(subst sub))

let subst_all_funcs sub = List.map ~f:(map_mstar ~f:(replace_funcs sub))

let all_vars mcs : StellarSig.idvar list =
  List.map mcs ~f:(function Marked s | Unmarked s ->
    List.map s.content ~f:StellarRays.vars |> List.concat )
  |> List.concat

let normalize_vars (mcs : marked_constellation) =
  let vars = all_vars mcs in
  let new_x, new_i = fresh_var vars in
  let new_vars =
    List.mapi vars ~f:(fun i _ ->
      Var (new_x, Some (Option.value new_i ~default:0 + i)) )
  in
  let sub = List.zip_exn vars new_vars in
  subst_all_vars sub mcs

let equal_mconstellation mcs mcs' =
  let smcs = List.sort ~compare:compare_mstar mcs in
  let smcs' = List.sort ~compare:compare_mstar mcs' in
  List.equal equal_mstar (normalize_vars smcs) (normalize_vars smcs')

let unmark = function s -> Unmarked s

let mark = function s -> Marked s

let focus = List.map ~f:(fun r -> mark r)

let remove_mark : marked_star -> star = function
  | Marked s -> s
  | Unmarked s -> s

let unmark_all = List.map ~f:(fun s -> Unmarked s)

let remove_mark_all : marked_constellation -> constellation =
  List.map ~f:remove_mark

let ident_counter = ref 0

let connectable (s1 : star) (s2 : star) : bool =
  let ( >>= ) = List.Monad_infix.( >>= ) in
  begin
    s1.content >>= fun r1 ->
    s2.content >>= fun r2 ->
    let renamed_r = replace_indices !ident_counter r1 in
    let renamed_r' = replace_indices (!ident_counter + 1) r2 in
    let matching = raymatcher renamed_r renamed_r' in
    if Option.is_some matching then ident_counter := !ident_counter + 1;
    [ matching ]
  end
  |> List.exists ~f:Option.is_some

let rec saturation queue marked remains =
  match queue with
  | [] -> (marked, remains)
  | h :: t ->
    let marked', remains' = List.partition_tf remains ~f:(connectable h) in
    saturation (marked' @ t) (h :: marked) remains'

let cc_representatives from cs =
  let rec selection reps marked remains =
    match remains with
    | [] -> (marked, reps)
    | h :: t ->
      let marked', remains' = List.partition_tf t ~f:(connectable h) in
      let marked'', remains'' = saturation marked' marked remains' in
      selection (h :: reps) marked'' remains''
  in
  selection [] from cs

let extract_intspace (mcs : marked_constellation) =
  let rec sort (cs, space) = function
    | [] -> (List.rev cs, List.rev space)
    | Marked s :: t -> sort (cs, s :: space) t
    | Unmarked s :: t -> sort (s :: cs, space) t
  in
  match sort ([], []) mcs with
  (* marks are selected for you in each connected component *)
  | unmarked, [] ->
    let cs, marked = cc_representatives [] unmarked in
    ident_counter := 0;
    (cs, marked)
  (* user selects marks *)
  | unmarked, marked ->
    ident_counter := 0;
    (unmarked, marked)

(* ---------------------------------------
   Execution
   --------------------------------------- *)

let unpolarized_star s = List.for_all ~f:(Fn.compose not is_polarised) s.content

let kill : constellation -> constellation = List.filter ~f:unpolarized_star

let clean : constellation -> constellation =
  List.filter ~f:(fun s -> List.is_empty s.content)

let selections l =
  let rec aux acc = function
    | [] -> []
    | h :: t -> (h, acc @ t) :: aux (acc @ [ h ]) t
  in
  aux [] l

let fusion repl1 repl2 s1 s2 bans1 bans2 theta : star =
  let new1 = List.map s1 ~f:repl1 in
  let new2 = List.map s2 ~f:repl2 in
  let nbans1 = List.map bans1 ~f:(fun (x, y) -> (repl1 x, repl1 y)) in
  let nbans2 = List.map bans2 ~f:(fun (x, y) -> (repl2 x, repl2 y)) in
  { content = List.map (new1 @ new2) ~f:(subst theta)
  ; bans =
      List.map (nbans1 @ nbans2) ~f:(fun (x, y) ->
        (subst theta x, subst theta y) )
  }

exception TooFewArgs of string

exception TooManyArgs of string

exception UnknownEffect of string

let apply_effect r theta =
  match (r, theta) with
  | Func ((Noisy, (_, "print")), _), [] -> raise (TooFewArgs "print")
  | Func ((Noisy, (_, "print")), _), _ :: _ :: _ -> raise (TooManyArgs "print")
  | Func ((Noisy, (_, "print")), _), [ (_, Func ((_, (Null, arg)), [])) ] ->
    String.strip ~drop:(fun x -> equal_char x '\"') arg
    |> Out_channel.output_string Out_channel.stdout;
    Out_channel.flush Out_channel.stdout
  | Func ((Noisy, (_, "print")), _), [ (_, arg) ] ->
    Out_channel.output_string Out_channel.stdout (string_of_ray arg);
    Out_channel.flush Out_channel.stdout
  | Func ((Noisy, (_, s)), _), _ -> raise (UnknownEffect s)
  | _ -> ()

let string_of_exn = function
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
  | _ -> "unknown exception.\n"

let pause () =
  let open Out_channel in
  let open In_channel in
  flush stdout;
  let _ = input_line stdin in
  ()

let search_partners ?(showtrace = false) (r, other_rays, bans) candidates :
  star list =
  let open Out_channel in
  let print_string = output_string stdout in
  if showtrace then begin
    print_string
    @@ Printf.sprintf "select state: >>%s<< %s" (string_of_ray r)
         (string_of_raylist other_rays);
    pause ()
  end;
  let rec select_ray ~queue other_stars repl1 repl2 s : star list =
    match s.content with
    | [] -> []
    | r' :: s' when not (is_polarised r') ->
      select_ray ~queue:(r' :: queue) other_stars repl1 repl2
        { content = s'; bans }
    | r' :: s' -> (
      if showtrace then begin
        print_string
        @@ Printf.sprintf "  try action: >>%s<< %s..." (string_of_ray r')
             (string_of_raylist s')
      end;
      let next =
        select_ray ~queue:(r' :: queue) other_stars repl1 repl2
          { content = s'; bans }
      in
      match raymatcher (repl1 r) (repl2 r') with
      | None ->
        if showtrace then print_string "failed.";
        next
      (* if there is an actual connection between rays *)
      | Some theta ->
        ( try apply_effect r theta
          with e ->
            string_of_exn e |> Out_channel.output_string Out_channel.stderr;
            Stdlib.exit (-1) );
        if showtrace then begin
          print_string
          @@ Printf.sprintf "success with %s." (string_of_subst theta)
        end;
        if showtrace then pause ();
        let other_rays' = queue @ s' in
        let after_fusion =
          fusion repl1 repl2 other_rays other_rays' bans s.bans theta
        in
        let all_coherent =
          List.for_all ~f:(fun (b1, b2) -> not @@ equal_ray b1 b2)
        in
        let res =
          if all_coherent after_fusion.bans then begin
            if showtrace then begin
              print_string
              @@ Printf.sprintf "  add star %s." (string_of_star after_fusion)
            end;
            after_fusion :: next
          end
          else begin
            if showtrace then begin
              print_string
              @@ Printf.sprintf "  result filtered out by constraint."
            end;
            next
          end
        in
        if showtrace then pause ();
        ident_counter := !ident_counter + 2;
        res )
  in
  let repl1 = replace_indices !ident_counter in
  selections candidates
  |> List.concat_map ~f:(fun (s, cs) ->
       let repl2 = replace_indices (!ident_counter + 1) in
       select_ray ~queue:[] cs repl1 repl2 s )

let interaction ?(showtrace = false) (actions : star list) (states : star list)
  : constellation option =
  let rec select_ray states' ~queue s ~bans =
    match s with
    | [] -> None
    | r :: rs when not (is_polarised r) ->
      select_ray states' ~queue:(r :: queue) rs ~bans
    | r :: rs -> begin
      match search_partners ~showtrace (r, queue @ rs, bans) actions with
      | [] -> select_ray states' ~queue:(r :: queue) rs ~bans
      | new_stars -> Some new_stars
    end
  in
  let rec select_star ~queue = function
    | [] -> None
    | s :: states' -> begin
      match select_ray states' ~queue:[] s.content ~bans:s.bans with
      | None -> select_star ~queue:(s :: queue) states'
      | Some new_stars -> Some (List.rev queue @ states' @ new_stars)
    end
  in
  select_star ~queue:[] states

let string_of_configuration (actions, states) : string =
  Printf.sprintf ">> actions: %s\n>> states: %s\n"
    (string_of_constellation actions)
    (string_of_constellation states)

let exec ?(showtrace = false) mcs =
  let open Out_channel in
  let print_string = output_string stdout in
  let rec aux (actions, states) =
    if showtrace then begin
      print_string @@ string_of_configuration (actions, states);
      pause ()
    end;
    begin
      match interaction ~showtrace actions states with
      | None -> states
      | Some result' -> aux (actions, result')
    end
  in
  let actions, states = extract_intspace mcs in
  if showtrace then print_string @@ Printf.sprintf "\n>> starting trace...\n";
  let res = aux (actions, states) in
  if showtrace then begin
    print_string @@ Printf.sprintf ">> end trace.\n";
    pause ()
  end;
  res
