# Stellogen Refocusing Plan: Logic Workbench (v2)

**Updated:** 2026-07-06

This plan identifies what to change, remove, simplify, or defer so that
Stellogen focuses on its strength: a workbench for building, testing, and
exploring logical systems via stellar resolution, structured as a **minimal
pure kernel plus user-space tower** (notation macros, checkers, logics).

See `evaluation_and_directions.md` (same directory) for the full rationale.
That document is self-contained; the former research corpus it once referenced
has been deleted and its durable findings are preserved in its Appendix A.

**v2 changes relative to v1:**

- Statuses added (done / pending / amended / superseded).
- Exercises are **kept**, not deleted — they were rewritten in current syntax
  with a cram test (`test/exercises.t`), which supersedes v1's Phase 1.2.
- New removal: **incremental parsing + error recovery** in `src/parsing/`
  (v1 missed it; it is the largest remaining piece of general-purpose noise).
- New workstream: **kernel definition** (`KERNEL.md`) and **canonicalizing
  the existing code-as-term encoding** (quotation is already structurally
  present; an `eval` primitive existed and was removed in commit `3025e62`,
  2025-11-16). v1 did not anticipate these, but Phase 4 (logic library)
  silently depends on the encoding contract.
- **Ray scoping considered and deferred** (was briefly a planned kernel
  addition): its motivating scenario was Prolog-style knowledge-base
  merging, which this plan deprioritizes; workbench idioms curate
  interaction spaces per `exec` and are collision-resistant. Analysis and
  revisit triggers: `evaluation_and_directions.md` §5.1. The object kernel
  gets **zero additions**.
- `examples/prolog/` reframed as saturation-style (Datalog-like) logic
  programming or folded into `relational/`; `family.sg` fixed by rewriting
  the rule (both subgoals negative — verified working) or dropped, not by a
  kernel feature.
- References to deleted `ai/research/` documents corrected.

---

## Phase 1: Remove Distractions

### 1.1 Delete broken example `circuits.sg` — **pending**
- **Why:** Starts with `' FIXME`, body is 100% commented out. Shipping broken
  examples harms credibility. The impossibility of faithful synchronous
  circuits is a boundary of the model (thesis Ch. 8), not a bug to fix.
- **Action:** Delete `examples/circuits.sg`. The analysis is preserved in
  `evaluation_and_directions.md`, Appendix A.1.

### 1.2 Exercises — **superseded (keep the rewrite)**
- v1 said delete the outdated exercises. Instead they were rewritten in
  current syntax with solutions and a cram test (`test/exercises.t`).
- **Action:** Keep and maintain; commit the rewrite. Extend later per 3.7.

### 1.3 Move speculative docs — **superseded (deleted)**
- v1 moved 15+ AI-generated design docs to `ai/research/`. On 2026-07-06 the
  whole corpus was deleted as obsolete noise; durable findings distilled into
  `evaluation_and_directions.md` Appendix A. `docs/` was folded into
  `ai/research/`, which now holds only the two strategy documents.
- **Follow-up:** Update `CLAUDE.md`'s project-structure section (it still
  lists `docs/`).

### 1.4 Remove `watch` CLI command — **pending**
- **Why:** Developer convenience, not a workbench feature. ~70 lines of
  Unix-specific process management. Users can use `entr`/`watchexec`.
- **Action:** Remove `watch` subcommand, `run_with_timeout`, `timeout_arg`
  from `bin/sgen.ml`.

### 1.5 Remove incremental parsing + error recovery — **new, pending**
- **Why:** `src/parsing/parse_error.ml` (~120 lines) and the recovery driver
  in `stellogen_parsing.ml` implement Menhir's incremental API with
  token-skipping multi-error recovery. This is IDE-grade machinery serving
  the abandoned general-purpose direction. A research kernel wants fail-fast
  parsing with one precise, well-located error. Largest single de-noising win.
- **Action:** Replace the incremental/recovery driver with a plain Menhir
  parse; keep good single-error location reporting; delete
  `parse_error.ml`'s recovery strategy machinery.
- **Files:** `src/parsing/parse_error.ml`, `src/parsing/stellogen_parsing.ml`

---

## Phase 2: Simplify the Implementation

### 2.1 Make `process` a built-in — **pending, do first in this phase**
- **Why:** `process` is a core workbench construct (chaining interactions =
  building proofs step by step) but is currently a variadic macro in
  `milkyway/prelude.sg`. It must be a kernel form *before* variadic macros
  can be removed (2.2 depends on it).
- **Action:** Add `Process` variant to `sgen_expr`; handle
  `(process e1 e2 ...)` in `expression.ml`/`evaluator.ml`: evaluate, execute,
  merge left-associatively.
- **Files:** `syntax.ml`, `expression.ml`, `evaluator.ml`

### 2.2 Remove variadic macro support — **pending, after 2.1**
- **Why:** Variadic `...` splicing, arity dispatch, and recursive variadic
  expansion are a general-purpose metaprogramming language inside the macro
  system. The kernel needs simple, fixed-arity notation macros.
- **Action:** Remove `is_variadic_pattern`, `min_args_for_pattern`,
  `pattern_matches_args`, `split_variadic_params`, `find_matching_pattern`,
  `apply_variadic_substitution` from `src/core/expression.ml` (~120 lines).
- **Impact:** `stack`/`chain`/`process` macros in `milkyway/prelude.sg`
  break. `process` is rescued by 2.1. `stack`/`chain`: drop them; writing
  `(s (s 0))` is bearable, and no reader sugar should be added until real
  tower code demands it. Note `CLAUDE.md` documents a `<f a b>` sugar that no
  longer exists in the lexer — fix the doc, don't resurrect the feature.

### 2.3 Merge `use-macros` into `use` — **pending**
- **Why:** Two import mechanisms is confusing; `collect_macro_imports` has 8
  near-identical match arms.
- **Action:** `use` imports both macros and definitions; remove `use-macros`
  from parser, `expression.ml`, `stellogen_parsing.ml`.

### 2.4 Eliminate `MatchableRays` duplication — **pending**
- **Why:** A separate unification module instantiation exists solely so `~=`
  can ignore polarity, duplicating the unification pipeline.
- **Action:** Strip polarities before calling regular `StellarRays.solution`;
  remove `MatchableSig`, `MatchableRays`, `to_matchable_term`,
  `terms_unifiable`.
- **Files:** `constellation.ml`, `evaluator.ml`

### 2.5 Fold `constellation_eval.ml` into `tracer.ml` — **pending**
- **Why:** Thin wrapper re-exporting from `executor.ml`/`tracer.ml`;
  indirection without value.
- **Action:** Move trace configuration into `tracer.ml`; update imports.

### 2.6 Clean up trace configuration — **pending**
- **Why:** Trace mode is enabled via a magic `__trace__` binding checked on
  every `exec`.
- **Action:** Pass trace config explicitly through the evaluation context.
- **Files:** `evaluator.ml`

### 2.7 Kernel audit: write `KERNEL.md` — **new, pending**
- **Why:** "Pure substrate" must be a checkable claim, not a mood. One short
  document listing every form the evaluator accepts, with the rule: *if a
  feature can be defined as a macro, it must not be in the kernel; if it
  can't and isn't essential, remove it.*
- **Action:** Write `KERNEL.md` after 2.1–2.6 land, **in two parts**:
  the *object kernel* (stellar resolution proper: terms, rays, stars,
  constellations, focus, `||` constraints) and the *meta kernel* (the
  functional glue: `def`, `#`, fixed-arity `macro`, `exec`/`fire`/`process`,
  `show`, `==`, `~=`, `forall`, `use`). Sorting rule: anything that computes
  belongs in the object language; meta constructs justify themselves as glue
  (assemble/run/compare) or are demoted/removed. Demote `spec` to a prelude
  macro — audit settled: the builtin is identical to `def`
  (`expression.ml:622`, same match arm), so intent-marking moves to the
  notation layer. Confirm fields/records remain a user-space pattern.
  Document the judgment contract: checking macros (`::`, `::lin`, …) must
  expand to `==`/`~=` assertions — the fixed base observations are the
  trusted layer; success conventions stay user-space (see
  evaluation_and_directions.md §5.3). Verify the meta-language is
  total once variadic macros are gone (expansion terminates structurally; no
  recursive definition references). Target: the OCaml core reads in an
  afternoon and maps one-to-one onto the formal definition of stellar
  resolution plus the kernel list.

---

## Phase 2.5: Kernel Contract Work (new)

No additions to the object kernel. One canonicalization task, plus one
deferral recorded so it is not re-litigated from scratch. Rationale:
`evaluation_and_directions.md` §5.

### 2.5.1 Ray scoping/namespacing — **deferred (no kernel construct)**
- **Status:** Considered as a kernel addition, rejected for now. Any two
  stars sharing a function symbol with opposite polarities form a
  communication channel; a `scope`/interface construct with symbol
  freshening would close accidental ones. Deferred because: the motivating
  scenario (knowledge-base-style vocabulary merging) is the deprioritized
  Prolog idiom; workbench practice curates each `exec` space by hand and
  composes results, not vocabularies; shape checkers read code as inert
  terms; a flat symbol space is the semantics (symbols are loci/addresses —
  local labels are an assembler feature, not an ISA feature).
- **Discipline meanwhile:** prefix private wiring symbols by library name
  (e.g. `acyclic-walk`), as house convention in `logics/`.
- **Escalation path if collisions bite:** import-time renaming at the meta
  level — `(use "lib.sg" (prefix lib))` — before any object-kernel change.
- **Revisit triggers:** real capture bugs; multi-library co-saturation
  becoming an idiom; a `logics/` library needing to share one interaction
  space with arbitrary user code.

### 2.5.2 Canonical code-as-term encoding — **blocking for shape-systems**
- **Why:** `::` tests behaviour (what code does). Systems — certified
  fragments like "acyclic ⇒ terminating" or MLL correctness — must test
  *shape* (what code is). Checkers need code reified as a term to unify
  against. **No new primitive is needed:** expressions already are terms
  internally (`ray_of_expr` in `expression.ml` maps all surface syntax onto
  `%`-constructors), examples already store code as data (fields pattern),
  and a term→code `eval` existed until it was removed on 2025-11-16 (commit
  `3025e62`) — correctly, for kernel purity.
- **Action:** (1) Document the exact reified-term shape in `KERNEL.md` as a
  stable contract for checkers. (2) Verify a macro can splice a definition
  body into both code position and term position; add thin `quote` notation
  only if some surface form (`@`, `#`, `{}`) fails to embed. (3) Keep `eval`
  removed until a concrete need (tactics, staged proof construction)
  justifies deliberate reintroduction with a written staging/trust story.
- **Acceptance test:** a working `(in-acyclic Name Body)` macro that defines
  `Name` and asserts the acyclicity checker accepts `Body`'s term encoding.

---

## Phase 3: Reframe and Rebuild Content

### 3.1 Rename `examples/prolog/` to `examples/relational/` — **pending**
- **Why:** The name frames Stellogen as a Prolog imitator; no formal
  correspondence with SLD semantics exists (thesis Ch. 9).
- **Action:** `mv examples/prolog examples/relational`; update `use`
  references; note in each file: relational reasoning by interaction, not
  Prolog emulation.

### 3.2 Fix `family.sg` grandparent limitation — **amended: fix by rewrite**
- v1 offered "fix or document"; an earlier v2 draft said "fix via scoping."
  Resolved without any kernel feature: rewrite the rule with both subgoals
  negative — `[(+grandparent X of Z) (-parent X of Y) (-parent Y of Z)]` —
  verified working (`bob`; `{[ann] [pat]}` plus a stuck star for the
  childless branch). The rule as currently written diverges (its
  `+parent`/`-parent` pair feeds itself across copies). Reframe the file as
  saturation-style relational reasoning per 3.1, and note the stuck-star
  residue as expected behaviour, not failure.

### 3.3 Reframe `examples/hello.sg` — **pending**
- **Action:** Add a minimal fact + query + execution so the first thing a
  user sees is stellar resolution in action, not term printing.

### 3.4 Reframe `examples/stack.sg` — **pending**
- **Action:** Frame as "encoding a stack machine's operational semantics;
  each rule is a transition."

### 3.5 Clean up `examples/macro_demo.sg` — **pending**
- **Action:** Remove the dubious nested `def`-inside-`exec`; show macros
  building logical notation only; fixed-arity only after 2.2.

### 3.6 Rewrite `BASICS.md` logic section — **pending**
- **Action:** Use Stellogen's own vocabulary: axioms (positive stars),
  inference rules (negative-to-positive stars), goals (focused negative
  stars), theories (constellations). Promote types-as-tests.

### 3.7 Exercises — **amended**
- Base set exists (00–03, solutions, cram test). Extend with: types-as-tests,
  automata word-acceptance, and (post-Phase 4) a small MLL proof exercise.

### 3.8 Codify the standard file shape — **new**
- **Action:** Document the house style (imports → definitions → tests →
  assertions → demonstrations) in `BASICS.md`; align all examples with it.
  It is the file-level expression of "encode + test."

---

## Phase 4: Build the Logic Library

### 4.1 Create `logics/` directory — **pending; requires 2.5.1, benefits from 2.5.2**
```
logics/
  mll.sg            -- Multiplicative Linear Logic (expand from proofnets/)
  classical.sg      -- Classical propositional logic via resolution
  linear_types.sg   -- Linear type system (complete linear_lambda.sg TODO)
  automata.sg       -- Automata-as-logic (acceptance as type membership)
```

### 4.2 Each logic file is a *system*: notation + checker + guarantee
1. Connective definitions as constellations
2. Correctness criteria as test constellations (the checker)
3. Fixed-arity macros for readable notation
4. Worked proofs with commentary **and failing examples showing what the
   checker rejects**
5. A stated guarantee ("everything this checker accepts satisfies P"), with
   the paper proof referenced or sketched

### 4.3 The flagship demonstration — **the project's centerpiece**
- One polished MLL tutorial: connectives → correctness tests → valid proof
  accepted → cut-elimination via `exec` → invalid proof-structure rejected →
  **change the logic and watch behaviour change**. Five-minute answer to
  "what is Stellogen for"; seed of the tool paper.
- Supporting demos: "inventing a connective"; "automata as logical systems."

---

## Phase 5: Improve the Experience

### 5.1 Empty-result diagnostics — **highest UX priority**
- When `exec` produces `{}`, report why: no focused stars? no
  opposite-polarity pair? unification failure (on which rays)?
- **Files:** `executor.ml`, `evaluator.ml`

### 5.2 `(trace expr)` as a language construct
- Let users trace specific executions instead of all-or-nothing CLI tracing.

### 5.3 REPL
- Essential for workbench-style exploration: define connectives, try proofs,
  watch reductions.

---

## Summary: What Changes

| Category | Items | Est. lines |
|----------|-------|------------|
| **Remove** | `circuits.sg`, `watch`, incremental parsing/error recovery | ~500 removed |
| **Simplify** | variadic macros, `use-macros`, `MatchableRays`, `constellation_eval.ml`, trace hack | ~250 removed |
| **Add (kernel)** | `process` built-in (meta level; ray scoping deferred — zero object-kernel additions) | ~60 added |
| **Document** | `KERNEL.md` (incl. code-as-term encoding contract), file-shape house style, `BASICS.md` rewrite, `CLAUDE.md` structure fix | — |
| **Rename/reframe** | `prolog/`→`relational/`, `hello.sg`, `stack.sg`, `macro_demo.sg` | ~50 changed |
| **New content** | `logics/` library + flagship MLL tutorial, exercise extensions | ~600 new |
| **Done** | exercises rewrite + cram test; research corpus deleted; strategy docs consolidated in `ai/research/` | — |

**Net effect:** a kernel small enough to read in an afternoon, an encoding
contract that unblocks the logic library, and a flagship artifact that
states the project's identity — with zero additions to the object kernel.

---

## Execution Order

```
Phase 1 (immediate)      → Remove: circuits.sg, watch, parser recovery
Phase 2 (short term)     → Simplify: process built-in first, then macro/import
                           cleanups; write KERNEL.md
Phase 2.5 (design work)  → Encoding contract (blocks Phase 4); scoping deferred
Phase 3 (ongoing)        → Reframe examples and docs
Phase 4 (the point)      → logics/ library + flagship MLL demonstration
Phase 5 (longer term)    → Diagnostics, trace, REPL
```

Phases 1–2 are mechanical and can be done in a few sessions. Phase 2.5 is
the real design work and gates Phase 4. Phase 4 is where Stellogen becomes
genuinely compelling; Phase 5 is what makes it pleasant to show others.
