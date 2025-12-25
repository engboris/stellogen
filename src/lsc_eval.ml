(*
 * lsc_eval.ml - Backwards compatibility wrapper
 *
 * This module re-exports functionality from lsc_exec and lsc_trace
 * to maintain backwards compatibility with existing code.
 *)

open Base
open Lsc_ast.Raw

(* Re-export source_location from lsc_trace *)
type source_location = Lsc_trace.source_location =
  { filename : string
  ; line : int
  ; column : int
  }

(* Trace configuration - adapts between old and new APIs *)
type trace_config =
  { enabled : bool
  ; mutable trace_state : Lsc_trace.trace_state option
  ; mutable current_location : source_location option
  }

let make_trace_config ?(web_mode = false) enabled =
  let mode =
    if web_mode then Lsc_trace.WebMode
    else if enabled then Lsc_trace.Interactive
    else Lsc_trace.Silent
  in
  { enabled
  ; trace_state = Some (Lsc_trace.create ~mode ())
  ; current_location = None
  }

let set_trace_location cfg loc =
  cfg.current_location <- loc;
  match cfg.trace_state with
  | Some state -> Lsc_trace.set_location state loc
  | None -> ()

let get_trace_steps cfg =
  match cfg.trace_state with Some state -> state.collected_steps | None -> []

let format_trace_steps_html steps =
  (* Create a temporary state to format *)
  let state = Lsc_trace.create ~mode:WebMode () in
  state.collected_steps <- steps;
  Lsc_trace.format_html state

(* Main execution function - delegates to lsc_exec *)
let exec ?(linear = false) ?(trace = None) mcs : constellation =
  match trace with
  | None -> Lsc_exec.exec ~linear mcs
  | Some cfg when cfg.enabled -> (
    match cfg.trace_state with
    | Some state ->
      (* Set location if available *)
      Option.iter cfg.current_location ~f:(fun loc ->
        Lsc_trace.set_location state (Some loc) );
      let handler = Lsc_trace.make_handler state in
      Lsc_exec.exec ~linear ~on_event:handler mcs
    | None -> Lsc_exec.exec ~linear mcs )
  | Some _ -> Lsc_exec.exec ~linear mcs
