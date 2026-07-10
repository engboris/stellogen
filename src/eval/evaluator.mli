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

(** {1 Error Formatting} *)

(** Format an error for display, returning the formatted string or an error *)
val pp_err : err -> (string, err) Result.t

(** {1 Expression Evaluation} *)

(** Evaluate a single Stellogen expression in an environment. Returns the
    updated environment and the result term. [trace_cfg], when given, routes
    every [exec] inside the expression through that trace session. *)
val eval_sgen_expr :
     ?trace_cfg:Tracer.trace_config option
  -> env
  -> sgen_expr
  -> (env * Constellation.StellarRays.term, err) Result.t

(** {1 Program Evaluation} *)

(** Evaluate a complete program starting from the initial environment. Prints
    errors to stderr and returns the final environment. *)
val eval_program : program -> (env, err) Result.t

(** Evaluate a program with a custom initial environment. Does not print errors;
    returns them in the Result. [trace_cfg] behaves as in {!eval_sgen_expr}. *)
val eval_program_internal :
  ?trace_cfg:Tracer.trace_config option -> env -> program -> (env, err) Result.t
