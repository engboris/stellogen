# Import Mechanisms in Stellogen: Analysis and Improvements

**Status:** Research Document
**Date:** 2025-10-11
**Purpose:** Analyze the current file import mechanism and propose improvements for importing macros, particularly for creating a "MilkyWay" standard library

---

## Table of Contents

1. [Current State](#current-state)
2. [The Macro Import Problem](#the-macro-import-problem)
3. [Design Considerations](#design-considerations)
4. [Proposed Solutions](#proposed-solutions)
5. [Recommendation](#recommendation)
6. [Implementation Roadmap](#implementation-roadmap)
7. [References](#references)

---

## Current State

### How Imports Work

Stellogen supports file imports through the `use` expression:

```stellogen
(use "examples/automata.sg")
```

**Implementation:** `src/sgen_eval.ml:256-274`

When a `use` declaration is evaluated:

1. **File reading**: The file is opened and lexed
2. **Parsing**: Expressions are parsed into an AST
3. **Preprocessing**: Macros are expanded (with empty macro environment!)
4. **Conversion**: Expressions are converted to declarations
5. **Evaluation**: Declarations are evaluated, building a new runtime environment
6. **Return**: The new environment is returned

```ocaml
| Use path -> (
  (* ... read file into lexbuf ... *)
  let expr = Sgen_parsing.parse_with_error filename lexbuf in
  let preprocessed = Expr.preprocess expr in
  match Expr.program_of_expr preprocessed with
  | Ok program ->
      let* new_env = eval_program program in
      Ok new_env
  | Error expr_err -> Error (ExprError (expr_err, None)) )
```

### The Preprocessing Pipeline

**Implementation:** `src/expr.ml:302`

```ocaml
let preprocess e = e |> List.map ~f:expand_macro |> unfold_decl_def []
                                                                      ^^
                                                      Empty macro environment!
```

The preprocessing phase consists of two steps:

1. **Syntactic expansion** (`expand_macro`): Desugars syntax like `[1|Tail]`, `<f a b>`, `"string"` into core forms
2. **Macro expansion** (`unfold_decl_def`): Processes `new-declaration` forms and expands macro calls

### How Macros Work

**Implementation:** `src/expr.ml:105-138`

The `unfold_decl_def` function:

```ocaml
let unfold_decl_def (macro_env : (string * (string list * expr list)) list) exprs =
  let rec process_expr (env, acc) = function
    (* Macro definition *)
    | List (Symbol "new-declaration" :: List (Symbol macro_name :: args) :: body) ->
      let var_args = List.map args ~f:(function | Var x -> x | _ -> failwith ...) in
      ((macro_name, (var_args, body)) :: env, acc)

    (* Macro call *)
    | List (Symbol macro_name :: call_args) as expr -> (
      match List.Assoc.find env macro_name ~equal:String.equal with
      | Some (formal_params, body) ->
          (* Expand macro by substituting arguments *)
          let expanded = List.map body ~f:apply_substitution |> List.rev in
          (env, expanded @ acc)
      | None -> (env, expr :: acc) )
    (* ... *)
  in
  List.fold_left exprs ~init:(macro_env, []) ~f:process_expr |> snd |> List.rev
```

**Key observations:**

- Macros are stored in a local environment during preprocessing: `(string * (string list * expr list)) list`
- When a macro is defined, it's added to this local environment
- When a macro is called, its body is expanded with arguments substituted
- After preprocessing completes, the macro environment is **discarded**
- Only the **expanded expressions** proceed to evaluation

### The Runtime Environment

**Implementation:** `src/sgen_ast.ml:36`

```ocaml
type env = { objs : (ident * sgen_expr) list }

let initial_env = { objs = [] }
```

The runtime environment stores **identifiers** (terms) mapped to **expressions** (constellations). It does NOT store macros.

---

## The Macro Import Problem

### The Duplication Issue

The same macro definitions appear at the beginning of **12+ example files**:

```stellogen
(new-declaration (spec X Y) (:= X Y))
(new-declaration (:: Tested Test)
  (== @(interact @#Tested #Test) ok))
```

**Files with duplicated macros:**
- `examples/nat.sg`
- `examples/smll.sg`
- `examples/sumtypes.sg`
- `examples/npda.sg`
- `examples/mll.sg`
- `examples/syntax.sg`
- `examples/automata.sg`
- `examples/binary4.sg`
- `examples/linear_lambda.sg`
- And more...

### Why Imports Don't Work for Macros

The problem occurs because of the **separation between preprocessing and evaluation**:

```
File A:                          File B (imports A):
┌─────────────────┐              ┌─────────────────┐
│ Define macros   │              │ (use "a.sg")    │
│ Use macros      │              │ Try to use A's  │
│                 │              │ macros...       │
└────────┬────────┘              └────────┬────────┘
         │                                │
         ▼                                ▼
    Preprocessing                   Preprocessing
    (macro_env = [])                (macro_env = [])
         │                                │
    - Collect macros                 - Parse use declaration
    - Expand macros                  - No macros available!
    - Discard macro_env              - Can't expand A's macros
         │                                │
         ▼                                ▼
    Evaluation                       Evaluation
    (env contains defs)              - Load A, get A's defs
         │                           - But A's macros were
         │                             discarded during A's
         │                             preprocessing!
         ▼                                │
    Return env                           ▼
    (no macros!)                    Error or duplication
```

**Root cause:** Each file is preprocessed independently with an empty macro environment, and macro definitions are not preserved in the runtime environment.

### Concrete Example

Suppose we want to create `lib/prelude.sg`:

```stellogen
' lib/prelude.sg - Common macros
(new-declaration (spec X Y) (:= X Y))
(new-declaration (:: Tested Test)
  (== @(interact @#Tested #Test) ok))
```

And use it in `my_program.sg`:

```stellogen
' my_program.sg
(use "lib/prelude.sg")

' Try to use the macros
(spec nat {
  [(-nat 0) ok]
  [(-nat (s N)) (+nat N)]})

(:: 0 nat)  ' This won't work!
```

**What happens:**

1. `lib/prelude.sg` is preprocessed, macros are defined and then discarded
2. `lib/prelude.sg` is evaluated, runtime definitions are stored (but there are none in this case)
3. `my_program.sg` tries to use `spec` and `::` macros
4. **Error:** These macros are not available in `my_program.sg`'s preprocessing phase

---

## Design Considerations

When designing a solution, we must align with Stellogen's core philosophy:

### 1. Minimalism

Stellogen is intentionally minimal. From the README:

> It offers elementary interactive building blocks where both computation and meaning live in the same language.

**Implication:** Avoid adding complex module systems, namespaces, or heavyweight import mechanisms. Keep it simple.

### 2. Logic-Agnostic Nature

> The semantic power (and the responsibility that comes with it) belongs entirely to the user.

**Implication:** Don't impose a rigid module structure. Allow flexibility in how code is organized and reused.

### 3. Metaprogramming Spirit

Influenced by Scheme/Racket's metaprogramming:

> from **Scheme/Racket** for the spirit of metaprogramming

**Implication:** Macros should be first-class citizens or close to it. Their import mechanism should feel natural to the language.

### 4. Practical Needs

The language is evolving, and real programs need to reuse code:

> This project is still in development, hence the syntax and features are still changing frequently.

**Implication:** A solution should be practical and solve the immediate need (MilkyWay standard library) without over-engineering.

### 5. Clean Separation of Concerns

The current architecture has a clean separation between:
- **Preprocessing:** Syntactic transformations (macros, desugaring)
- **Evaluation:** Semantic operations (interaction, unification)

**Implication:** Preserve this separation if possible. Mixing them could complicate the implementation.

---

## Proposed Solutions

### Solution 1: Thread Macro Environment Through Imports

**Idea:** Modify the import mechanism to collect and propagate macro environments.

**Changes needed:**

1. Modify `preprocess` to return both expanded expressions AND macro environment:
   ```ocaml
   let preprocess e : expr list * macro_env =
     let expanded = List.map ~f:expand_macro e in
     let macro_env, result = unfold_decl_def [] expanded in
     (result, macro_env)
   ```

2. Thread macro environment through `eval_program`:
   ```ocaml
   type env = {
     objs : (ident * sgen_expr) list;
     macros : (string * (string list * expr list)) list
   }
   ```

3. When processing `Use` declarations, merge macro environments

4. Modify file processing to use inherited macro environment during preprocessing

**Pros:**
- Clean separation: macros remain preprocessing-time constructs
- Imported macros are available in importing files
- Explicit propagation of macro definitions

**Cons:**
- Significant refactoring required across multiple modules
- Macro environment must be threaded through the entire evaluation pipeline
- Complicates the current clean separation

**Complexity:** High

---

### Solution 2: Make Macros Runtime Constructs

**Idea:** Store macros in the runtime environment and apply expansion during evaluation, not preprocessing.

**Changes needed:**

1. Add a new declaration type:
   ```ocaml
   type declaration =
     | Def of ident * sgen_expr
     | MacroDef of string * string list * expr list
     | (* ... existing ... *)
   ```

2. Store macros in runtime environment:
   ```ocaml
   type env = {
     objs : (ident * sgen_expr) list;
     macros : (string * (string list * expr list)) list
   }
   ```

3. Apply macro expansion during evaluation or as a separate pass

**Pros:**
- Natural integration with import system
- Macros become first-class like definitions
- Imported files export their macros automatically

**Cons:**
- Fundamentally changes the compilation model
- Macros are no longer purely compile-time
- Potential performance implications (repeated expansion)
- Blurs the clean preprocessing/evaluation separation

**Complexity:** High

**Philosophical concern:** Mixing compile-time and runtime concerns may go against the clean separation principle.

---

### Solution 3: Two-Phase Import (Separate Macro Imports)

**Idea:** Introduce a separate `use-macros` declaration for importing macros.

**Syntax:**

```stellogen
' Import macros only
(use-macros "lib/prelude.sg")

' Import runtime definitions only
(use "lib/nat.sg")

' Or import both
(use-macros "lib/prelude.sg")
(use "lib/prelude.sg")
```

**Changes needed:**

1. Add `UseMacros` declaration type:
   ```ocaml
   type declaration =
     | (* ... existing ... *)
     | UseMacros of ident
   ```

2. Modify preprocessing to handle `UseMacros` specially:
   - Before `unfold_decl_def`, scan for `UseMacros` declarations
   - Load those files and extract their macro definitions
   - Build initial macro environment
   - Then proceed with `unfold_decl_def` using this environment

3. Keep `Use` for runtime definitions only

**Pros:**
- Explicit and clear: users know what they're importing
- Backward compatible: existing `use` still works
- Minimal runtime impact: macros remain preprocessing-time
- Simple to understand and implement

**Cons:**
- Two different import mechanisms (cognitive overhead)
- Requires duplication if you want both macros and definitions
- Still requires threading macro environment to some degree

**Complexity:** Medium

**Example:**

```stellogen
' lib/prelude.sg
(new-declaration (spec X Y) (:= X Y))
(new-declaration (:: Tested Test)
  (== @(interact @#Tested #Test) ok))

' my_program.sg
(use-macros "lib/prelude.sg")

(spec nat {
  [(-nat 0) ok]
  [(-nat (s N)) (+nat N)]})

(:: 0 nat)  ' Works!
```

---

### Solution 4: Preprocessing Directive for Macro Imports

**Idea:** Add a special preprocessing directive that loads macros before the main preprocessing pass.

**Syntax:**

```stellogen
(import-macros "lib/prelude.sg")

' Rest of the file...
```

**Changes needed:**

1. Parse files in two phases:
   - **Phase 1:** Scan for `import-macros` directives
   - Load imported files and extract macro definitions
   - Build initial macro environment
   - **Phase 2:** Preprocess with this macro environment

2. `import-macros` is NOT a regular declaration—it's a preprocessing directive

3. Keep the rest of the pipeline unchanged

**Pros:**
- Clean separation: preprocessing is still distinct from evaluation
- Minimal changes to evaluation pipeline
- Natural fit with the existing architecture
- Only affects preprocessing, not runtime

**Cons:**
- Introduces a new concept (preprocessing directives vs declarations)
- Requires two-pass parsing
- Need to handle cycles (A imports B, B imports A)

**Complexity:** Medium

**Example:**

```stellogen
' lib/prelude.sg
(new-declaration (spec X Y) (:= X Y))
(new-declaration (:: Tested Test)
  (== @(interact @#Tested #Test) ok))

' my_program.sg
(import-macros "lib/prelude.sg")

(spec nat {
  [(-nat 0) ok]
  [(-nat (s N)) (+nat N)]})

(:: 0 nat)  ' Works!
```

---

### Solution 5: Standard Prelude File

**Idea:** Provide a special file (e.g., `lib/prelude.sg`) that's automatically loaded before every program, or allow a command-line flag to specify a prelude.

**Syntax:**

```bash
# Automatically load prelude
sgen run --prelude lib/prelude.sg my_program.sg

# Or configure a default prelude
sgen config set prelude lib/prelude.sg
```

**Changes needed:**

1. Add CLI option for prelude file
2. Before preprocessing any file, load and process the prelude:
   - Extract macro definitions
   - Build initial macro environment
   - Use this environment for all subsequent preprocessing

3. Optionally, support a `.stellogenrc` config file

**Pros:**
- Simple for the common case: one standard library
- No language changes required
- Easy to implement
- Users can choose their prelude or none

**Cons:**
- Doesn't solve the general import problem
- Less flexible: single global prelude
- Implicit behavior (magic prelude) may be confusing
- Doesn't support multiple libraries well

**Complexity:** Low

**Example usage:**

```bash
# Create prelude
echo '(new-declaration (spec X Y) (:= X Y))' > prelude.sg
echo '(new-declaration (:: Tested Test) (== @(interact @#Tested #Test) ok))' >> prelude.sg

# Use it
sgen run --prelude prelude.sg my_program.sg
```

---

## Recommendation

### Recommended Approach: Solution 4 (Preprocessing Directive) + Solution 5 (Optional Prelude)

**Rationale:**

1. **Aligns with Stellogen's philosophy:**
   - Minimal language changes
   - Preserves clean preprocessing/evaluation separation
   - Keeps macros as compile-time constructs
   - Flexible and user-driven

2. **Solves the immediate need:**
   - Enables creating a "MilkyWay" standard library
   - Allows importing specific macro libraries
   - No code duplication

3. **Practical implementation:**
   - Medium complexity (manageable)
   - Doesn't require major refactoring
   - Can be added incrementally

4. **User experience:**
   - Clear and explicit: `(import-macros "file.sg")`
   - Optional convenience: `--prelude` flag for common cases
   - Flexible: users can organize libraries as needed

### Combined Approach

**For general use:**

```stellogen
' my_program.sg
(import-macros "lib/types.sg")
(import-macros "lib/lists.sg")

' Now use macros from both libraries
(spec nat {...})
(:: value nat)
```

**For the common case (MilkyWay standard library):**

```bash
# Set up MilkyWay as default prelude
sgen run --prelude lib/milkyway.sg my_program.sg

# Or configure it once
sgen config set prelude lib/milkyway.sg
```

```stellogen
' my_program.sg
' MilkyWay macros are automatically available!

(spec nat {...})
(:: value nat)
```

### Why Not the Other Solutions?

- **Solution 1 (Thread macro env):** Too much refactoring, complicates the architecture
- **Solution 2 (Runtime macros):** Fundamentally changes the compilation model, blurs concerns
- **Solution 3 (Two-phase import):** Redundant with Solution 4, requires both `use-macros` and `use` for full imports

---

## Implementation Roadmap

### Phase 1: Core Macro Import (Solution 4)

**Goal:** Enable `(import-macros "file.sg")` directive

**Steps:**

1. **Add preprocessing directive parsing**
   - Modify parser to recognize `import-macros` as a special form
   - Distinguish it from regular declarations

2. **Implement two-phase preprocessing**
   ```ocaml
   (* Phase 1: Collect imported macros *)
   let rec collect_macro_imports expr_list : string list = ...
   let load_macro_file filename : (string * (string list * expr list)) list = ...

   (* Phase 2: Preprocess with macro environment *)
   let preprocess_with_imports e : expr list =
     let import_files = collect_macro_imports e in
     let macro_env = List.concat_map import_files ~f:load_macro_file in
     e |> List.map ~f:expand_macro |> unfold_decl_def macro_env
   ```

3. **Handle cycles and errors**
   - Detect circular imports
   - Provide clear error messages for missing files
   - Handle macro name conflicts (later import wins? error? warning?)

4. **Update `preprocess` function**
   ```ocaml
   (* Old *)
   let preprocess e = e |> List.map ~f:expand_macro |> unfold_decl_def []

   (* New *)
   let preprocess e = preprocess_with_imports e
   ```

5. **Test with examples**
   - Create `lib/prelude.sg` with common macros
   - Update example files to use `import-macros`
   - Verify no regressions

**Files to modify:**
- `src/expr.ml` - Add `preprocess_with_imports`, `collect_macro_imports`
- `src/sgen_parsing.ml` - Recognize `import-macros` (or handle as special case)

**Estimated effort:** 2-3 days

---

### Phase 2: Optional Prelude (Solution 5)

**Goal:** Support `--prelude` flag for automatic macro loading

**Steps:**

1. **Add CLI flag**
   ```ocaml
   (* bin/sgen.ml *)
   let prelude_flag =
     Arg.(value & opt (some string) None & info ["prelude"]
          ~doc:"Prelude file to load before processing")
   ```

2. **Load prelude macros before main file**
   ```ocaml
   let run_with_prelude prelude_file input_file =
     let macro_env =
       match prelude_file with
       | None -> []
       | Some file -> load_macro_file file
     in
     (* Process input_file with macro_env *)
   ```

3. **Optional: Config file support**
   - Create `.stellogenrc` format
   - Load config on startup
   - Allow setting default prelude

4. **Create MilkyWay standard library**
   - `lib/milkyway.sg` with common macros
   - Document available macros
   - Add examples

**Files to modify:**
- `bin/sgen.ml` - Add CLI flag and config loading
- Create `lib/milkyway.sg`
- Update documentation

**Estimated effort:** 1-2 days

---

### Phase 3: MilkyWay Standard Library

**Goal:** Create a comprehensive standard library

**Contents:**

```stellogen
' lib/milkyway.sg - Stellogen Standard Library

''' Type system macros '''
(new-declaration (spec X Y) (:= X Y))
(new-declaration (:: Tested Test)
  (== @(interact @#Tested #Test) ok))
(new-declaration (::lin Tested Test)
  (== @(fire @#Tested #Test) ok))

''' Common type definitions '''
(spec nat {...})
(spec binary {...})
(spec list {...})

''' Utility macros '''
(new-declaration (alias X Y) (:= X Y))
(new-declaration (type X Y) (spec X Y))

''' Testing macros '''
(new-declaration (test Name Body)
  (== Body ok Name))

''' Documentation helpers '''
(new-declaration (doc _ Body) Body)
```

**Organization:**

```
lib/
├── milkyway.sg         # Main standard library (imports all)
├── types.sg            # Type system macros
├── data.sg             # Data structure definitions
├── logic.sg            # Logic programming utilities
├── testing.sg          # Testing framework
└── docs/
    └── milkyway.md     # Documentation
```

**Estimated effort:** 3-5 days for initial version

---

### Total Timeline

- **Phase 1:** 2-3 days (core functionality)
- **Phase 2:** 1-2 days (convenience features)
- **Phase 3:** 3-5 days (standard library)

**Total:** ~1-2 weeks for complete implementation

---

## References

### Source Files

- `src/expr.ml` - Expression representation and macro expansion
  - Lines 71-96: `expand_macro` (syntactic sugar expansion)
  - Lines 98-103: `replace_id` (variable substitution)
  - Lines 105-138: `unfold_decl_def` (macro definition and expansion)
  - Line 302: `preprocess` (preprocessing pipeline)

- `src/sgen_eval.ml` - Expression evaluation and import handling
  - Lines 12-27: `find_with_solution` (identifier lookup with unification)
  - Lines 173-223: `eval_sgen_expr` (expression evaluation)
  - Lines 232-274: `eval_decl` (declaration evaluation)
  - Lines 256-274: `Use` declaration handler (file import)

- `src/sgen_ast.ml` - AST definitions
  - Lines 17-24: `sgen_expr` type
  - Line 36: `env` type (runtime environment)
  - Lines 40-45: `declaration` type

- `bin/sgen.ml` - CLI entry point

### Example Files with Macro Duplication

- `examples/nat.sg`
- `examples/automata.sg`
- `examples/smll.sg`
- `examples/mll.sg`
- `examples/sumtypes.sg`
- `examples/npda.sg`
- `examples/binary4.sg`
- `examples/linear_lambda.sg`
- `examples/syntax.sg`

### Related Documentation

- `README.md` - Project philosophy and overview
- `CLAUDE.md` - Project guide
- `docs/basics.md` - Language fundamentals

---

## Open Questions

1. **Macro name conflicts:** What happens if two imported files define the same macro?
   - Option A: Error (safe but restrictive)
   - Option B: Later import wins (flexible but potentially confusing)
   - Option C: Warning + later import wins (balanced)

2. **Import paths:** Should we support relative vs. absolute paths?
   - Current `use` supports both: `"examples/file.sg"` and potentially `"file"`
   - Should `import-macros` follow the same convention?

3. **Visibility:** Should imported macros be re-exported?
   - If A imports B's macros, and C imports A, should C see B's macros?
   - Current recommendation: No (explicit is better)

4. **Performance:** Should we cache parsed macro files?
   - Multiple files might import the same macro library
   - Caching could avoid repeated parsing
   - Premature optimization?

5. **Syntax:** Should `import-macros` use a different syntax?
   - Current: `(import-macros "file.sg")`
   - Alternative: `(use-macros "file.sg")`
   - Alternative: `(require "file.sg" :macros)`

---

## Conclusion

The current import mechanism in Stellogen successfully handles runtime definitions but lacks support for importing macros. This creates code duplication across example files and prevents the creation of a reusable standard library.

The recommended solution—combining preprocessing directives for explicit macro imports with an optional prelude system—addresses this limitation while maintaining Stellogen's minimalist philosophy and clean architectural separation.

This approach enables the creation of a "MilkyWay" standard library, reduces code duplication, and provides a foundation for better code organization as Stellogen continues to evolve.

**Next steps:** Implement Phase 1 (core macro import functionality), then gather user feedback before proceeding with Phase 2 and Phase 3.
