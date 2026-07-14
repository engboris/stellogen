(** Stellogen expression evaluator.

    This module provides the main evaluation functions for Stellogen programs,
    converting high-level expressions into constellation interactions. *)

open Syntax

(** {1 Term Conversion} *)

(** Convert a marked constellation to a term representation *)
val term_of_constellation :
  Constellation.Marked.constellation -> Constellation.StellarRays.term

(** Convert a term back to a marked constellation *)
val constellation_of_term :
  Constellation.StellarRays.term -> Constellation.Marked.constellation

(** {1 Output} *)

(** Where [show] writes its output. Defaults to printing on stdout; the web
    playground redirects it to its output buffer. *)
val show_printer : (string -> unit) ref

(** {1 Error Formatting} *)

(** Format an error for display, returning the formatted string or an error *)
val pp_err : err -> (string, err) Result.t

(** {1 Phases} *)

(** Whether an item takes part in the given phase: [Shared] items always do,
    [CheckOnly]/[RunOnly] items only in their own phase *)
val phase_active : phase -> item_phase -> bool

(** Names bound by a program item, used to record what a phase skipped without
    evaluating anything *)
val skipped_def_names : sgen_expr -> ident list

(** {1 Expression Evaluation} *)

(** Evaluate a single Stellogen expression in an environment. Returns the
    updated environment and the result term. [trace_cfg], when given, routes
    every [exec] inside the expression through that trace session. [phase]
    (default [Run]) selects which items imports evaluate and words phase-aware
    lookup errors. *)
val eval_sgen_expr :
     ?trace_cfg:Tracer.trace_config option
  -> ?phase:phase
  -> env
  -> sgen_expr
  -> (env * Constellation.StellarRays.term, err) Result.t

(** {1 Program Evaluation} *)

(** Evaluate a complete program starting from the initial environment, in the
    run phase. Prints errors to stderr and returns the final environment. *)
val eval_program : program -> (env, err) Result.t

(** Evaluate a program with a custom initial environment. Does not print errors;
    returns them in the Result. [trace_cfg] and [phase] behave as in
    {!eval_sgen_expr}; items outside the active phase are skipped. *)
val eval_program_internal :
     ?trace_cfg:Tracer.trace_config option
  -> ?phase:phase
  -> env
  -> program
  -> (env, err) Result.t

(** Evaluate the check phase of a program, collecting assertion failures per
    top-level item instead of stopping at the first one. Structural errors
    (unknown identifiers, import failures) still stop evaluation. Does not
    print; returns the collected errors in file order. *)
val eval_program_check : program -> env * err list
