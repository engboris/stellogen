(** Constellation types and operations.

    This module defines the core data structures for stellar resolution: rays
    (polarized terms), stars (collections of rays), and constellations
    (collections of stars). *)

(** {1 Polarity} *)

(** Ray polarity: positive (provides), negative (requests), or neutral *)
type polarity =
  | Pos  (** Positive polarity - provides/offers *)
  | Neg  (** Negative polarity - requests/demands *)
  | Null  (** Neutral - does not interact *)

val equal_polarity : polarity -> polarity -> bool

(** {1 Signature Modules} *)

(** Signature for stellar rays (polarity-aware compatibility) *)
module StellarSig : sig
  type idvar = string * int option

  type idfunc = polarity * string

  val string_of_idvar : idvar -> string

  val equal_idvar : idvar -> idvar -> bool

  val equal_idfunc : idfunc -> idfunc -> bool

  val compatible : idfunc -> idfunc -> bool
end

(** {1 Unification Modules} *)

(** Stellar rays with polarity-aware unification *)
module StellarRays : module type of Unification.Make (StellarSig)

(** {1 Core Types} *)

(** A ray is a term (from StellarRays) *)
type ray = StellarRays.term

val equal_ray : ray -> ray -> bool

(** Constraints on stars *)
type ban =
  | Ineq of ray * ray  (** Inequality constraint *)
  | Incomp of ray * ray  (** Incompatibility constraint *)

val equal_ban : ban -> ban -> bool

(** {1 Raw Stars and Constellations} *)

(** Unmarked (raw) stars and constellations *)
module Raw : sig
  (** A star is a collection of rays with optional constraints *)
  type star =
    { content : ray list
    ; bans : ban list
    }

  val equal_star : star -> star -> bool

  (** A constellation is a collection of stars *)
  type constellation = star list

  val equal_constellation : constellation -> constellation -> bool
end

(** {1 Marked Stars and Constellations} *)

(** Stars marked as either state (to be transformed) or action (rules), each
    independently tagged consumable (linear) or reusable. *)
module Marked : sig
  (** A marked star is either a state or an action; the bool tracks whether it
      is consumable (used at most once per execution). *)
  type star =
    | State of Raw.star * bool
      (** State stars are transformed during execution *)
    | Action of Raw.star * bool  (** Action stars define transformation rules *)

  val equal_star : star -> star -> bool

  (** A marked constellation *)
  type constellation = star list

  val equal_constellation : constellation -> constellation -> bool

  (** Map a function over the rays in a star *)
  val map : f:(ray -> ray) -> star -> star

  (** Create a non-linear action star from a raw star *)
  val make_action : Raw.star -> star

  (** Create a non-linear state star from a raw star *)
  val make_state : Raw.star -> star

  (** Mark all raw stars as non-linear actions *)
  val make_action_all : Raw.constellation -> constellation

  (** Mark all raw stars as non-linear states *)
  val make_state_all : Raw.constellation -> constellation

  (** Remove marking (both State/Action and linear) from a star *)
  val remove : star -> Raw.star

  (** Remove marking from all stars *)
  val remove_all : constellation -> Raw.constellation

  (** Whether a star is consumable (linear) *)
  val is_linear : star -> bool

  (** Set the linear flag, preserving the State/Action tag and content *)
  val set_linear : bool -> star -> star

  (** Set the linear flag on every star, preserving each one's State/Action tag
  *)
  val set_linear_all : bool -> constellation -> constellation

  (** Force State, preserving each star's existing linear flag *)
  val refocus : star -> star

  (** [refocus] applied to every star *)
  val refocus_all : constellation -> constellation

  (** Normalize: remove marking and re-mark all as non-linear actions *)
  val normalize_all : constellation -> constellation
end

(** {1 Utilities} *)

(** Generate a fresh placeholder string (for anonymous variables) *)
val fresh_placeholder : unit -> string

(** {1 Term Constructors} *)

(** Create a variable term with no index *)
val to_var : string -> ray

(** Create a function term from polarity-symbol pair and arguments *)
val to_func : StellarSig.idfunc * ray list -> ray

(** Create a positive polarity symbol *)
val pos : string -> StellarSig.idfunc

(** Create a negative polarity symbol *)
val neg : string -> StellarSig.idfunc

(** Create a neutral polarity symbol *)
val null : string -> StellarSig.idfunc

(** Create a function term with given polarity *)
val gfunc : StellarSig.idfunc -> ray list -> ray

(** Create a positive function term *)
val pfunc : string -> ray list -> ray

(** Create a negative function term *)
val nfunc : string -> ray list -> ray

(** Create a neutral function term *)
val func : string -> ray list -> ray

(** Create a variable *)
val var : StellarSig.idvar -> ray

(** Create a positive constant (0-arity function) *)
val pconst : string -> ray

(** Create a negative constant *)
val nconst : string -> ray

(** Create a neutral constant *)
val const : string -> ray

(** {1 Ray Operations} *)

(** Check if a ray has polarity (Pos or Neg) *)
val is_polarised : ray -> bool

(** Replace variable indices in a ray *)
val replace_indices : int -> ray -> ray

(** Rename each distinct variable of the given rays to a fresh index
    starting at the given base. Injective on variables: same-named
    variables with different indices stay distinct. Returns the
    renaming and the number of indices consumed. *)
val injective_renaming : int -> ray list -> (ray -> ray) * int

(** Try to match two polarized rays, returning substitution if successful *)
val raymatcher : ray -> ray -> StellarRays.substitution option

(** Base observation for [~=]: structural unifiability, ignoring polarity *)
val terms_unifiable : ray -> ray -> bool

(** Find a fresh variable not in the given list *)
val fresh_var : StellarSig.idvar list -> StellarSig.idvar

(** {1 Constellation Operations} *)

(** Apply a substitution to all rays in a marked constellation *)
val subst_all_vars :
  StellarRays.substitution -> Marked.constellation -> Marked.constellation

(** Collect all variables from a marked constellation *)
val all_vars : Marked.constellation -> StellarSig.idvar list

(** Normalize variable names in a constellation *)
val normalize_vars : Marked.constellation -> Marked.constellation
