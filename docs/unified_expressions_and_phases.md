# Unified Expressions and Phases: Removing the Declaration/Expression Distinction

> **Disclaimer**: This document was written with the assistance of Claude Code and represents exploratory research and analysis. The content may contain inaccuracies or misinterpretations and should not be taken as definitive statements about the Stellogen language implementation.

**Status:** Research Document / Design Proposal
**Date:** 2025-10-12
**Purpose:** Explore the idea that macros are essentially compile-time `:=` definitions, and that the separation between declarations and expressions may be superficial. Propose a unified model based on phased evaluation.

**Related Documents:**
- [Import Mechanisms](import_mechanisms.md) - How macros are currently handled
- [Phasing and Type Checking](phasing_and_type_checking.md) - Multi-phase execution model

---

## Table of Contents

1. [The Key Insight](#the-key-insight)
2. [Current Architecture Analysis](#current-architecture-analysis)
3. [The Artificial Separation](#the-artificial-separation)
4. [Toward a Unified Model](#toward-a-unified-model)
5. [Phased Evaluation as the Foundation](#phased-evaluation-as-the-foundation)
6. [Concrete Design Proposal](#concrete-design-proposal)
7. [Implications and Benefits](#implications-and-benefits)
8. [Migration Path](#migration-path)
9. [Comparison with Other Languages](#comparison-with-other-languages)
10. [Open Questions](#open-questions)
11. [Conclusion](#conclusion)

---

## The Key Insight

### Macros Are Compile-Time Definitions

Consider the parallel between these two forms:

```stellogen
' Runtime definition
(:= add {
  [(+add 0 Y Y)]
  [(-add X Y Z) (+add (s X) Y (s Z))]})

' Compile-time "definition" (macro)
(macro (spec X Y) (:= X Y))
```

**Key observation:** Both are binding a name to a computational structure:
- `add` is bound to a constellation (runtime)
- `spec` is bound to an expansion template (compile-time)

The **only difference** is WHEN they execute:
- Runtime definitions execute during program evaluation
- Macros execute during preprocessing/macro expansion

**The insight:** Macros are just `:=` definitions that happen to run at an earlier phase.

### Declarations vs Expressions: An Artificial Distinction?

Currently, Stellogen has two separate categories in its AST:

```ocaml
(* From src/sgen_ast.ml *)

(* Expressions - computational structures *)
type sgen_expr =
  | Raw of Marked.constellation
  | Call of ray
  | Focus of sgen_expr
  | Group of sgen_expr list
  | (* ... *)

(* Declarations - top-level forms *)
type declaration =
  | Def of ray * sgen_expr
  | Show of sgen_expr
  | Expect of sgen_expr * sgen_expr * ray * source_location option
  | Use of ray
```

**Question:** Is this distinction fundamental, or is it an artifact of the implementation?

**Observation:** Every declaration could be represented as an expression:
- `(Def id expr)` → `(:= id expr)` is just a special form
- `(Show expr)` → `(show expr)` is just a function call
- `(Expect e1 e2 ...)` → `(== e1 e2)` is just a function call
- `(Use path)` → `(use path)` is just a function call

The distinction between "declaration" and "expression" may be **superficial**—a matter of how we organize code, not a fundamental semantic difference.

---

## Current Architecture Analysis

### The Three-Layer Architecture

Currently, Stellogen has three distinct processing layers:

```
Layer 1: Preprocessing (Compile-time)
├─ Syntactic expansion (desugar syntax)
├─ Macro expansion (unfold_decl_def)
└─ Output: Expanded expressions

Layer 2: Conversion
├─ Convert expressions to declarations
└─ Output: Program (declaration list)

Layer 3: Evaluation (Runtime)
├─ Execute declarations
├─ Build environment
└─ Output: Results
```

### The Macro Environment Problem

From the import mechanisms analysis:

```ocaml
(* src/expr.ml:302 *)
let preprocess e = e |> List.map ~f:expand_macro |> unfold_decl_def []
                                                                      ^^
                                                      Empty macro environment!
```

**Issue:** Macros are stored in a temporary environment during preprocessing:
```ocaml
type macro_env = (string * (string list * expr list)) list
```

After preprocessing:
- Macros are **discarded**
- Only expanded expressions survive
- Runtime environment has no knowledge of macros

**Why this causes problems:**
1. Can't import macros from other files
2. Can't define macros at runtime
3. Can't introspect or manipulate macros
4. Artificial boundary between "compile-time" and "runtime"

### The Declaration Type

The `declaration` type serves two purposes:

1. **Organizational:** Top-level forms in a program
2. **Semantic:** Different evaluation strategies

**Examples:**
```stellogen
(:= add ...)     → Def: Binds identifier to value
(show x)         → Show: Performs I/O
(== x y)         → Expect: Assertion/test
(use "file.sg")  → Use: Imports file
```

**Question:** Do these really need a separate type, or are they just special expressions evaluated in a special way?

### The Current Duplication

Consider type checking macros:

```stellogen
' Macro definition (compile-time)
(macro (spec X Y) (:= X Y))

' Runtime definition
(:= nat {
  [(-nat 0) ok]
  [(-nat (s N)) (+nat N)]})
```

Both use similar syntax:
- Pattern matching on arguments: `(spec X Y)` vs `[(-nat (s N)) ...]`
- Body: `(:= X Y)` vs nested constellation structure
- Binding: `spec` is bound in macro env, `nat` is bound in runtime env

**The duplication suggests:** These could be unified under a single mechanism.

---

## The Artificial Separation

### Why Separate Declarations and Expressions?

Historical reasons from traditional language design:

1. **C/Pascal tradition:** Declarations (type/variable defs) vs statements (code)
2. **ML tradition:** Top-level declarations vs expressions
3. **Implementation convenience:** Easier to have separate phases

But in Stellogen:
- No types (logic-agnostic)
- Everything is term interaction
- No fundamental semantic difference

### What If Everything Were an Expression?

**Radical idea:** Eliminate the `declaration` type entirely.

```ocaml
(* Instead of two types *)
type declaration = Def of ... | Show of ... | Expect of ... | Use of ...
type sgen_expr = Raw of ... | Call of ... | Focus of ... | ...

(* Have only one type *)
type expr =
  | Raw of constellation
  | Call of ray
  | Focus of expr
  | Define of ray * expr      (* was Def declaration *)
  | Show of expr              (* was Show declaration *)
  | Assert of expr * expr     (* was Expect declaration *)
  | Import of ray             (* was Use declaration *)
  | (* ... existing expression forms ... *)
```

**Key change:** `:=`, `show`, `==`, `use` are just special forms, not a separate category.

### What If Macros Were Runtime Constructs?

**Another radical idea:** Don't discard macros after preprocessing.

```stellogen
' Define a macro at any phase
@phase:preprocessing
(:= spec (macro (X Y)
  (:= X Y)))

@phase:runtime
(:= my-type (call-macro #spec my-type-body))
```

**Key change:** Macros are first-class values that can be:
- Defined at any phase
- Passed around
- Called/expanded on demand
- Introspected

This is how **Racket** works:
```racket
; Macros are just functions that transform syntax
(define-syntax my-macro
  (lambda (stx)
    (syntax-case stx ()
      [(my-macro x) #'(expanded x)])))
```

---

## Toward a Unified Model

### Principle 1: Everything Is an Expression

No distinction between "declarations" and "expressions"—everything is evaluated uniformly:

```stellogen
' These are all expressions:
42
(+nat 0)
(:= zero (+nat 0))
(show #zero)
(== x y)
(use "file.sg")
(macro (spec X Y) (:= X Y))
```

Some expressions have **side effects**:
- `:=` adds binding to environment
- `show` performs I/O
- `==` checks assertion
- `use` loads file
- `macro` adds macro to environment

But they're all expressions that evaluate to values and potentially modify the environment.

### Principle 2: Phases Determine When

Instead of having different types for compile-time vs runtime, use **phase annotations**:

```stellogen
' Preprocessing phase (what we currently call "compile-time")
@phase:preprocessing {
  (:= spec (macro (X Y)
    (:= X Y)))

  (:= desugar-cons (macro ([H | T])
    (cons H T)))
}

' Evaluation phase (what we currently call "runtime")
@phase:evaluation {
  (:= nat {
    [(-nat 0) ok]
    [(-nat (s N)) (+nat N)]})

  (show (interact #nat ...))
}
```

**Key insight:** The WHEN is separate from the WHAT.

### Principle 3: Uniform Binding Mechanism

Use `:=` for all bindings, regardless of phase:

```stellogen
' Compile-time binding (macro)
@phase:preprocessing
(:= spec (macro (X Y) (:= X Y)))

' Runtime binding (constellation)
@phase:evaluation
(:= nat { ... })

' Type-checking binding (type definition)
@phase:type-check
(:= nat-type (type-checker { ... }))
```

All use the same `:=` operator. The phase determines which environment they bind to.

### Principle 4: First-Class Macros

Macros are values, not meta-constructs:

```stellogen
' Define a macro
@phase:preprocessing
(:= my-macro (macro (X)
  (transform X)))

' Pass macro as argument
@phase:preprocessing
(:= apply-macro (fn [M Arg]
  (expand M Arg)))

(:= result (apply-macro #my-macro some-expr))

' Introspect macro
@phase:preprocessing
(:= macro-body (get-body #my-macro))
(show "Macro has" (count-params #my-macro) "parameters")
```

This enables **powerful metaprogramming** while maintaining simplicity.

---

## Phased Evaluation as the Foundation

### The Core Idea

Instead of having "preprocessing" and "evaluation" as separate phases with different semantics, have a **single evaluation mechanism** that runs at different phases:

```
Phase 0: Preprocessing/Macro Expansion
  - Evaluate expressions marked @phase:preprocessing
  - Build preprocessing environment (includes macros)
  - Generate expanded code

Phase 1: Type Checking (optional)
  - Evaluate expressions marked @phase:type-check
  - Build type environment
  - Verify type constraints

Phase 2: Static Analysis (optional)
  - Evaluate expressions marked @phase:analysis
  - Run user-defined analyses
  - Report results

Phase 3: Evaluation/Runtime
  - Evaluate expressions marked @phase:evaluation (or unmarked)
  - Build runtime environment
  - Produce final results
```

**Key change:** Same evaluation function `eval : expr -> env -> (value * env)` runs at every phase, just with different environments and different source expressions.

### Unified Environment

Instead of separate environments for macros, types, and runtime values:

```ocaml
(* Current - multiple environments *)
type macro_env = (string * (string list * expr list)) list
type type_env = (string * type_spec) list
type runtime_env = { objs : (ident * sgen_expr) list }

(* Unified - single environment *)
type env = {
  bindings : (ident * value) list;
  phase : phase;
}

type value =
  | Constellation of Marked.constellation
  | Macro of (string list * expr)          (* macro is just a value *)
  | Type of type_spec                      (* type is just a value *)
  | ComputedResult of Marked.constellation  (* result is just a value *)
```

**Every binding is just `(name, value)` pair**—no special handling for different kinds of bindings.

### Phase-Aware Evaluation

```ocaml
let rec eval (expr : expr) (env : env) : (value * env, error) result =
  match expr with
  | Symbol s -> lookup env s
  | List es -> eval_list es env

  (* Define - works at any phase *)
  | Define (name, body) ->
      let* val = eval body env in
      let env' = add_binding env name val in
      Ok (val, env')

  (* Macro definition - just another value *)
  | MacroDef (params, body) ->
      Ok (Macro (params, body), env)

  (* Macro call - expand and eval *)
  | Call (Macro (params, body), args) when env.phase = Preprocessing ->
      let* expanded = expand_macro params body args in
      eval expanded env

  (* Show - I/O side effect *)
  | Show e ->
      let* val = eval e env in
      print_value val;
      Ok (val, env)

  (* ... other forms ... *)
```

**Key point:** Same `eval` function, same semantics, different phases just change the environment and available operations.

### Macro Expansion as Evaluation

Currently, macro expansion is a separate pass:

```ocaml
(* Current *)
let preprocess e = e |> List.map ~f:expand_macro |> unfold_decl_def []
```

**Proposed:** Macro expansion is just evaluation at the preprocessing phase:

```ocaml
(* Proposed *)
let preprocess exprs =
  (* Extract preprocessing phase expressions *)
  let prep_exprs = exprs |> filter_by_phase Preprocessing in

  (* Evaluate at preprocessing phase *)
  let* (values, prep_env) = eval_program prep_exprs initial_env in

  (* The "expanded code" is what's left over for next phase *)
  let expanded = exprs |> remove_phase Preprocessing in
  Ok (expanded, prep_env)
```

**Key change:** "Macro expansion" is just "evaluation at preprocessing phase".

---

## Concrete Design Proposal

### Unified AST

```ocaml
(* Single expression type *)
type expr =
  (* Literals *)
  | Symbol of string
  | Var of ident

  (* Constellation *)
  | Constellation of Marked.constellation

  (* Function application *)
  | Apply of expr * expr list

  (* Special forms that used to be "declarations" *)
  | Define of ident * expr           (* := *)
  | Show of expr                     (* show *)
  | Assert of expr * expr            (* == *)
  | Import of string                 (* use *)

  (* Macro-related *)
  | Macro of string list * expr      (* macro definition *)
  | MacroCall of ident * expr list   (* macro invocation *)

  (* Phase annotation *)
  | Phase of phase * expr list       (* @phase:name { ... } *)

  (* Focus and call *)
  | Focus of expr                    (* @ *)
  | Call of expr                     (* # *)

  (* Control structures *)
  | Sequence of expr list            (* do multiple things *)
  | Let of (ident * expr) list * expr  (* local bindings *)

(* Phase labels *)
type phase =
  | Preprocessing
  | TypeCheck
  | Analysis
  | Optimization
  | Evaluation
  | UserDefined of string
```

### Unified Value Type

```ocaml
type value =
  | Constellation of Marked.constellation
  | Macro of (string list * expr)
  | Function of (value list -> value)
  | String of string
  | Number of int
  | List of value list
  (* All values are treated uniformly *)
```

### Unified Environment

```ocaml
type env = {
  phase : phase;
  bindings : (ident * value) list;
  parent : env option;  (* for nested scopes *)
}

let empty_env phase = { phase; bindings = []; parent = None }

let add_binding env name value =
  { env with bindings = (name, value) :: env.bindings }

let lookup env name =
  match List.assoc env.bindings name with
  | Some v -> Ok v
  | None ->
      match env.parent with
      | Some parent -> lookup parent name
      | None -> Error (UnboundIdentifier name)
```

### Unified Evaluation Function

```ocaml
let rec eval (expr : expr) (env : env) : (value * env, error) result =
  match expr with

  (* Define - works at any phase *)
  | Define (name, body) ->
      let* val = eval body env in
      let env' = add_binding env name val in
      Ok (val, env')

  (* Macro definition *)
  | Macro (params, body) ->
      Ok (Macro (params, body), env)

  (* Macro call - expand if in preprocessing phase *)
  | MacroCall (name, args) ->
      let* macro_val = lookup env name in
      (match macro_val, env.phase with
      | Macro (params, body), Preprocessing ->
          (* Expand macro *)
          let* expanded = substitute params args body in
          eval expanded env
      | Macro _, _ ->
          (* Not in preprocessing phase - error or treat as value *)
          Error (MacroCallOutsidePreprocessing name)
      | _ ->
          Error (NotAMacro name))

  (* Apply *)
  | Apply (fn_expr, arg_exprs) ->
      let* fn = eval fn_expr env in
      let* args = List.map (fun e -> eval e env) arg_exprs |> Result.all in
      (match fn with
      | Function f -> Ok (f args, env)
      | Constellation c -> eval_constellation_apply c args env
      | _ -> Error (NotApplicable fn))

  (* Show *)
  | Show e ->
      let* val = eval e env in
      print_value val;
      Ok (val, env)

  (* Assert *)
  | Assert (e1, e2) ->
      let* v1 = eval e1 env in
      let* v2 = eval e2 env in
      if equal_value v1 v2 then
        Ok (v1, env)
      else
        Error (AssertionFailed (v1, v2))

  (* Import *)
  | Import path ->
      let* imported_env = load_and_eval_file path env.phase in
      let env' = merge_env env imported_env in
      Ok (Unit, env')

  (* Phase block *)
  | Phase (phase, exprs) ->
      let env' = { env with phase } in
      eval_sequence exprs env'

  (* Other forms... *)
  | Focus e ->
      let* val = eval e env in
      Ok (evaluate_to_normal_form val, env)

  | Call e ->
      let* val = eval e env in
      Ok (dereference val env, env)

  | Sequence exprs ->
      eval_sequence exprs env

  | Let (bindings, body) ->
      let* env' = eval_bindings bindings env in
      eval body env'

and eval_sequence exprs env =
  List.fold_left exprs ~init:(Ok (Unit, env)) ~f:(fun acc expr ->
    let* (_, env') = acc in
    eval expr env')

and eval_bindings bindings env =
  List.fold_left bindings ~init:(Ok env) ~f:(fun acc (name, expr) ->
    let* env' = acc in
    let* val = eval expr env' in
    Ok (add_binding env' name val))
```

### Multi-Phase Execution

```ocaml
let eval_program (program : expr list) : (env, error) result =
  (* Extract expressions by phase *)
  let phases = [Preprocessing; TypeCheck; Analysis; Evaluation] in

  let rec eval_phases phases env =
    match phases with
    | [] -> Ok env
    | phase :: rest ->
        (* Extract expressions for this phase *)
        let phase_exprs = extract_phase_exprs program phase in

        (* Evaluate at this phase *)
        let env' = { env with phase } in
        let* (_, env'') = eval_sequence phase_exprs env' in

        (* Continue to next phase *)
        eval_phases rest env''
  in

  eval_phases phases (empty_env Preprocessing)

let extract_phase_exprs (program : expr list) (phase : phase) : expr list =
  List.filter_map program ~f:(function
    | Phase (p, exprs) when p = phase -> Some exprs
    | Phase _ -> None
    | expr -> if phase = Evaluation then Some [expr] else None)
  |> List.concat
```

### Syntax Examples

**Simple case:**

```stellogen
' Everything is just expressions
(:= zero (+nat 0))
(show #zero)
```

**With phases:**

```stellogen
@phase:preprocessing {
  ' Define macro
  (:= spec (macro (X Y)
    (:= X Y)))

  ' Use macro
  (spec nat {
    [(-nat 0) ok]
    [(-nat (s N)) (+nat N)]})
}

@phase:evaluation {
  (:= zero (+nat 0))
  (show #zero)
}
```

**Macro as first-class value:**

```stellogen
@phase:preprocessing {
  ' Define a macro
  (:= my-macro (macro (X) (transform X)))

  ' Pass macro to function
  (:= apply-to-all (fn [M Items]
    (map (fn [I] (M I)) Items)))

  ' Use it
  (:= results (apply-to-all #my-macro [expr1 expr2 expr3]))
}
```

**Import macros naturally:**

```stellogen
@phase:preprocessing {
  ' Import file at preprocessing phase
  (import "lib/macros.sg")

  ' Macros from imported file are now available
  (use-imported-macro ...)
}
```

---

## Implications and Benefits

### 1. Unified Semantics

**Before:** Different rules for declarations vs expressions, compile-time vs runtime.

**After:** One simple rule: evaluate expressions in an environment at a phase.

```stellogen
' Same semantics everywhere
@phase:preprocessing
(:= spec (macro ...))    ' Binds in preprocessing env

@phase:evaluation
(:= nat { ... })         ' Binds in evaluation env

' Both use same := operator, same evaluation rules
```

### 2. First-Class Macros

Macros can be:
- Passed as arguments
- Returned from functions
- Stored in data structures
- Introspected
- Generated dynamically

```stellogen
@phase:preprocessing {
  ' Generate macro programmatically
  (:= make-accessor (fn [Field]
    (macro ([Obj])
      (get-field Obj Field))))

  ' Create accessors
  (:= get-name (make-accessor 'name))
  (:= get-age (make-accessor 'age))
}
```

### 3. Natural Macro Import

No special mechanism needed—just import at the right phase:

```stellogen
@phase:preprocessing {
  (import "lib/macros.sg")
}

' Macros are available because they were imported at preprocessing phase
```

### 4. User-Defined Phases

Users can define custom phases for custom purposes:

```stellogen
@phase:type-check {
  (:: zero nat)
}

@phase:optimize {
  (inline small-functions)
  (fuse-constellations)
}

@phase:generate-docs {
  (extract-documentation my-module)
}
```

All use the same evaluation mechanism, just at different phases.

### 5. Simpler Implementation

**Before:**
- Parse → AST (expr)
- Preprocess (special macro expansion logic)
- Convert to declarations
- Evaluate declarations (different from expressions)

**After:**
- Parse → AST (expr)
- Evaluate at phase 0 (preprocessing)
- Evaluate at phase 1 (type checking)
- Evaluate at phase 2 (runtime)

Same `eval` function throughout.

### 6. More Powerful Metaprogramming

Can write macros that:
- Inspect other macros
- Generate macros
- Transform macros
- Compose macros

```stellogen
@phase:preprocessing {
  ' Macro that generates macros
  (:= defmacro-set (fn [Names Bodies]
    (map (fn [[N B]] (macro N B))
         (zip Names Bodies))))

  ' Use it
  (:= my-macros (defmacro-set
    ['mac1 'mac2]
    [body1 body2]))
}
```

### 7. Cleaner Architecture

No artificial boundaries:
- No separate `declaration` type
- No separate preprocessing pass with different semantics
- No special-case logic for imports
- One evaluation model, used everywhere

### 8. Easier to Understand

For users:
- "Everything is an expression"
- "Phases determine when it runs"
- "`:=` binds names to values at any phase"

No need to understand:
- Difference between declarations and expressions
- Why macros are special
- Why imports don't work for macros
- Complex preprocessing rules

---

## Migration Path

### Phase 1: Internal Unification

Keep external syntax the same, but unify internally:

```ocaml
(* Internal: single expr type *)
type expr = Define of ... | Show of ... | Macro of ... | ...

(* External: keep parsing both forms for compatibility *)
let parse_declaration = function
  | "(:=" :: rest -> Define (parse_rest rest)
  | "(show" :: rest -> Show (parse_rest rest)
  (* Map old syntax to new internal representation *)
```

### Phase 2: Add Phase Annotations

Introduce `@phase:name` syntax:

```stellogen
' Old syntax still works
(macro (spec X Y) (:= X Y))
(:= nat { ... })

' New syntax available
@phase:preprocessing
(:= spec (macro (X Y) (:= X Y)))

@phase:evaluation
(:= nat { ... })
```

### Phase 3: Unify Evaluation

Make macros first-class in preprocessing phase:

```stellogen
@phase:preprocessing {
  ' Macros are just values
  (:= my-macro (macro (X) (transform X)))

  ' Can be imported naturally
  (import "macros.sg")
}
```

### Phase 4: Deprecate Old Syntax

Eventually, move fully to unified syntax:

```stellogen
' Everything uses same syntax
@phase:preprocessing
(:= spec (macro (X Y) (:= X Y)))

@phase:evaluation
(:= nat { ... })
```

---

## Comparison with Other Languages

### Racket

**Racket** already has a unified model:

```racket
; Macros are just syntax transformers
(define-syntax my-macro
  (syntax-rules ()
    [(my-macro x) (transform x)]))

; Functions are values
(define (my-function x) (+ x 1))

; Both are first-class, both can be imported
```

**Stellogen (proposed)** is similar:
```stellogen
@phase:preprocessing
(:= my-macro (macro (X) (transform X)))

@phase:evaluation
(:= my-function (fn [X] (+ X 1)))
```

### Lisp

**Common Lisp** has:
- Macros as transformers: `(defmacro name (args) body)`
- Functions as values: `(defun name (args) body)`
- Both can be imported via packages

**Stellogen (proposed)** would be similar but with explicit phases.

### MetaML/MetaOCaml

**MetaML** has staging with brackets:

```ocaml
let power n = .< fun x -> ~(power_body n) >.
```

**Stellogen (proposed)** has phases:

```stellogen
@phase:compile-time
(:= power-gen (fn [N] (generate-power N)))

@phase:runtime
(:= power-3 (power-gen 3))
```

### Comparison Table

| Feature | Racket | Common Lisp | MetaML | Stellogen (Proposed) |
|---------|--------|-------------|--------|----------------------|
| **Unified model** | Yes | Partial | Yes | Yes |
| **First-class macros** | Yes | Yes | N/A | Yes |
| **Explicit phases** | Yes (automatic) | No | Yes | Yes |
| **Phase control** | Limited | eval-when | Explicit | Explicit |
| **Import works** | Yes | Yes | Yes | Yes |

---

## Open Questions

### 1. Performance

**Question:** Does evaluating macros at runtime (even in a preprocessing phase) have performance implications?

**Consideration:**
- Currently, macro expansion is pure syntactic substitution (fast)
- With full evaluation, might be slower
- But: Can cache results, compile phases separately

### 2. Backwards Compatibility

**Question:** Can we maintain compatibility with existing `.sg` files?

**Options:**
- Parse old syntax, translate to new internal representation
- Support both syntaxes indefinitely
- Provide migration tool

### 3. Macro Hygiene

**Question:** How do we handle variable capture in first-class macros?

**Options:**
- Hygienic macros (Racket-style) - requires gensym and lexical scoping
- Unhygienic macros (traditional Lisp) - simpler but risk of capture
- Let user choose

### 4. Phase Propagation

**Question:** How do bindings propagate between phases?

**Current proposal:** Each phase starts with bindings from previous phases.

**Alternative:** Phases are isolated, must explicitly import.

### 5. Type of `macro`

**Question:** What is the type/value representation of a macro?

```stellogen
(:= my-macro (macro (X) (transform X)))
```

**Options:**
- `Macro of (string list * expr)` - simple, matches current model
- `Function of (expr list -> expr)` - first-class function on syntax
- Separate value type with special evaluation rules

### 6. Syntax for Phase Blocks

**Question:** What's the best syntax for phase blocks?

**Options:**
```stellogen
' Option 1: Block syntax
@phase:preprocessing {
  ...
}

' Option 2: Inline annotation
@phase:preprocessing (:= foo ...)

' Option 3: Named phases
(phase preprocessing
  ...)

' Option 4: Implicit (based on form)
(macro ...)  ' Automatically preprocessing phase
(:= ...)     ' Automatically evaluation phase
```

### 7. Error Handling Across Phases

**Question:** How do errors in one phase affect later phases?

**Options:**
- Fail fast: Error in phase N halts execution
- Continue: Collect errors, report all at end
- Partial: Try to continue if possible

### 8. Separate Compilation

**Question:** How do phases work with separate compilation of files?

**Consideration:**
- Each file might be compiled separately
- Preprocessing phase results need to be available when importing
- Need to serialize/deserialize preprocessed environments

---

## Conclusion

### Summary of Proposal

**Core idea:** Eliminate the artificial distinction between declarations and expressions, and between compile-time (macros) and runtime (definitions). Instead:

1. **Everything is an expression** - no separate `declaration` type
2. **`:=` works at any phase** - binds names to values uniformly
3. **Macros are first-class values** - can be passed, introspected, generated
4. **Phases determine when, not what** - same evaluation semantics at every phase
5. **Imports work naturally** - just import at the appropriate phase

### Key Insight

The current separation between:
- Declarations vs expressions
- Compile-time (macros) vs runtime (definitions)
- Preprocessing vs evaluation

...is **superficial and artificial**. It's an implementation artifact, not a fundamental semantic requirement.

**Macros are just `:=` definitions that run during preprocessing.** Once we recognize this, we can unify the entire language around a single evaluation model with multiple phases.

### Benefits

1. **Simpler implementation** - one evaluation function, one AST type
2. **Simpler mental model** - users only need to understand phases
3. **More powerful** - first-class macros enable better metaprogramming
4. **More consistent** - same rules everywhere
5. **Solves import problem** - imports work uniformly at all phases
6. **Enables extensibility** - users can define custom phases

### Alignment with Stellogen Philosophy

| Principle | Alignment |
|-----------|-----------|
| **Minimalism** | ✓ Fewer concepts (no declaration/expression split) |
| **Uniformity** | ✓ Same evaluation model everywhere |
| **Explicit control** | ✓ Phases are explicit, user-controlled |
| **Logic-agnostic** | ✓ Phases are a mechanism, not tied to any logic |
| **Elementary blocks** | ✓ Simple building blocks: expressions + phases |
| **User-driven** | ✓ Users control phases and define their own |

### Next Steps

1. **Prototype** the unified AST and evaluation function
2. **Test** with existing examples to verify equivalence
3. **Implement** phase system with preprocessing and evaluation phases
4. **Extend** to support user-defined phases
5. **Document** the new model with examples
6. **Migrate** existing code to new syntax (or support both)

### Final Thought

The separation between "declarations" and "expressions", between "macros" and "definitions", between "preprocessing" and "evaluation"—these are all **implementation details** that leaked into the language design.

By recognizing that **everything is just evaluation at different phases**, we can simplify Stellogen dramatically while making it more powerful.

**One mechanism (phased evaluation), infinite possibilities.**

---

## References

### Related Documents

- [Import Mechanisms](import_mechanisms.md) - Current macro import problem
- [Phasing and Type Checking](phasing_and_type_checking.md) - Multi-phase execution
- [Cut and Control Flow](cut_and_control_flow.md) - Stellogen's evaluation model

### Source Files

- `src/sgen_ast.ml` - Current declaration and expression types
- `src/expr.ml` - Current preprocessing and macro expansion
- `src/sgen_eval.ml` - Current evaluation of declarations

### Related Work

- **Racket**: Language-oriented programming with unified syntax/compile-time model
- **Scheme R6RS**: Phase separation in module system
- **Common Lisp**: Macros and eval-when
- **MetaML**: Multi-stage programming with explicit staging
- **Template Haskell**: Compile-time metaprogramming

---

**Document Version:** 1.0
**Last Updated:** 2025-10-12
**Author:** Exploration of unified expressions and phases in Stellogen
