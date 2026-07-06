# Stellogen Refocusing Plan: Logic Workbench (v3)

**Updated:** 2026-07-06

This plan identifies what to change, remove, simplify, or defer so that
Stellogen focuses on its strength: a workbench for building, testing, and
exploring logical systems via stellar resolution, structured as a **minimal
pure kernel plus user-space tower** (notation macros, checkers, logics).

See `evaluation_and_directions.md` (same directory) for the full rationale.
That document is self-contained; the former research corpus it once referenced
has been deleted and its durable findings are preserved in its Appendix A.

Completed items are removed from this plan (git history keeps the record).
Numbering of the remaining items is unchanged so cross-references stay valid.

---

## Phase 2: Simplify the Implementation (remaining)

### 2.2b Factorize execution variants — **design note, decision pending**
Recorded 2026-07-06 (Boris to decide later). Execution is **one operation**
(saturation of a focused space) with two orthogonal axes:

- *Resource discipline of action stars*: which structural rules actions
  enjoy. Weakening always (unused actions are discarded); contraction =
  `exec` (actions as if under `!`); none = `fire` (purely linear dynamics).
  The AST already half-knows this: `Exec of bool * …`, the bool is this
  axis.
- *Composition shape*: flat vs staged (`then`). Staging is **not** an
  execution mode: it is derived notation (a left fold of executions), which
  is why it never touches the evaluator.

Proposals on the table:

1. **Encode the mode axis honestly:** replace the bool with
   `type exec_mode = Reuse | Linear`. Extensible to bounded/soft disciplines
   later; exponential disciplines correspond to complexity classes (light
   logics), which connects directly to the descriptive-complexity program
   (evaluation doc §6). The mode axis is research-relevant, not plumbing.
2. **2×2 matrix** {reuse, linear} × {flat, staged}: ship three cells
   (`exec`, `fire`, `then` = staged reuse); staged-linear is a 2-line
   addition when a use case arrives (e.g. step-by-step proof construction).
3. **Naming options:** (i) systematic family `exec`/`exec-lin`/`exec-seq`
   (renames `fire`: churn); (ii) mode symbols inside one head,
   `(exec lin seq …)` — **rejected**: bare symbols become context-dependent,
   the §4.2 reader hazard; (iii) keep `exec`/`fire` + `then` — least churn,
   current choice pending the decision.

`KERNEL.md` (2.7) should state whichever factorization wins in one
paragraph: one operation, mode = structural discipline of actions,
staging = derived fold.

### 2.5 Fold `constellation_eval.ml` into `tracer.ml` — **pending**
- **Why:** Thin wrapper re-exporting from `executor.ml`/`tracer.ml`;
  indirection without value.
- **Action:** Move trace configuration into `tracer.ml`; update imports.

### 2.6 Clean up trace configuration — **pending**
- **Why:** Trace mode is enabled via a magic `__trace__` binding checked on
  every `exec`.
- **Action:** Pass trace config explicitly through the evaluation context.
- **Files:** `evaluator.ml`

### 2.7 Kernel audit: write `KERNEL.md` — **pending**
- **Why:** "Pure substrate" must be a checkable claim, not a mood. One short
  document listing every form the evaluator accepts, with the rule: *if a
  feature can be defined as a macro, it must not be in the kernel; if it
  can't and isn't essential, remove it.*
- **Action:** Write `KERNEL.md` after 2.5–2.6 land, **in two parts**:
  the *object kernel* (stellar resolution proper: terms, rays, stars,
  constellations, focus, `||` constraints) and the *meta kernel* (the
  functional glue: `def`, `#`, fixed-arity `macro`, `exec`/`fire`/`then`,
  `show`, `==`, `~=`, `forall`, `use`). Sorting rule: anything that computes
  belongs in the object language; meta constructs justify themselves as glue
  (assemble/run/compare) or are demoted/removed. Demote `spec` to a prelude
  macro — audit settled: the builtin is identical to `def`
  (same match arm in `expression.ml`), so intent-marking moves to the
  notation layer. Confirm fields/records remain a user-space pattern.
  Document the judgment contract: checking macros (`::`, `::lin`, …) must
  expand to `==`/`~=` assertions — the fixed base observations are the
  trusted layer; success conventions stay user-space (see
  evaluation_and_directions.md §5.3). State the base-observation contracts:
  `==` is syntactic equality of results; `~=` is **polarity-blind structural
  unifiability** (settled 2026-07-06; pinned by `test/syntax/match.sg`);
  `forall` is the ∀ of orthogonality (each test in its own interaction
  space) — pin down what "member" means for it. Verify the meta-language is
  total now that variadic macros are gone (expansion terminates
  structurally; no recursive definition references). Target: the OCaml core
  reads in an afternoon and maps one-to-one onto the formal definition of
  stellar resolution plus the kernel list.

---

## Phase 2.5: Kernel Contract Work

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

### 3.2 Fix `family.sg` grandparent limitation — **pending (approach settled)**
- Resolved without any kernel feature: rewrite the rule with both subgoals
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
  building logical notation only (fixed-arity).

### 3.6 Rewrite `BASICS.md` logic section — **pending**
- **Action:** Use Stellogen's own vocabulary: axioms (positive stars),
  inference rules (negative-to-positive stars), goals (focused negative
  stars), theories (constellations). Promote types-as-tests.

### 3.7 Extend exercises — **pending**
- Base set exists (00–03, solutions, cram test). Extend with: types-as-tests,
  automata word-acceptance, and (post-Phase 4) a small MLL proof exercise.

### 3.8 Codify the standard file shape — **pending**
- **Action:** Document the house style (imports → definitions → tests →
  assertions → demonstrations) in `BASICS.md`; align all examples with it.
  It is the file-level expression of "encode + test."

---

## Phase 4: Build the Logic Library

### 4.1 Create `logics/` directory — **pending; benefits from 2.5.2**
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

## Summary: What Remains

| Category | Items |
|----------|-------|
| **Simplify** | `constellation_eval.ml` (2.5), trace hack (2.6) |
| **Decide** | execution-variant factorization (2.2b) |
| **Document** | `KERNEL.md` incl. code-as-term encoding contract (2.7, 2.5.2), file-shape house style, `BASICS.md` rewrite |
| **Rename/reframe** | `prolog/`→`relational/`, `family.sg`, `hello.sg`, `stack.sg`, `macro_demo.sg` |
| **New content** | `logics/` library + flagship MLL tutorial, exercise extensions |

**Net effect:** a kernel small enough to read in an afternoon, an encoding
contract that unblocks the logic library, and a flagship artifact that
states the project's identity — with zero additions to the object kernel.

---

## Execution Order

```
Phase 2 (short term)     → Import merge and dedups; write KERNEL.md
Phase 2.5 (design work)  → Encoding contract (blocks Phase 4); scoping deferred
Phase 3 (ongoing)        → Reframe examples and docs
Phase 4 (the point)      → logics/ library + flagship MLL demonstration
Phase 5 (longer term)    → Diagnostics, trace, REPL
```

Phase 2 is mechanical and can be done in a session. Phase 2.5 is the real
design work and gates Phase 4. Phase 4 is where Stellogen becomes genuinely
compelling; Phase 5 is what makes it pleasant to show others.
