# Interaction Sequence Language (ISL) for JIT Debugging

**Status:** Design Document
**Date:** 2025-10-31
**Purpose:** Design an intermediate language that exposes Stellogen's execution as explicit sequences of basic interactions, enabling advanced debugging features like rewind, alternative execution paths, and detailed introspection.

---

## Table of Contents

1. [Motivation](#motivation)
2. [The Core Insight](#the-core-insight)
3. [Current Execution Model](#current-execution-model)
4. [ISL Design Philosophy](#isl-design-philosophy)
5. [ISL Operations](#isl-operations)
6. [JIT Compilation Strategy](#jit-compilation-strategy)
7. [Debugging Capabilities](#debugging-capabilities)
8. [Implementation Roadmap](#implementation-roadmap)
9. [Comparison with Previous Work](#comparison-with-previous-work)
10. [Examples](#examples)

---

## Motivation

### Problem: Current Trace Command Limitations

The existing `trace` command (in `bin/sgen.ml` and `src/sgen_eval.ml`) provides basic debugging by showing each interaction step, but has significant limitations:

**What trace provides:**
- Step-by-step display of interactions
- Shows which rays are selected
- Displays unification substitutions
- Source location information

**What trace cannot do:**
- **No rewind**: Can't go backward through execution
- **No branching**: Can't explore alternative execution paths
- **No conditional breakpoints**: Stops at every step or none
- **No state modification**: Can't test "what if" scenarios
- **Interactive only**: Requires manual keypresses for each step
- **Fixed granularity**: One step per interaction attempt
- **No replay**: Can't save and replay execution traces
- **Limited analysis**: Can't detect patterns or cycles programmatically

### Vision: True Debugging via ISL

By compiling Stellogen expressions just-in-time to an **Interaction Sequence Language (ISL)**, we can:

1. **Record execution** as a sequence of explicit operations
2. **Step forward and backward** through interactions
3. **Branch execution** to explore alternatives
4. **Set sophisticated breakpoints** (conditional, data-dependent)
5. **Analyze execution patterns** (detect infinite loops, visualize interaction graphs)
6. **Modify state** mid-execution for experimentation
7. **Replay and analyze** traces offline
8. **Generate execution reports** (profiling, coverage, interaction statistics)

---

## The Core Insight

### Execution = Scheduling Basic Interactions

At its core, Stellogen execution is remarkably simple:

```
LOOP:
  1. Select a state star (from @-focused stars)
  2. Select a ray within that star (skip neutral rays)
  3. Search for a matching action star (opposite polarity + unifiable)
  4. If match found:
     a. Compute unification substitution (θ)
     b. Apply θ to both stars' remaining rays
     c. Merge into new star
     d. Check constraint coherence
     e. Replace state star with merged star
  5. Repeat until no more interactions possible (saturation)
```

**Key observation:** This loop involves only a handful of **primitive operations**:
- `select_star` — pick a state star
- `select_ray` — pick a ray from a star
- `search_partners` — find matching action stars
- `raymatcher` — check polarity compatibility and unify
- `fusion` — merge two stars after successful match
- `coherent_bans` — verify inequality constraints

### ISL Makes Scheduling Explicit

The current OCaml implementation **interprets** this loop directly. ISL **compiles** it into explicit instructions:

```
SELECT_STATE 0 → star₀
SELECT_RAY star₀ 0 → ray₀
SEARCH_PARTNERS ray₀ actions → [action₁, action₃]
RAYMATCH ray₀ action₁.ray₀ → θ₁
IF_SUCCESS:
  FUSION star₀ action₁ θ₁ → star₀'
  CHECK_COHERENCE star₀' → ok
  REPLACE_STATE 0 star₀'
CONTINUE
```

By making these operations **explicit sequential instructions**, we gain:
- **Observability**: Every decision is visible
- **Controllability**: Can pause, rewind, modify at any point
- **Analyzability**: Can detect patterns, optimize, profile
- **Debuggability**: Full control over execution flow

---

## Current Execution Model

### Triple-Nested Loop Structure

The current execution model (from `lsc_eval.ml`) has three nested loops:

```ocaml
let rec exec ?(linear = false) ?(trace = None) mcs : constellation =
  let rec loop (actions, states) =
    match select_star ~linear ~trace ~queue:[] actions states with
    | None, _ -> states  (* Saturation reached *)
    | Some res, new_actions -> loop (new_actions, res)
  in
  let cfg = extract_intspace mcs in  (* Separate actions from states *)
  loop cfg

and select_star ~linear ~trace ~queue actions states =
  (* Loop 1: Iterate through state stars *)
  List.fold_until states ~init:(queue, actions) ~f:(fun acc state_star ->
    match select_ray ~linear ~trace state_star actions with
    | Some (new_star, new_actions) ->
        Continue_or_stop.Stop (Some (new_star :: other_stars, new_actions))
    | None -> Continue_or_stop.Continue acc
  ) ~finish:(fun _ -> (None, actions))

and select_ray ~linear ~trace state_star actions =
  (* Loop 2: Iterate through rays in state_star *)
  List.fold_until state_star.rays ~init:None ~f:(fun _ ray ->
    if not (is_polarised ray) then Continue_or_stop.Continue None
    else
      match search_partners ~linear ~trace ray actions with
      | Some result -> Continue_or_stop.Stop (Some result)
      | None -> Continue_or_stop.Continue None
  ) ~finish:(fun x -> x)

and search_partners ~linear ~trace ray actions =
  (* Loop 3: Iterate through action stars *)
  List.fold_until actions ~init:None ~f:(fun _ action_star ->
    match interaction ray action_star with
    | Some fused_star ->
        if coherent_bans fused_star.bans then
          let new_actions = if linear then remove action_star actions else actions in
          Continue_or_stop.Stop (Some (fused_star, new_actions))
        else Continue_or_stop.Continue None
    | None -> Continue_or_stop.Continue None
  ) ~finish:(fun x -> x)
```

### The Basic Primitives

**From `lsc_ast.ml` and `lsc_eval.ml`:**

1. **`raymatcher : ray -> ray -> substitution option`**
   - Checks polarity compatibility
   - Attempts unification
   - Returns substitution or None

2. **`fusion : star -> star -> substitution -> star`**
   - Merges two stars after successful match
   - Applies substitution to remaining rays
   - Combines inequality constraints

3. **`coherent_bans : ban list -> bool`**
   - Validates inequality constraints
   - Ensures no contradictions

4. **`is_polarised : ray -> bool`**
   - Checks if ray has + or - polarity

5. **`extract_intspace : marked_constellation -> (actions, states)`**
   - Separates constellation into actions (no `@`) and states (`@`)

### What's Implicit vs Explicit

**Currently implicit:**
- Which state star to select first
- Which ray within a star to try first
- Which action star to try first when multiple match
- When to stop searching (first match)
- Loop termination condition (no more interactions)

**ISL makes explicit:**
- Every selection decision
- Every matching attempt
- Every fusion operation
- Every coherence check
- The entire control flow

---

## ISL Design Philosophy

### Goals

1. **Simple**: Few instruction types, easy to understand
2. **Explicit**: All scheduling decisions are visible
3. **Sequential**: Linear instruction stream (not a tree/graph)
4. **Reversible**: Can step backward as easily as forward
5. **Stateful**: Maintains constellation state at each step
6. **Debuggable**: Every instruction has clear semantics for inspection

### Non-Goals

This is **not** a general compilation target (use BIM for that). ISL is specifically for:
- Debugging Stellogen expressions
- Understanding execution behavior
- Experimenting with execution strategies

Performance is secondary—clarity and debuggability are primary.

### Comparison to BIM

The old document proposed a **Basic Interaction Machine (BIM)** as a comprehensive abstract machine for Stellogen compilation. ISL differs:

| Aspect | BIM | ISL |
|--------|-----|-----|
| **Purpose** | General compilation target | Debugging intermediate language |
| **Scope** | Full language (constellations, env, etc.) | Just execution loop (exec/fire) |
| **Design** | Abstract machine (heap, stack, registers) | Sequential operations log |
| **Optimization** | Register allocation, inlining, etc. | None—clarity over performance |
| **Usage** | Compile once, execute many times | Compile JIT for debugging session |
| **Reversibility** | Not a design goal | Core requirement |

**ISL is simpler and more focused than BIM.**

---

## ISL Operations

### Design Principle: Mirror the Current Implementation

ISL instructions directly correspond to the operations in `lsc_eval.ml`:

### 1. State Management

```
CLASSIFY constellation → (actions, states)
  Separate constellation into action stars and state stars
  Based on @ focus marker

GET_STATES → states
  Return current list of state stars

GET_ACTIONS → actions
  Return current list of action stars

SET_STATES states
  Replace current state stars

SET_ACTIONS actions
  Replace current action stars
```

### 2. Selection Operations

```
SELECT_STATE index → star | NONE
  Select state star at given index
  Returns NONE if index out of bounds

SELECT_RAY star index → ray | NONE
  Select ray at given index in star
  Skip if ray is neutral (unpolarised)
  Returns NONE if index out of bounds or ray neutral

SEARCH_PARTNERS ray actions → [matches]
  Find all action stars that can interact with ray
  Returns list of (action_star, matching_ray_index) pairs
```

### 3. Matching & Fusion

```
RAYMATCH ray1 ray2 → substitution | FAIL
  Check polarity compatibility
  Attempt unification
  Returns substitution or FAIL

FUSION star1 star2 substitution → star
  Merge two stars according to substitution
  Remove matched rays
  Combine remaining rays
  Merge inequality constraints

CHECK_COHERENCE star → OK | FAIL
  Verify inequality constraints are satisfiable
  Returns OK or FAIL
```

### 4. State Transformation

```
REPLACE_STATE index new_star
  Replace state star at index with new_star

REMOVE_ACTION index
  Remove action star at index (for linear/fire mode)
```

### 5. Control Flow

```
IF_SUCCESS label
  Jump to label if last operation succeeded

IF_FAIL label
  Jump to label if last operation failed

JUMP label
  Unconditional jump

HALT
  Stop execution, return current states
```

### 6. Debugging Annotations

```
MARK step_number source_location
  Annotate following instructions with debugging info

CHECKPOINT name
  Save current state for later restoration

RESTORE name
  Restore state from checkpoint
```

---

## JIT Compilation Strategy

### When to Compile

Compile Stellogen expressions to ISL **just-in-time** when:
1. User runs `trace` command (replace current trace)
2. User starts debugging session
3. User requests execution analysis

**Not compiled:**
- Regular `exec` or `fire` operations (use interpreter for performance)
- Production code
- Non-debugging contexts

### Compilation Process

```
Stellogen Expression
     ↓
[Parser] → AST
     ↓
[Evaluator] → Marked Constellation (actions + @states)
     ↓
[ISL Compiler] → ISL Instruction Sequence
     ↓
[ISL Interpreter/Debugger] → Results + Trace
```

### Example: Compiling `exec`

**Input:**
```stellogen
(def add {
  [(+add 0 Y Y)]
  [(-add X Y Z) (+add (s X) Y (s Z))]})

(exec #add @[(-add (s (s 0)) (s (s 0)) R) R])
```

**Compiled ISL:**

```
; Initialize
CLASSIFY constellation_add_query → (actions, states)
  ; actions = {[(+add 0 Y Y)], [(-add X Y Z) (+add (s X) Y (s Z))]}
  ; states = {[(-add (s (s 0)) (s (s 0)) R) R]}

; Main loop
LOOP_START:

; Step 1: Try to find an interaction
SELECT_STATE 0 → state₀
IF_FAIL HALT  ; No more states → saturation reached

; Step 2: Try each ray in the state
SELECT_RAY state₀ 0 → ray₀
IF_FAIL LOOP_START  ; No more polarised rays, try next state

; Step 3: Search for matching actions
SEARCH_PARTNERS ray₀ actions → matches
IF_FAIL LOOP_START  ; No match, try next ray

; Step 4: Try first match
GET_MATCH matches 0 → (action₀, ray_idx)
RAYMATCH ray₀ action₀[ray_idx] → θ
IF_FAIL TRY_NEXT_MATCH

; Step 5: Fusion
FUSION state₀ action₀ θ → new_star
CHECK_COHERENCE new_star → result
IF_FAIL TRY_NEXT_MATCH

; Step 6: Update state
REPLACE_STATE 0 new_star
JUMP LOOP_START

TRY_NEXT_MATCH:
  ; Try next match in list
  ...

HALT:
  GET_STATES → final_result
  RETURN final_result
```

### ISL Optimization (Optional)

While performance isn't the goal, some simple optimizations help:

1. **Index matching rays**: Pre-compute which action stars have compatible ray signatures
2. **Skip known failures**: Cache failed match attempts
3. **Prune dead branches**: Remove states with no polarised rays

But keep these **optional and transparent** for debugging.

---

## Debugging Capabilities

### What ISL Enables

#### 1. Forward & Backward Stepping

```
[Debugger] Step forward:
  Execute next ISL instruction
  Update state

[Debugger] Step backward:
  Undo last ISL instruction
  Restore previous state
```

**Implementation:** Keep a stack of states after each instruction. Stepping backward = pop stack.

#### 2. Breakpoints

**Instruction breakpoints:**
```
Break on FUSION instruction
Break on RAYMATCH when X unifies with 0
Break on SELECT_STATE when selecting specific star
```

**State breakpoints:**
```
Break when constellation contains specific pattern
Break when variable X becomes bound
Break when interaction count exceeds N
```

**Source breakpoints:**
```
Break at file.sg:5:10 (mapped via MARK annotations)
```

#### 3. State Inspection

At any point, examine:
- Current state stars and action stars
- Variable bindings in current substitution
- Interaction queue (which stars are candidates)
- Constraint bans and their coherence
- Source location (via MARK annotations)

#### 4. Execution Branching

```
[Debugger] Current state: SEARCH_PARTNERS found 3 matches
[Debugger] Show matches:
  1. [(+add 0 Y Y)]
  2. [(-add X Y Z) (+add (s X) Y (s Z))]
  3. [(+add (s 0) Z W)]

[Debugger] Fork execution:
  Branch A: Try match 1
  Branch B: Try match 2
  Branch C: Try match 3

[Debugger] Compare final states
```

**Implementation:** Create checkpoint before branching, restore for each branch.

#### 5. Alternative Execution Strategies

By exposing selection as explicit instructions, we can experiment:

```
; Default: depth-first, try first state
SELECT_STATE 0

; Alternative: breadth-first, round-robin
SELECT_STATE next_in_round_robin()

; Alternative: random exploration
SELECT_STATE random()

; Alternative: heuristic-based
SELECT_STATE smallest_ray_count()
```

#### 6. Execution Analysis

**Cycle detection:**
```
[Debugger] Detecting patterns...
  States: [S₁ → S₂ → S₃ → S₁]
  Warning: Cycle detected at step 47
  Pattern: (-loop X) → (+loop X) → (-loop X)
```

**Interaction statistics:**
```
[Debugger] Execution report:
  Total steps: 127
  Fusions: 43
  Failed matches: 84
  Most active action star: [(-add X Y Z) ...]
  Hottest ray: (-add ... )
```

**Coverage:**
```
[Debugger] Coverage report:
  Stars never used:
    - [(+unused X)]
  Rays never matched:
    - (+corner_case Y) in star 5
```

#### 7. Time-Travel Debugging

```
[Debugger] Save execution trace to file
[Debugger] Load trace from file
[Debugger] Jump to step 47
[Debugger] Set state to checkpoint "before_fusion_3"
[Debugger] Replay with different strategy
```

---

## Implementation Roadmap

### Phase 1: ISL Specification (2 weeks)

**Deliverables:**
1. Formal ISL instruction set (this document)
2. ISL abstract syntax in OCaml
3. Pretty-printer for ISL instructions
4. Simple test cases

**Code:**
```ocaml
(* src/isl_ast.ml *)
type isl_instruction =
  | Classify of constellation
  | SelectState of int
  | SelectRay of star * int
  | SearchPartners of ray * constellation
  | RayMatch of ray * ray
  | Fusion of star * star * substitution
  | CheckCoherence of star
  | ReplaceState of int * star
  | RemoveAction of int
  | IfSuccess of label
  | IfFail of label
  | Jump of label
  | Halt
  | Mark of step_number * source_location
  | Checkpoint of string
  | Restore of string

type isl_program = {
  instructions: isl_instruction list;
  labels: (label * int) list;
}
```

### Phase 2: Compiler (4 weeks)

**Deliverable:** Compiler from Stellogen `exec`/`fire` to ISL

**Key functions:**
```ocaml
(* src/isl_compiler.ml *)
val compile_exec : constellation -> isl_program
  (* Compile exec into ISL instruction sequence *)

val compile_fire : constellation -> isl_program
  (* Compile fire into ISL instruction sequence *)
  (* Difference: insert REMOVE_ACTION after each fusion *)

val add_debug_marks : isl_program -> source_map -> isl_program
  (* Annotate with MARK instructions for source mapping *)
```

**Algorithm:** Walk through the nested loop structure and emit ISL instructions.

### Phase 3: Interpreter with Checkpointing (3 weeks)

**Deliverable:** ISL interpreter that can step forward/backward

**Key features:**
- Execute ISL instructions
- Maintain state stack for rewind
- Support checkpoints
- Track source locations

**Code:**
```ocaml
(* src/isl_interp.ml *)
type isl_state = {
  actions: constellation;
  states: constellation;
  registers: register_file;
  pc: int;  (* Program counter *)
  history: isl_state list;  (* For rewind *)
  checkpoints: (string * isl_state) list;
}

val step_forward : isl_program -> isl_state -> isl_state
val step_backward : isl_state -> isl_state
val execute : isl_program -> isl_state -> isl_state (* Run to completion *)
val execute_until : isl_program -> isl_state -> breakpoint -> isl_state
```

### Phase 4: Debugger Interface (4 weeks)

**Deliverable:** Replace current `trace` command with ISL-based debugger

**User interface:**
```
$ sgen debug program.sg

[ISL Debugger]
Step 1 at program.sg:5:3
  [Instruction] SELECT_STATE 0 → star₀
  [State] [(-add (s (s 0)) (s (s 0)) R) R]

(isl-debug) step
Step 2 at program.sg:5:3
  [Instruction] SELECT_RAY star₀ 0 → (-add (s (s 0)) (s (s 0)) R)

(isl-debug) break FUSION
Breakpoint set on FUSION instructions

(isl-debug) continue
...
Breakpoint hit at step 5
  [Instruction] FUSION star₀ action₁ θ → star₀'

(isl-debug) inspect star₀'
star₀' = [(+add (s 0) (s (s 0)) (s R))]

(isl-debug) back
Stepped back to step 4

(isl-debug) inspect θ
θ = {X ↦ (s (s 0)), Y ↦ (s (s 0)), Z ↦ R}

(isl-debug) history
  Step 1: SELECT_STATE 0
  Step 2: SELECT_RAY star₀ 0
  Step 3: SEARCH_PARTNERS ray₀ actions → [action₁]
  Step 4: RAYMATCH ray₀ action₁.ray₀ → θ
  Step 5: FUSION star₀ action₁ θ → star₀'  ← current
```

**Commands:**
- `step` / `s` — step forward
- `back` / `b` — step backward
- `continue` / `c` — run until breakpoint/end
- `break <condition>` — set breakpoint
- `inspect <expr>` — examine value
- `history` — show execution history
- `checkpoint <name>` — save state
- `restore <name>` — restore state
- `fork` — explore alternative execution paths
- `diff <state1> <state2>` — compare states

### Phase 5: Analysis Tools (3 weeks)

**Deliverables:**
1. Cycle detector
2. Coverage analyzer
3. Interaction profiler
4. Execution trace export (JSON format)

**Usage:**
```bash
$ sgen debug --analyze program.sg

[Analysis Report]
✓ No infinite loops detected
✓ All action stars were used
! Star [(+corner_case X)] matched 0 times
! Ray (+error_handling Y) never fired

Interaction statistics:
  Total interactions: 127
  Most active star: [(-add X Y Z) ...] (43 times)
  Average fusion depth: 3.2

Execution trace saved to: trace_20251031_143022.json
```

### Phase 6: Integration (2 weeks)

**Deliverable:** Seamless integration with existing tooling

1. Replace `trace` command with ISL debugger
2. Add `--isl` flag to `sgen` for ISL output
3. VS Code extension integration (DAP protocol)
4. Documentation and examples

---

## Comparison with Previous Work

### What Happened to BIM?

The old document (`docs/compilation_and_abstract_machines.md`) proposed a **Basic Interaction Machine (BIM)**—a comprehensive abstract machine for compiling Stellogen.

**Why not BIM?**

BIM is still a good idea for **general compilation** (performance, optimization, portability). However:

1. **BIM is complex**: Heap management, registers, full instruction set
2. **BIM is for compilation**: Not designed for debugging
3. **BIM lacks reversibility**: Hard to step backward through native/bytecode
4. **BIM is overkill for debugging**: We don't need full compilation infrastructure

### ISL vs BIM: Complementary, Not Competing

```
┌─────────────────────────────────────┐
│   Stellogen Source Code             │
└──────────────┬──────────────────────┘
               │
         ┌─────┴──────┐
         │            │
         ↓            ↓
    [Evaluator]  [ISL Compiler]
         │            │
         │            ↓
         │      ISL Program
         │            │
         │            ↓
         │    ISL Debugger
         │     (debugging)
         │
         ↓
  [BIM Compiler]
         │
         ↓
   BIM Bytecode
         │
         ↓
   BIM Runtime
   (production)
```

**Use ISL when:** Developing, debugging, understanding behavior
**Use BIM when:** Deploying, optimizing, targeting multiple platforms

### ISL is Simpler

| Feature | BIM | ISL |
|---------|-----|-----|
| **Instructions** | ~30 instructions | ~15 instructions |
| **Memory model** | Heap + Stack + Registers | Just constellation state |
| **Compilation** | Full program → bytecode | Just exec loop → sequence |
| **Execution** | Bytecode VM | Interpreter with history |
| **Optimization** | Register allocation, inlining | None (clarity over speed) |
| **Reversibility** | Not a goal | Core feature |

**ISL is "just enough" for debugging—nothing more.**

---

## Examples

### Example 1: Simple Addition

**Stellogen:**
```stellogen
(def add {
  [(+add 0 Y Y)]
  [(-add X Y Z) (+add (s X) Y (s Z))]})

(exec #add @[(-add (s 0) (s 0) R) R])
```

**Compiled ISL (simplified):**

```
0:  CLASSIFY add_and_query → (actions, states)
1:  MARK step:1 loc:"add.sg:5:1"

; Main loop
2:  SELECT_STATE 0 → state₀
3:  IF_FAIL 15  ; Jump to HALT if no states

4:  SELECT_RAY state₀ 0 → ray₀
5:  IF_FAIL 2  ; Try next state if no rays

6:  SEARCH_PARTNERS ray₀ actions → matches
7:  IF_FAIL 2  ; Try next ray if no partners

8:  GET_MATCH matches 0 → (action₀, 0)
9:  RAYMATCH ray₀ action₀[0] → θ
10: IF_FAIL 2

11: FUSION state₀ action₀ θ → new_star
12: CHECK_COHERENCE new_star → ok
13: IF_FAIL 2

14: REPLACE_STATE 0 new_star
15: JUMP 2

16: HALT
```

**Execution trace:**

```
Step 1: [CLASSIFY] → actions={A₀, A₁}, states={S₀}
  where A₀ = [(+add 0 Y Y)]
        A₁ = [(-add X Y Z) (+add (s X) Y (s Z))]
        S₀ = [(-add (s 0) (s 0) R) R]

Step 2: [SELECT_STATE 0] → S₀
Step 3: [SELECT_RAY S₀ 0] → (-add (s 0) (s 0) R)
Step 4: [SEARCH_PARTNERS] → [A₁]
Step 5: [RAYMATCH ray₀ A₁.ray₀] → θ = {X ↦ (s 0), Y ↦ (s 0), Z ↦ R}
Step 6: [FUSION S₀ A₁ θ] → S₀' = [(+add 0 (s 0) R') R] where R = (s R')
Step 7: [CHECK_COHERENCE S₀'] → ok
Step 8: [REPLACE_STATE 0 S₀']

Step 9: [SELECT_STATE 0] → S₀'
Step 10: [SELECT_RAY S₀' 0] → (+add 0 (s 0) R')
Step 11: [SEARCH_PARTNERS] → [A₀]
Step 12: [RAYMATCH] → θ' = {Y ↦ (s 0), R' ↦ (s 0)}
Step 13: [FUSION] → S₀'' = [(s (s 0))]  ; R = (s (s 0))
Step 14: [REPLACE_STATE 0 S₀'']

Step 15: [SELECT_STATE 0] → S₀''
Step 16: [SELECT_RAY S₀'' 0] → (s (s 0))  ; unpolarised
Step 17: [IF_FAIL] → HALT

Result: R = (s (s 0))
```

### Example 2: Debugging with Rewind

```
[Debugger] Starting execution...

Step 5: RAYMATCH successful
  θ = {X ↦ (s 0), Y ↦ (s 0), Z ↦ R}

(debug) Wait, let me check X before fusion
(debug) back
Step 4: SEARCH_PARTNERS → [A₁]

(debug) back
Step 3: SELECT_RAY S₀ 0 → (-add (s 0) (s 0) R)

(debug) inspect S₀
S₀ = [(-add (s 0) (s 0) R) R]

(debug) Good, now continue forward
(debug) step
Step 4: SEARCH_PARTNERS → [A₁]

(debug) step
Step 5: RAYMATCH → θ = {X ↦ (s 0), Y ↦ (s 0), Z ↦ R}

(debug) inspect θ[X]
θ[X] = (s 0)

(debug) Perfect! Continue
(debug) continue
...
```

### Example 3: Exploring Alternative Executions

**Scenario:** Multiple action stars match, want to see all possibilities

```
Step 6: SEARCH_PARTNERS → [A₁, A₂, A₃]

(debug) checkpoint "before_choice"
Checkpoint saved: before_choice

(debug) continue  ; Uses A₁ by default
...
Result: R = (s (s 0))

(debug) restore "before_choice"
Restored to step 6

(debug) set_match_strategy "try_A₂"
(debug) continue
...
Result: R = (s (s (s 0)))  ; Different result!

(debug) restore "before_choice"
(debug) set_match_strategy "try_A₃"
(debug) continue
...
Result: FAIL (no coherence)

(debug) compare_results
  Strategy A₁: R = (s (s 0))
  Strategy A₂: R = (s (s (s 0)))
  Strategy A₃: FAIL
```

---

## Conclusion

### Summary

**The Interaction Sequence Language (ISL)** is a simple, sequential intermediate language that exposes Stellogen's execution as explicit instructions. By compiling `exec`/`fire` operations to ISL just-in-time during debugging sessions, we enable:

1. **Rewind**: Step backward through execution
2. **Breakpoints**: Sophisticated conditional breakpoints
3. **Inspection**: Deep state introspection at any point
4. **Branching**: Explore alternative execution paths
5. **Analysis**: Detect cycles, profile interactions, measure coverage
6. **Time-travel**: Save and replay execution traces

### Why ISL?

- **Simpler than BIM**: Focused on debugging, not general compilation
- **Explicit**: Makes scheduling decisions visible and controllable
- **Reversible**: Designed for backward stepping from the start
- **Practical**: Replaces `trace` with much more powerful tool
- **Incremental**: Can be implemented phase-by-phase

### Next Steps

1. **Implement ISL specification** (Phase 1)
2. **Build compiler** from exec/fire to ISL (Phase 2)
3. **Create interpreter** with checkpointing (Phase 3)
4. **Replace trace command** with ISL debugger (Phase 4)
5. **Add analysis tools** (Phase 5)
6. **Integrate with tooling** (Phase 6)

### Relationship to BIM

ISL and BIM are **complementary**:
- ISL for **debugging** (development-time)
- BIM for **compilation** (deployment-time)

Both expose Stellogen's execution, but with different priorities:
- ISL: clarity, reversibility, introspection
- BIM: performance, optimization, portability

### Final Thought

> "The current trace shows you what happened.
> ISL lets you control what happens."

By making execution **explicit and controllable**, ISL transforms debugging from passive observation to active exploration. This is the foundation for truly understanding and mastering Stellogen programs.

---

**Document Version:** 1.0
**Last Updated:** 2025-10-31
**Author:** Design for Interaction Sequence Language for advanced Stellogen debugging
