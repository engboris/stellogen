(** Generic unification algorithm based on Robinson's algorithm.

    This module provides a functor that creates a unification engine for any
    term language defined by a signature. *)

(** Signature for term identifiers *)
module type Signature = sig
  (** Type of variable identifiers *)
  type idvar

  (** Type of function symbol identifiers *)
  type idfunc

  (** Equality test for variables *)
  val equal_idvar : idvar -> idvar -> bool

  (** Equality test for function symbols *)
  val equal_idfunc : idfunc -> idfunc -> bool

  (** Compatibility test for function symbols (for unification) *)
  val compatible : idfunc -> idfunc -> bool
end

(** Functor to create a unification module for a given signature *)
module Make (Sig : Signature) : sig
  (** Terms are either variables or function applications *)
  type term =
    | Var of Sig.idvar
    | Func of Sig.idfunc * term list

  val equal_term : term -> term -> bool

  (** A substitution maps variables to terms *)
  type substitution = (Sig.idvar * term) list

  (** An equation is a pair of terms to unify *)
  type equation = term * term

  (** A unification problem is a list of equations *)
  type problem = equation list

  (** {2 Term Operations} *)

  (** Fold over a term structure *)
  val fold :
    (Sig.idfunc -> 'a -> 'a) -> (Sig.idvar -> 'a -> 'a) -> 'a -> term -> 'a

  (** Map over a term structure *)
  val map : (Sig.idfunc -> Sig.idfunc) -> (Sig.idvar -> term) -> term -> term

  (** Check if a variable occurs in a term *)
  val exists_var : (Sig.idvar -> bool) -> term -> bool

  (** Check if a function symbol occurs in a term *)
  val exists_func : (Sig.idfunc -> bool) -> term -> bool

  (** Check if variable x occurs in term t (for occurs check) *)
  val occurs : Sig.idvar -> term -> bool

  (** Collect all variables in a term *)
  val vars : term -> Sig.idvar list

  (** Apply a substitution to a variable *)
  val apply : substitution -> Sig.idvar -> term

  (** Apply a substitution to a term *)
  val subst : substitution -> term -> term

  (** {2 Unification} *)

  (** Solve a unification problem, returning a most general unifier if one
      exists *)
  val solution : problem -> substitution option
end
