# A Macro/Alias System for Terms-by-Default

**Date:** 2026-07-07
**Status:** Design note. Companion to `evaluation_and_directions.md`
(sections 3.2, 5.2, 5.3) and `refocusing_plan.md` (2.8). Written after the
`spec` demotion attempt was overturned; the failure exposed what a good
macro system looks like under Stellogen's design premises.

---

## 1. The inversion

The Lisp macro tradition assumes code-by-default: an s-expression is code
unless quoted, the hazard is data accidentally treated as code, and the
defenses (unbound-identifier errors, phase separation, hygiene) are all
built on binding structure.

Stellogen inverts the premise. Terms are the default: an expression is
inert data unless its head is a kernel form or a macro in scope. There is
no such thing as an unbound identifier, because every symbol is a
legitimate term constructor. The hazard inverts accordingly: not data
treated as code, but **notation treated as data**. A `(spec nat {...})`
whose alias is not in scope does not error; it quietly becomes an inert
term. This silent fallthrough is what killed the `spec` demotion (see the
overturn note in evaluation_and_directions.md, section 5.3), and it is the
central problem any macro/alias design here must answer.

Racket's defenses cannot be imported, because they hang off binding
structure Stellogen deliberately does not have: symbols are addresses, not
bindings (locativity). A global "unknown head is an error" rule is also
unavailable, and should not be wanted: shape checkers receive code as
terms precisely because unrecognized forms are data. Making unknown heads
an error would destroy the code-as-term contract (KERNEL.md, part III).

The conclusion is that the right toolkit is not Scheme's (binding-based)
but a term-rewriting system's: symbol maps, arity discipline,
position-based errors, and variable freshening. Four pillars.

---

## 2. Pillar 1: errors on meaningless positions, not unknown names

You cannot detect unknown names, but you can detect positions where a bare
term is meaningless. A top-level expression that is neither a kernel form
nor a macro call evaluates to a term that is immediately discarded: dead
code at the spine of the file. That is exactly what a `spec` call without
its alias becomes.

**Proposal: "top-level expression has no effect" is a warning or error.**
Zero loss of expressiveness (a discarded term does nothing by
definition), and it converts the silent-fallthrough hazard into a loud
diagnostic at the only place it matters.

Precedent: Prolog reached the same compromise from the same premise.
Atoms are always legal data, but an unknown predicate in *call position*
raises an existence error. Stellogen's call position is the file spine.

**The same principle extends one level down, into interaction spaces.**
Inner expressions cannot be checked by name (an unknown head is
legitimate data anywhere), but they can be checked for meaninglessness
in *run positions*: an action star with no polarized ray can never fuse,
so inside an `exec`/`fire` space it is dead weight, discarded unused.
Unexpanded notation that lands in an interaction space typically becomes
exactly that, a neutral-headed single-ray star. So "this execution
received an action star that cannot interact" is the object-level
analogue of the dead-spine check. Two cautions: the diagnostic belongs at
the point where a constellation *enters an interaction space*, never at
definition (constellations stored purely as data for checkers are the
code-as-term contract working as intended); and "has no polarized ray"
must follow whatever eligibility rule the kernel specifies for depth
(KERNEL.md 1.2). What remains genuinely undetectable is unknown-name
notation sitting in a pure data position, and that is irreducible by
design: it *is* data, semantically indistinguishable from intended data.

## 3. Pillar 2: arity near-miss diagnostics

A head that names a known macro but matches no pattern of the call's
arity, e.g. `(:: a)` or a seven-group `spec` under patterns covering
arities 2 to 5, is almost never intended as data. It falls through
silently today.

**Proposal: "head matches macro `name` but no pattern of arity n" is a
warning or error.** Cheap, precise, and together with pillar 1 it
recovers most of the safety Racket gets from unbound identifiers without
touching the semantics. Unlike pillar 1, this check applies at **any
depth**: expansion already walks the whole tree, so a known name at the
wrong arity is detectable inside terms too, not only at the spine. The
blind spot is names not in scope at all; those are covered at the spine
by pillar 1, in run positions by the inert-star check, and in pure data
positions by nothing, correctly.

## 4. Pillar 3: the symbol map as the aliasing/namespacing backbone

Racket's rename transformers, `free-identifier=?`, and prefixed imports
are one idea, operations on bindings. The terms-by-default analogue is a
read-time symbol-to-symbol map, applied at head position. It unifies two
already-recorded needs:

- **Aliases**: a `macro` whose pattern is a bare symbol,
  `(macro spec def)`, rewriting the head at any arity. This is the `spec`
  demotion path (evaluation doc 5.3 update note) and makes intent
  vocabulary (`axiom`, `lemma`, practice variants) cheap user space. The
  surface shape `(macro sym sym')` is currently unoccupied grammar.
- **Import prefixing**: `(use "lib.sg" (prefix lib))`, the escalation
  path recorded for the deferred scoping question (evaluation doc 5.1),
  is the same map applied in batch at import time.

One mechanism, two granularities. Trivially total: a finite symbol map;
alias cycles are detectable at definition time by following the chain.
The assembler analogy holds: assemblers have no bindings either, and what
they provide is exactly this, `EQU` aliases and label prefixing, not
hygiene.

## 5. Pillar 4: context-blind expansion, and hygiene for variables only

Two decisions, one already made correctly (by accident), one a real gap.

**Expansion stays context-blind.** The expander rewrites macro calls
everywhere, including inside term position. This is correct and should be
documented as a decision: if expansion skipped term positions, reified
code would contain unexpanded notation while the code that ran was
expanded, and a shape checker would inspect a different program than the
one executing. Uniform expansion is what keeps quotation free. The cost,
that notation heads cannot be mentioned as inert data, is acceptable; an
escape hatch (a no-expand marker) is only worth designing when a concrete
need arrives.

**Freshen macro-introduced variables.** The only binders in the language
are star-local variables, and expansion can capture them: a macro body
that introduces `X` into a star where the user's argument also mentions
`X` silently shares it. Example: `(macro (tag R) [R (+tag X)])` applied
to `(-f X)` yields `[(-f X) (+tag X)]`, one shared `X` where two distinct
variables were meant. Hygiene for Stellogen is therefore much smaller
than for Scheme: **rename variables introduced by macro bodies to fresh
names, per expansion, and the problem is closed.** Symbols stay
unhygienic because being unhygienic is their semantics (addresses).
Caution: audit existing macros for deliberate capture before enabling
this; any macro relying on sharing a variable with its call site would
break.

---

## 6. Deliberately not proposed

- Phase separation, binding-aware hygiene, `free-identifier=?` analogues:
  they require binding structure the language rightly lacks.
- Signature declarations (Maude-style declared operators, opt-in per
  file): would give errors for undeclared heads, but heavier than
  pillars 1+2 and against the grain of terms-by-default.
- Any change to terms-by-default itself. The premise survives contact
  intact; it wants rewriting-world tools, not binding-world tools.
- Variadic patterns: their removal stands. Aliases handle the one case
  (variadic form aliasing) that fixed arity cannot.

---

## 7. Actions, in order of value

1. **Dead-spine diagnostic** (pillar 1): warning/error on top-level
   expressions with no effect. Catches missing notation imports,
   including the `spec` case. Its object-level companion, "action star
   with no polarized ray entered an interaction space", covers inner run
   positions and folds naturally into the planned empty-result
   diagnostics (evaluation doc 7.3). Diagnostics work, Phase 5 spirit.
2. **Arity near-miss diagnostic** (pillar 2). Diagnostics work, Phase 5
   spirit.
3. **Expansion cycle/depth guard**: already recorded in the plan (2.7
   note); discharges the acyclicity obligation KERNEL.md 2.5 currently
   places on the user. Small language work.
4. **Bare-symbol alias patterns** (pillar 3): implement when a second
   intent-marker is wanted; `spec` demotes with it. Small language work.
5. **Variable freshening** (pillar 4): after the deliberate-capture
   audit. Small language work, needs the audit first.

Items 1 to 3 are unconditionally good. Items 4 and 5 change surface
behavior and should each land with their first real client.
