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
  type term =
    | Var of Sig.idvar
    | Func of Sig.idfunc * term list
  [@@deriving eq]

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

  let skip _ acc = acc

  let exists_var pred = fold skip (fun y acc -> pred y || acc) false

  let exists_func pred = fold (fun y acc -> pred y || acc) skip false

  let occurs x = exists_var (fun y -> Sig.equal_idvar x y)

  let vars = fold skip List.cons []

  let apply sub x =
    match List.Assoc.find sub ~equal:Sig.equal_idvar x with
    | None -> Var x
    | Some t -> t

  let subst sub = map Fn.id (apply sub)

  (* ---------------------------------------
   Unification algorithm
   --------------------------------------- *)

  let map_snd f (x, y) = (x, f y)

  let map_pair f (x, y) = (f x, f y)

  let rec solve sub : problem -> substitution option = function
    | [] -> Some sub
    (* Clear *)
    | (Var x, Var y) :: pbs when Sig.equal_idvar x y -> solve sub pbs
    (* Orient + Replace *)
    | (Var x, t) :: pbs | (t, Var x) :: pbs -> elim x t pbs sub
    (* Open *)
    | (Func (f, ts), Func (g, us)) :: pbs when Sig.compatible f g -> (
      match List.zip ts us with
      | Ok zipped -> solve sub (zipped @ pbs)
      | Unequal_lengths -> None )
    | _ -> None

  (* Replace *)
  and elim x t pbs sub : substitution option =
    if occurs x t then None (* Circularity *)
    else
      let new_prob = List.map ~f:(map_pair (subst [ (x, t) ])) pbs in
      let new_sub = (x, t) :: List.map ~f:(map_snd (subst [ (x, t) ])) sub in
      solve new_sub new_prob

  let solution : problem -> substitution option = solve []
end
