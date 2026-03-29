# Stellogen Refocusing Plan: Logic Workbench

This plan identifies what to change, remove, simplify, or defer so that
Stellogen focuses on its strength: a workbench for building, testing, and
exploring logical systems via stellar resolution.

See `evaluation_and_directions.md` for the full rationale.

---

## Phase 1: Remove Distractions

### 1.1 Delete broken example `circuits.sg`
- **Why:** Starts with `' FIXME`, body is 100% commented out. Shipping broken
  examples harms credibility.
- **Action:** Delete `examples/circuits.sg`. The analysis of *why* circuits
  break is preserved in `ai/research/synchronization_in_circuits.md`.

### 1.2 Delete outdated exercises
- **Why:** All exercises use extinct syntax (`const`, `star`, `union`,
  `galaxy`, `show-exec`, `interaction`, `expect`). None of them run. They
  mislead anyone who discovers them.
- **Action:** Delete all files in `exercises/` (including `solutions/`).
  Rewriting them is Phase 3 work.

### 1.3 Move speculative docs to `ai/research/`
- **Why:** 15 AI-generated design documents push Stellogen toward
  general-purpose DSL territory (traffic light controllers, loan approval
  engines, JSON parsers). They cloud the project's identity.
- **Action:** Already done. `docs/` now contains only actionable documents.
  `ai/research/` preserves the research for future reference.

### 1.4 Remove `watch` CLI command
- **Why:** Developer convenience, not a logic workbench feature. Adds ~70
  lines of Unix-specific process management (`fork`, `kill`, polling). Users
  can use `entr` or `watchexec` externally.
- **Action:** Remove `watch` subcommand and `run_with_timeout` from
  `bin/sgen.ml`. Remove `timeout_arg`.
- **Files:** `bin/sgen.ml`

---

## Phase 2: Simplify the Implementation

### 2.1 Remove variadic macro support
- **Why:** Variadic `...` splicing, multi-pattern dispatch by arity, and
  recursive variadic expansion push toward general-purpose metaprogramming.
  A logic workbench needs simple notation macros, not a macro language.
- **Action:** Remove `is_variadic_pattern`, `min_args_for_pattern`,
  `pattern_matches_args`, `split_variadic_params`,
  `find_matching_pattern`, `apply_variadic_substitution` from
  `src/core/expression.ml` (~120 lines). Keep fixed-arity macros.
- **Impact:** The `stack` and `chain` macros in `milkyway/prelude.sg` break.
  Replace them (see 2.3).

### 2.2 Merge `use-macros` into `use`
- **Why:** Two import mechanisms (`use` for definitions, `use-macros` for
  macros only) is confusing. The `collect_macro_imports` function has 8
  near-identical match arms for `Positioned` wrappers.
- **Action:** Make `use` import both macros and definitions. Remove
  `use-macros` from the parser, `expression.ml`, and `stellogen_parsing.ml`.
- **Files:** `expression.ml` (remove `collect_macro_imports` complexity),
  `stellogen_parsing.ml` (simplify import handling)

### 2.3 Make `process` a built-in
- **Why:** `process` is documented as a core construct but currently depends
  on variadic macros (which we're removing). It's important enough for a
  logic workbench (chaining interactions = building proofs step by step) to
  be a language primitive.
- **Action:** Add `Process` variant to `sgen_expr` in `syntax.ml`. Handle
  binary `(process e1 e2)` in `expression.ml` and `evaluator.ml`: evaluate
  `e1`, execute it, merge the result with `e2`.
- **Semantics:** `(process c1 c2)` = execute `c1`, then combine the result
  with `c2` and return the combined constellation (for further use with
  `exec` or another `process`).
- **Files:** `syntax.ml`, `expression.ml`, `evaluator.ml`

### 2.4 Eliminate `MatchableRays` duplication
- **Why:** A separate unification module instantiation (`MatchableRays`) exists
  solely for the `~=` operator to ignore polarity. This duplicates the
  entire unification pipeline.
- **Action:** Instead of a separate module, strip polarities from terms
  before calling regular `StellarRays.solution`. Remove `MatchableSig`,
  `MatchableRays`, `to_matchable_term`, `terms_unifiable`.
- **Files:** `constellation.ml` (remove ~20 lines), `evaluator.ml` (update
  `constellations_matchable`)

### 2.5 Fold `constellation_eval.ml` into `tracer.ml`
- **Why:** `constellation_eval.ml` is a thin wrapper re-exporting from
  `executor.ml` and `tracer.ml` with trace configuration plumbing. It adds
  indirection without value.
- **Action:** Move trace configuration directly into `tracer.ml`. Update
  `evaluator.ml` imports.
- **Files:** `constellation_eval.ml` (delete), `tracer.ml`, `evaluator.ml`

### 2.6 Clean up trace configuration
- **Why:** Trace mode is enabled via a magic `__trace__` binding inserted
  into the environment. This is a hack checked on every `exec` call.
- **Action:** Pass trace config explicitly through the evaluator (as a
  field in the evaluation context/config), not through the definition
  environment.
- **Files:** `evaluator.ml`

---

## Phase 3: Reframe and Rebuild Content

### 3.1 Rename `examples/prolog/` to `examples/relational/`
- **Why:** The directory name frames Stellogen as a Prolog imitator. The
  content (relational definitions, queries) is valid for a logic workbench
  but the framing is wrong.
- **Action:** `mv examples/prolog examples/relational`. Update any `use`
  references. Add a comment in each file: "This demonstrates relational
  reasoning in Stellogen (cf. logic programming), not Prolog emulation."

### 3.2 Fix or document `family.sg` grandparent limitation
- **Why:** The grandparent query is commented out with "does not work."
  This is a fundamental limitation (accidental interactions between
  constellations that should be isolated) and needs to be either solved
  or clearly explained.
- **Action (option A - fix):** Introduce a scoping/namespacing mechanism
  for rays to prevent accidental interaction between rule subgoals.
- **Action (option B - document):** Keep the broken query but add a
  clear explanation of *why* it fails and what this teaches about
  constellation-based vs clause-based reasoning.

### 3.3 Reframe `examples/hello.sg`
- **Why:** Currently just shows terms. Should immediately show the
  workbench angle.
- **Action:** Add a minimal interaction example (e.g., a simple fact +
  query + execution) so the first thing a user sees is stellar resolution
  in action, not just term printing.

### 3.4 Reframe `examples/stack.sg`
- **Why:** Currently reads like "how to use stacks in Stellogen." Should
  read like "encoding an operational semantics."
- **Action:** Update comments to frame as: "Encoding a stack machine's
  operational semantics as a constellation. Each rule is a transition."

### 3.5 Clean up `examples/macro_demo.sg`
- **Why:** Contains a confusing nested `def` inside `exec` that may not
  work correctly.
- **Action:** Simplify to show macros in service of building logical
  notation, not arbitrary metaprogramming. After removing variadics,
  update to use only fixed-arity macros.

### 3.6 Rewrite `BASICS.md` logic programming section
- **Why:** Uses Prolog vocabulary ("Facts", "Rule", "Query") rather than
  Stellogen's own terms.
- **Action:** Reframe using: "axioms" (positive stars), "inference rules"
  (negative-to-positive stars), "goals" (focused negative stars),
  "theories" (constellations). Promote the types-as-tests section to be
  more prominent.

### 3.7 Write new exercises (current syntax)
- **Why:** The old exercises were deleted in Phase 1. A logic workbench
  needs guided learning materials.
- **Suggested exercises:**
  1. **Unification basics** — predict fusion results, fix polarity errors
  2. **Building a small logic** — define propositional connectives as
     constellations, test them
  3. **Types as tests** — define a type, check values against it
  4. **Automata** — encode a simple DFA, test word acceptance
  5. **Proof construction** — build an MLL proof, verify with correctness
     tests

---

## Phase 4: Build the Logic Library (new content)

### 4.1 Create `logics/` directory
Structure:
```
logics/
  mll.sg          -- Multiplicative Linear Logic (expand from proofnets/)
  classical.sg    -- Classical propositional logic via resolution
  intuitionistic.sg -- Intuitionistic logic via exponentials
  linear_types.sg -- Linear type system (complete the TODO)
```

### 4.2 Each logic file should contain:
1. Connective definitions as constellations
2. Correctness criteria as test constellations
3. Helper macros for readable notation
4. Worked proofs with commentary
5. Failing examples showing what correctness rejects

### 4.3 Write demonstrations
- **"What if we change the logic?"** — same proof in MLL vs classical,
  showing different cut-elimination behavior
- **"Inventing a connective"** — define a non-standard operator, test it
- **"Automata as logical systems"** — frame NFA acceptance as a logical
  statement and execution as proof

---

## Phase 5: Improve the Experience

### 5.1 Better "no interaction" diagnostics
- When `exec` produces `{}`, report *why*: polarity mismatch? no focused
  stars? unification failure?
- **Files:** `executor.ml`, `evaluator.ml`

### 5.2 Add `(trace expr)` as a language construct
- Currently tracing requires the `trace` CLI command (all-or-nothing).
  A `(trace ...)` form would let users trace specific executions.
- **Files:** `syntax.ml`, `expression.ml`, `evaluator.ml`

### 5.3 REPL
- Essential for interactive exploration of logical systems. Define
  connectives, try proofs, see reductions, adjust.
- **Files:** `bin/sgen.ml` (new `repl` subcommand)

---

## Summary: What Changes

| Category | Items | Est. lines removed |
|----------|-------|--------------------|
| **Remove** | `circuits.sg`, exercises (8 files), `watch` command | ~400 |
| **Simplify** | Variadic macros, `use-macros`, `MatchableRays`, `constellation_eval.ml`, trace hack | ~250 |
| **Add** | `process` built-in | ~30 |
| **Rename** | `prolog/` → `relational/` | 0 |
| **Reframe** | `hello.sg`, `stack.sg`, `BASICS.md` | ~50 changed |
| **New content** | `logics/` library, exercises, demonstrations | ~500 new |
| **Moved** | 16 docs → `ai/research/` | 0 (relocated) |

**Net effect:** ~650 lines removed from implementation, ~500 lines of new
focused content, and a much clearer identity.

---

## Execution Order

```
Phase 1 (immediate)    → Clean slate: remove broken/outdated material
Phase 2 (short term)   → Simplify: fewer concepts, less code
Phase 3 (medium term)  → Reframe: everything tells the "logic workbench" story
Phase 4 (medium term)  → Build: the logic library that proves the concept
Phase 5 (longer term)  → Polish: diagnostics, tracing, REPL
```

Phases 1-2 can be done in a few sessions. Phase 3 is ongoing. Phases 4-5
are where Stellogen becomes genuinely compelling.
