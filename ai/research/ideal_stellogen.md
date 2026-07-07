# Ideal Stellogen: Syntax and the Shape of the Tower

*Companion to `evaluation_and_directions.md` (§3.2, §3.3, §4, §5). That
document argues for the design; this one draws the target. Everything here
is written as if the refocusing plan has been executed: variadic macros
gone, `use`/`use-macros` merged, `process` a built-in, incremental parsing
removed, the code-as-term encoding documented.*

---

## 1. The tower at a glance

One reader, one s-expression syntax, four layers. Only the bottom two are
built into `sgen`; the top two are ordinary `.sg` files.

```
  Layer 3   SYSTEMS & LOGICS          user space     systems/acyclic.sg, logics/mll.sg
            checkers + guarantees                    "small theorems packaged as libraries"
  ─────────────────────────────────────────────────────────────────────────────
  Layer 2   NOTATION                  user space     prelude.sg
            macros over layers 0–1                   ::, spec, get, quote, ...
  ═════════════════════════════════════════════════════════════════════════════
  Layer 1   META KERNEL               built-in       def  #  exec  fire  process
            functional glue                          show  ==  ~=  forall  use  macro
  ─────────────────────────────────────────────────────────────────────────────
  Layer 0   OBJECT KERNEL             built-in       terms  rays  stars  {...}
            stellar resolution                       @  ||
```

The double line is the trust boundary: `KERNEL.md` documents exactly layers
0 and 1 and nothing else. `sgen preprocess` is the witness that layers 2–3
elaborate away — run it on any file and what remains is layers 0–1 only.

The two built-in layers have **different semantics on purpose**:

- **Layer 0 is the chemistry**: unordered, interactive, non-deterministic,
  possibly non-terminating. This is the language of the thesis.
- **Layer 1 is the lab bench**: deterministic, ordered, total. It never
  computes anything itself — it only *assembles* constellations, *runs*
  them, and *compares* the results.

The sorting rule that keeps them apart: **anything that computes belongs in
layer 0; layer 1 only assembles, runs, and compares.** Every time a feature
request arrives, this rule decides its floor — or its rejection.

---

## 2. Layer 0 — the object kernel

Exactly stellar resolution as in the thesis — no additions. The full
grammar fits in a dozen lines:

```
term   ::=  VAR                        ; uppercase: X, Result
         |  fun                        ; constant: a, 0, bob
         |  (fun term ...)             ; application: (s (s 0))
         |  [term ...]                 ; sugar: cons list, %cons/%nil
         |  "chars"                    ; sugar: string as term

ray    ::=  term | +term | -term      ; polarity on the head symbol

star   ::=  [ray ...]
         |  [ray ... || constraint ...]     ; e.g. || (!= X Y)

cell   ::=  star | @star                    ; @ = focus: state vs action

const  ::=  cell
         |  { cell ... }
         |  @{ cell ... }                   ; focus everything inside
```

That is the whole object language. Things that are *not* in it, and never
will be: numbers with arithmetic, booleans, conditionals, ordering of
stars, any notion of function call. All of those are encodings.

### 2.1 Why there is no module construct

Compatibility of rays is decided by symbol + polarity + unifiability —
globally. Any two constellations that share a function symbol with opposite
polarities can interact, whether or not their authors meant them to. A
`scope`/interface construct (exported symbols visible, private symbols
freshened at composition) was considered for exactly this, and **deferred**
(full analysis: `evaluation_and_directions.md` §5.1). The short version:

- The scenario that motivated it — many independently authored vocabularies
  saturating in one space — is the knowledge-base idiom of Prolog-style
  logic programming, which this design deprioritizes. No real example hits
  the collision.
- The meta-language already curates interaction spaces: every `exec` is a
  small, hand-assembled world, and composition happens on *results*, not
  vocabularies. The workbench's own idioms are collision-resistant — shape
  checkers read code as inert terms; behavioural tests interact through a
  deliberately narrow vocabulary, which under bi-orthogonality *is* the
  interface.
- A flat symbol space is the semantics, not a defect: symbols are the loci
  where interaction happens. The kernel gives hygiene to variables because
  they are per-star placeholders; symbols are *addresses*. Local labels are
  an assembler feature, not an ISA feature — if hygiene is ever needed, it
  belongs at the notation/import layer (e.g. `(use "lib.sg" (prefix lib))`
  at layer 1), never in layer 0.

Until a real capture bug or a genuine multi-library co-saturation idiom
appears, the discipline is a naming convention, and layer 0 stays exactly
the thesis.

### 2.2 The canonical code encoding

Every surface expression already *is* a first-order term (`ray_of_expr`):

```
[a b]        ⇝  (%cons a (%cons b %nil))
{ s1 s2 }    ⇝  (%group s1; s2')
(f a b)      ⇝  (f a b)                 ; applications are themselves
"hi"         ⇝  (%string ...)
```

Ideal Stellogen promotes this from implementation detail to **contract**:
the encoding is specified in `KERNEL.md`, stable, and unique. It is layer
3's raw material — shape-checkers pattern-match against code terms, and
unification is exactly a code-pattern-matcher. No `quote` *primitive* is
needed; a thin `quote` *notation* (layer 2, possibly a no-op) marks term
position for the human reader.

### 2.3 The bracket overload, resolved by position

`[...]` means *cons list* in term position and *star* in constellation
position. The grammar is unambiguous (a star can never appear inside a
term); the hazard is only for the human reader. Ideal Stellogen keeps the
sugar and disarms it with one documentation rule: **inside parentheses,
brackets are data; at the top of a constellation, brackets are stars.**
No new delimiter — every candidate replacement costs more than the
confusion it removes.

---

## 3. Layer 1 — the meta kernel

The complete inventory. Each form must justify itself as *glue*; the day
one of them starts computing, it is drift.

| Form | Role | Justification as glue |
|---|---|---|
| `(def name e)` | bind | naming things |
| `(def (name p ...) e)` | parametric bind | naming families of things |
| `#name`, `#(name a ...)` | reference | using named things |
| `@e` | focus | marking state (shared with layer 0) |
| `(exec e ...)` | run, non-linear | the point of the language |
| `(fire e ...)` | run, linear | resource-aware variant |
| `(process e ...)` | run, chained | pipelines; built-in because it *orders* runs, which macros cannot honestly express without variadic recursion |
| `(show e)` | display | observation |
| `(== e1 e2)` | assert equal | comparison |
| `(~= e1 e2)` | assert compatible | comparison |
| `(forall g V e)` | iterate over galaxy | the one binder; needed by `::` |
| `(use "path")` | import | one form, files are files |
| `(macro (pat) (exp))` | fixed-arity rewrite | the tower's growth mechanism |

Thirteen forms. What is deliberately absent: closures, higher-order
functions, arithmetic, general recursion, conditionals, mutable state. With
variadic macros gone, macro expansion terminates structurally, so **the
meta-language is total** — every `.sg` file's elaboration halts; only layer
0 interaction may diverge. That property is worth more than any convenience
that would break it: it is what makes "the meta-language is just glue" a
theorem about the implementation rather than a slogan.

`spec` is *not* in this table: the audit is settled — it is a layer 2
macro (§4). The current builtin is *literally* `def` (`expression.ml:622`,
same match arm; galaxy formation included), so nothing about galaxy
semantics requires kernel support. Intent-marking is notation-layer work.

### Why layer 1 looks functional while layer 0 looks logical

This asymmetry is the classic architecture of logic frameworks, not an
accident to repair: ML was invented as the functional *meta-language* of
the LCF prover, whose distinguished datatype was `theorem`. Stellogen's
layer 1 is to constellations what ML was to LCF theorems — its only data
are terms and constellations, its only verbs are build, run, compare.
The mixing of flavours is the design.

---

## 4. Layer 2 — the standard prelude

The entire ideal prelude. Small enough to read over coffee; everything in
it is a fixed-arity macro over layers 0–1:

```stellogen
; prelude.sg — standard notation. No computation, only spelling.

; Type assertion: run every test in the galaxy, expect ok.
(macro (:: Tested Test)
  (forall Test T
    (== @(exec @#Tested #T) ok)))

; A spec is a def with intent: the thing defined is a test suite.
(macro (spec Name Tests)
  (def Name Tests))

; Field access over the fields *pattern* (records stay user space).
(macro (get G X)
  (exec #G @[(-field X)]))

; Term-position marker for reified code. Elaborates to the canonical
; %-encoding of E — possibly the identity, but the reader sees intent.
(macro (quote E)
  E)
```

Gone from the current prelude, by design: `stack`, `chain`, and the macro
version of `process` — all variadic, all replaced by either a built-in
(`process`) or by just writing the term (`(s (s 0))` is bearable, and
honesty about the encoding is a feature in a language whose subject matter
is encodings).

Layer 2 is where dialects live. A linear-logic library ships macros that
make proof structures pleasant to write; a Prolog-flavoured library ships
`:-`-ish notation if someone wants it. All of it elaborates away under
`sgen preprocess`, which is what keeps dialects cheap.

---

## 5. Layer 3 — systems and logics

A **system** is a triple *(notation, checker, guarantee)* packaged as one
file. The notation is layer 2 material; the checker is an ordinary
constellation that interacts with *reified code* (the §2.2 encoding); the
guarantee is a theorem on paper. Locking is an assertion, not a compiler
mode.

### 5.1 A shape system: `systems/acyclic.sg`

```stellogen
; systems/acyclic.sg
; GUARANTEE (thesis, Ch. 9): constellations whose dependency graph is
; acyclic terminate under exec. The checker accepts only such code.

(use "prelude.sg")

; The checker: ordinary stars that walk a %-encoded constellation,
; extract (symbol, polarity) pairs per star, build the dependency
; graph, and search for a cycle. Interaction yields `ok` iff none.
; Internal wiring symbols are prefixed (acyclic-...) by convention (§2.1).
(def acyclic-check
  {[(-check Code) (+acyclic-walk Code %nil)]
   ; ... graph construction and cycle search, ~20 stars ...
   })

; The lock: splice Body twice — in code position (the def) and in
; term position (the checker's input).
(macro (in-acyclic Name Body)
  { (def Name Body)
    (== @(exec @[(-check (quote Body))] #acyclic-check) ok) })
```

Using it:

```stellogen
(use "systems/acyclic.sg")

(in-acyclic add {
  [(+add 0 Y Y)]
  [(-add X Y Z) (+add (s X) Y (s Z))]})
; Admitted only if the checker accepts the *shape* of the code.
; By the paper theorem, (exec #add ...) terminates. That sentence —
; checker accepted, therefore property holds — is the entire meaning
; of "type system" here.
```

Note what did *not* happen: no compiler flag, no new judgment in the
kernel, no second semantics. Checking membership is itself stellar
resolution — the language applied to its own syntax. And not writing
`in-acyclic` is the escape hatch; no `unlock` keyword exists because none
is needed.

### 5.2 A logic: `logics/mll.sg`

The flagship (§8 of the evaluation doc). Same triple, richer content:

```stellogen
; logics/mll.sg
; GUARANTEE (paper): proof structures accepted by the correctness
; checker are exactly the MLL-sequentializable ones (Danos–Regnier).

(use "prelude.sg")

; Notation: macros for building proof structures as constellations —
; (ax A) (cut S1 S2) (tensor S1 S2) (par S) ...

; Checker: the switching/trip criterion as a test galaxy — each test
; is one switching; correctness = every interaction yields ok.
(spec mll-correct { ; one star-block per switching test ... 
  })

; A proof net is then certified the same way a nat is typed:
; (:: my-proof-structure mll-correct)
```

The pattern generalizes: `logics/` grows one file per certified fragment
— acyclic (termination), linear (`fire`-safety), MLL (correctness),
eventually shape hierarchies for complexity classes. Each file is
potentially a paper; the directory *is* the research program.

### 5.3 The file pragma, much later

Once two or more systems exist and are stable, a pragma can compress the
common case:

```stellogen
#system mll
; sugar for: (use "logics/mll.sg") + wrap top-level defs in the lock
```

A pragma, not a second reader. It is listed here only to mark the ceiling
of ambition: even the maximally polished experience is one line of sugar
over the library mechanism.

---

## 6. A complete ideal file, top to bottom

The house style — definitions, then tests, then assertions, then
demonstrations — with every layer visible:

```stellogen
; peano.sg — natural numbers, certified terminating.

(use "prelude.sg")                              ; layer 2: notation
(use "systems/acyclic.sg")                      ; layer 3: a system

; ── objects ────────────────────────────────────────────── layer 0
(in-acyclic add {
  [(+add 0 Y Y)]
  [(-add X Y Z) (+add (s X) Y (s Z))]})

; ── tests ──────────────────────────────────────────────── layer 0
(spec nat {
  [(-nat 0) ok]
  [(-nat (s N)) (+nat N)]})

; ── assertions ─────────────────────────────────────────── layer 2→1
(def two (+nat (s (s 0))))
(:: two nat)

(def four [(-add (s (s 0)) (s (s 0)) R) R])
(== @(exec #add @#four) [(s (s (s (s 0))))])

; ── demonstrations ─────────────────────────────────────── layer 1
(show (exec #add @#four))
```

Reading this file, the two languages are visually separable with no
training: everything inside `{...}`/`[...]` is chemistry (unordered,
interactive); everything at the spine of the file is bench work (ordered,
total, deterministic). One syntax carries both without ambiguity because
the three sigils — `+`/`-` polarity, `@` focus, `#` reference — mark
exactly the concepts that cross the boundary.

And the workbench session around it:

```
$ sgen run peano.sg          ; assertions checked, shows printed
$ sgen preprocess peano.sg   ; the same file, layers 2–3 elaborated away:
                             ; pure layer 0–1 forms — the trust witness
$ sgen trace peano.sg        ; fusion-by-fusion account of one exec
```

---

## 7. Syntax delta: current → ideal

| Item | Today | Ideal | Action |
|---|---|---|---|
| S-expressions, `;` comments | ✓ | ✓ | keep |
| Sigils `+ - @ #` | ✓ | ✓ | keep |
| `[...]` stars / `{...}` constellations | ✓ | ✓ | keep |
| `[a b]` cons sugar in term position | ✓, undocumented hazard | ✓, documented rule (§2.3) | document |
| `"strings"` | ✓ | ✓ | keep |
| `use` vs `use-macros` | two forms | one `use` | merge |
| `<f a b>` stack sugar | documented, **does not exist** | absent | fix CLAUDE.md |
| `stack`/`chain` variadic macros | in prelude | gone; write the term | remove |
| Variadic `macro` | supported | fixed-arity only | remove |
| `process` | prelude macro (variadic) | layer 1 built-in | promote **first**, then remove variadics |
| `spec` | built-in (identical code path to `def`) | layer 2 macro | demote — audit settled |
| Fields / `get` | user-space pattern | unchanged — never a kernel record system | keep out |
| `scope` / interfaces | absent | still absent — deferred; naming convention now, `(use ... (prefix ...))` at layer 1 if collisions ever bite (§2.1) | defer |
| `quote` | nothing (encoding implicit) | layer 2 no-op macro over documented encoding | document + add notation |
| `eval` | removed (commit 3025e62) | stays removed until a concrete staged-computation need | hold |
| Incremental parsing / error recovery | ~400 lines | gone | remove |
| `KERNEL.md` | absent | two parts: object kernel + meta kernel, with the sorting rule | write |

Net effect on the grammar: the ideal language is *strictly smaller* than
today's. Zero kernel additions — the one candidate (`scope`) was examined
and deferred, and the `spec` audit resolved to a demotion — plus one piece
of documentation promoted to contract (the `%`-encoding). That is the
"pure substrate without noise" instinct, made precise: purity is not a
rewrite, it is sixteen removals and one document.

---

## 8. Why this is the ideal and not a compromise

Three properties the tower buys, none of which a two-language (asm/C)
design or a richer meta-language could keep simultaneously:

1. **Self-extension is the product.** New logics are `use`-able files, not
   compiler forks — the thesis of the project, load-bearing in the design.
2. **The trust story is mechanically checkable.** `sgen preprocess`
   witnesses that everything above the double line elaborates away; the
   totality of layer 1 guarantees the witness always arrives. Per-system
   trust = small executor + readable checker + paper theorem.
3. **Homoiconicity across all four layers for free.** Checkers (layer 3)
   inspect code (layer 0) as plain terms because one syntax feeds one
   reader — the quotation problem never opens.

The kernel stays available as a compilation target for external front-ends
(the LLVM door), *because* layers 0–1 are small and documented. But the
project ships one language: this one.
