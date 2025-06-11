open Base

module type Signature = sig
  type idvar

  type idfunc

  val equal_idvar : idvar -> idvar -> bool

  val equal_idfunc : idfunc -> idfunc -> bool

  val compatible : idfunc -> idfunc -> bool
end

(* ---------------------------------------
   Elementary definitions
   --------------------------------------- *)

module Make (Sig : Signature) = struct
  type fmark =
    | Noisy
    | Muted

  type term =
    | Var of Sig.idvar
    | Func of (fmark * Sig.idfunc) * term list

  let equal_mark m m' =
    match (m, m') with Noisy, Noisy | Muted, Muted -> true | _ -> false

  let equal_func (m, f) (m', f') = equal_mark m m' && Sig.equal_idfunc f f'

  let rec equal_term t u =
    match (t, u) with
    | Var x, Var y -> Sig.equal_idvar x y
    | Func ((Muted, f), ts), Func ((Muted, g), us)
    | Func ((Noisy, f), ts), Func ((Noisy, g), us) -> begin
      try
        Sig.equal_idfunc f g
        && List.for_all2_exn ~f:(fun t u -> equal_term t u) ts us
      with _ -> false
    end
    | _ -> false

  type substitution = (Sig.idvar * term) list

  type equation = term * term

  type problem = equation list

  let rec fold fnode fbase acc = function
    | Var x -> fbase x acc
    | Func (f, ts) ->
      let acc' = fnode f acc in
      List.fold ts ~init:acc' ~f:(fold fnode fbase)

  let rec map fnode fbase = function
    | Var x -> fbase x
    | Func (g, ts) -> Func (fnode g, List.map ~f:(map fnode fbase) ts)

  let skip = fun _ acc -> acc

  let exists_var pred = fold skip (fun y acc -> pred y || acc) false

  let for_all_var pred = fold skip (fun y acc -> pred y && acc) true

  let exists_func pred = fold (fun y acc -> pred y || acc) skip false

  let for_all_func pred = fold (fun y acc -> pred y && acc) skip true

  let occurs x = exists_var (fun y -> Sig.equal_idvar x y)

  let vars = fold skip List.cons []

  let apply sub x =
    match List.Assoc.find sub ~equal:Sig.equal_idvar x with
    | None -> Var x
    | Some t -> t

  let subst sub = map Fn.id (apply sub)

  let replace_func from_pf to_pf =
    map (fun pf -> if equal_func pf from_pf then to_pf else pf) (fun x -> Var x)

  let replace_funcs fsub t =
    List.fold_left fsub ~init:t ~f:(fun acc (from_pf, to_pf) ->
      replace_func from_pf to_pf acc )

  (* ---------------------------------------
   A few useful functions
   --------------------------------------- *)

  let lift_pairl f (x, y) = (f x, y)

  let lift_pairr f (x, y) = (x, f y)

  let lift_pair f p = p |> lift_pairl f |> lift_pairr f

  (* ---------------------------------------
   Unification algorithm
   --------------------------------------- *)

  let extract_idfuncs ts =
    List.fold_left
      ~f:(fun acc x -> match x with Var _ -> acc | Func (f, _) -> f :: acc)
      ~init:[] ts
    |> List.rev

  let signals = ref []

  (* FIXME: doesn't work as expected *)
  let emit_signals sub =
    let new_signals = List.map ~f:(fun (_, t) -> t) sub in
    signals := new_signals @ !signals

  let rec solve sub : problem -> substitution option = function
    | [] -> Some sub
    (* Clear *)
    | (Var x, Var y) :: pbs when Sig.equal_idvar x y -> solve sub pbs
    (* Orient + Replace *)
    | (Var x, t) :: pbs | (t, Var x) :: pbs -> elim x t pbs sub
    (* Open *)
    | (Func ((m, f), ts), Func ((m', g), us)) :: pbs
      when equal_mark m m' && Sig.compatible f g
           && List.length ts = List.length us -> begin
      match solve sub (List.zip_exn ts us @ pbs) with
      | None -> None
      | Some s -> begin
        match m with
        | Noisy ->
          emit_signals s;
          Some s
        | _ -> Some s
      end
    end
    | _ -> None

  (* Replace *)
  and elim x t pbs sub : substitution option =
    if occurs x t then None (* Circularity *)
    else
      let new_prob = List.map ~f:(lift_pair (subst [ (x, t) ])) pbs in
      let new_sub = (x, t) :: List.map ~f:(lift_pairr (subst [ (x, t) ])) sub in
      solve new_sub new_prob

  let solution : problem -> substitution option = solve []
end
