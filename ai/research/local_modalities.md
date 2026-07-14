# Join Synchronization: One `exec`, Circuits as Linear Nets

**Date:** 2026-07-14 (third revision, same day: supersedes the `?`
lock proposal of the previous revision; section 9 records what it
taught)
**Status:** design proposal, not implemented. The `*` (linearity)
modality is implemented (`KERNEL.md` 1.4/1.5). Converged with Boris
after working the boolean circuit example end to end.

---

## 1. Goal

One notion of execution. Everything that used to be a separate engine
or operator should be a property carried locally by the program and
read off by the one fusion loop: `fire` became the `*` star tag, and
`then` may one day become a `stage` tag (section 10). This revision's
finding is that circuits, the example that motivated a synchronization
modality, need no new modality at all: they need the missing half of
fusion, the join.

## 2. What circuits do today

`examples/circuits.sg` (the contradiction `(and A (not A))` and the
excluded middle `(or A (not A))`, linear gates, reusable truth tables,
`==` acceptance assertions) is a FIXME: with plain gates it diverges,
and with `*` gates the contradiction on input 1 yields

```
{ [(+c3 0) (-c3 1) 1] [(+c3 0) (-c3 0) 0] }
```

instead of `0`. Decoding: the AND gate reached the truth table while
its `c3` input was still an unbound variable, matched both rows, and
the star split into one branch per guess (`(-c3 1)` and `(-c3 0)` are
the guesses; the `(+c3 0)` next to them is the real value). The value
could never reach the gate because both rays ended up in the same
star, and rays of one star never fuse. Appendix A holds the measured
traces, including the variable-capture bug in fusion renaming that
these experiments flushed out (found and fixed 2026-07-14).

## 3. Diagnosis: no data/program duality in a circuit

The engine splits every execution into states and actions, and only
ever fuses a state ray against an action star. The action pool is an
implicit exponential: actions enjoy contraction (duplicated at each
use) and weakening (dropped unused), so every interaction is data
against a reusable program, stars under `!`.

A boolean circuit is exponential-free. Each gate fires once, each wire
carries one value and is consumed once. There is no program side: the
whole circuit is one linear net, and evaluating it is cut elimination
inside that net. The engine implements only cut-against-program, so it
structurally cannot normalize a closed linear object. It is telling
that `examples/proofnets/mll.sg` never hits this: types-as-tests
reintroduces an interactive duality (tested against test), so the
state/action split fits. A circuit computing its own output has no
tester/tested division. This diagnosis is Boris's: the problem is not
waiting, it is that two parallel strands of one computation cannot be
joined.

The state/action split itself is best understood as a proof-search
strategy that quietly became semantics. It is the set-of-support
restriction from resolution theorem proving: never resolve two axioms
together, only clauses connected to the goal set. The restriction
exists for a good reason (rule-against-rule saturation explodes, and
query-against-database programs stay efficient under it), but circuits
and proof nets are goal-set-only objects: everything is in the
problem, nothing is an axiom. A strategy should not make such objects
inexpressible.

## 4. The proposal: the join

Read `(+c3 R)` and `(-c3 X)` as two parallel strands that must meet:
the fork duplicated the token, one branch produced the wire value, the
other is waiting for it. A wire is a rendezvous point and the fusion
of its two dual rays is the join event.

**Rule: a state ray may fuse with a dual, unifiable state ray, whether
it lives in another state star or in the same star (the internal
cut).** Both matched rays disappear, the substitution applies to the
merged (or same) star, bans are re-checked.

Notes:

- Waiting needs no annotation. A `-c3` that has not met its `+c3` is
  simply not joined yet; the polarity structure already encodes the
  synchronization.
- The fork needs nothing: one star with two output rays
  (`[(-c0 X) (+c1 X) (+c2 X)]`) was always expressible.
- Wires are point-to-point (one `+c3`, one `-c3`), so each join has a
  unique partner: joins in a circuit are deterministic, like cuts in a
  correct proof net. A join with several dual partners branches, as
  fusion already does.
- Result collectors should be reusable, not `*`: a collector is an
  observer, not a resource. A linear collector turns scheduling luck
  into which branch gets observed (measured in appendix A).
- Self-copy fusion (a star against a fresh copy of itself, Girard's
  self-interaction) stays excluded: it is where infinite behaviors
  come from, and circuits do not need it.

### 4.1 Reading `@` as solution membership

With the join in place, the marks stop meaning data and program and
read chemically:

- `@` (focused): **in the solution**. Reactive, consumed by reacting,
  part of the observable result.
- unmarked: **a catalyst**. Duplicable, passive (participates when a
  reactive star solicits it), inert toward other catalysts, dropped
  from the result.

"Everything interacts with everything without distinction", the
complex-system reading Boris asked for (atoms and molecules), then
needs no new operator. It is expressible with existing syntax by
focusing the whole object:

```stellogen
(exec @{#contradiction (+c0 1)} #semantics)
```

Everything inside the braces is in the soup and mutually reactive
through the join; the truth tables catalyze from outside. How much of
a program is focused places it on a spectrum: one focused query
against a database of rules is goal-directed search (the old
data/program reading, still the efficient default for Datalog-style
programs), and a fully focused constellation is a computational graph
with information flowing, a circuit or a proof net normalizing by
internal cuts. The distinction becomes a property the user asserts
about the objects, not a truth the engine imposes, which is the
language's philosophy anyway.

A pleasant consequence: gates stop needing `*`. The divergence of
section 5 comes from encoding gates as duplicable actions; as focused
stars they are consumed by construction, linear by being in the
solution rather than by annotation. The circuit encoding becomes
markless except the single `@`.

## 5. Linearity, and why gates encoded as actions diverge

Measured fact: with gates as plain (duplicable) actions, the bare
diamond diverges. A dangling gate input like `(-c3 X)` unifies with
the output ray `(+c3 R)` of a fresh copy of the upstream gate, whose
own input pulls a fresh copy of the gate before it, around the cycle
forever. Backward chaining through unconsumed premises turns a
reusable gate set into an infinite gate factory. Marking gates `*`
removes the implicit `!` and stops this.

Under the focused encoding of 4.1 the question dissolves: gates are
in the solution, consumed by construction, and no `*` is needed
anywhere in a circuit. `*` keeps its role for the cases it was made
for: single-use catalysts, and practices like `::lin` where the test
side must not duplicate. Discipline for circuits: net focused, truth
tables catalytic, nothing marked.

## 6. The open decision: join versus query ordering

At the critical star `[(+c3 0) (-c3 X) (-and X 1 R) (+c4 R)]` two
events are possible: the join on `c3`, or the table query by
`(-and X 1 R)` with X unbound. To the engine the unbound query is the
relational question "for which X does and(X, 1, R) hold?", answered by
both rows. The circuit meant X as an input in transit. Three policies:

1. **Explore both** (pure saturation). Sound and complete; the correct
   branch normalizes cleanly, speculative branches survive as stuck
   stars with clashing residue. A cleanliness convention (keep only
   stars with no polarized ray) filters the result. Cost: wasted
   branches, up to exponential in gate count, and `==` acceptance
   needs the filter in front.
2. **Join-priority.** While a join involving a variable V is available
   in a star, rays containing V are not candidates against the action
   pool. The diamond becomes deterministic with zero annotations: the
   join binds X first, one table row matches, the run ends in `[0]`.
   Complete for circuits (point-to-point wires). In relational code it
   is a real commitment: an internal joinable pair could suppress an
   action alternative that saturation would have explored, though dual
   pairs inside one state star barely occur in that style. Note this
   reuses the scoped-lock insight from the superseded `?` design: the
   held-back rays are exactly those sharing variables with the pending
   join.
3. **Explicit locks** (`?` marks). A manual approximation of policy 2,
   written by the programmer. Superseded (section 9).

Recommendation: policy 2 as the default eligibility rule, with policy
1 measured against it on the test suite before committing. The
difference only appears when an internal join and an action match
compete over the same variable.

## 7. Acceptance

`examples/circuits.sg` as it stands: contradiction and excluded
middle, written markless in the focused encoding of 4.1, and

```stellogen
(== (exec @{#contradiction (+c0 1)} #semantics) 0)
(== (exec @{#excluded_middle (+c0 0)} #semantics) 1)
```

Under the join with join-priority the contradiction runs: the token
joins the fork, the branches join the NOT and AND gates, the NOT row
binds `c3`, the internal join binds X, a single AND row fires, the
collector joins and leaves `[0]`. The assertions as written assume
policy 2 (or policy 1 plus the cleanliness filter folded into the
success convention).

## 8. Costs and open questions

- **Semantic change.** State stars that today sit inert holding dual
  unifiable residue would start reacting, across stars and internally.
  Audit the test suite under the new rule; if something legitimately
  relies on inert residue, the fallback is an opt-in switch, which
  would quietly reintroduce a mark.
- **Join-priority completeness.** Characterize exactly when policy 2
  prunes relative to saturation (an internal joinable pair sharing a
  variable with a ray that also matches an action).
- **Implementation.** Candidate search gains a state-to-state pass and
  an intra-star pass; saturation counts joins as progress; the
  eligibility check for policy 2 is a variable-connectivity pass over
  one star (stars are small). Cost is quadratic only in state stars
  that hold polarized rays.
- **The missing cell of the marks, for later.** Under the 4.1 reading,
  `@` and `*` span a matrix with one dead entry: linearity currently
  means nothing on a focused star, since reacting already consumes it.
  Giving that cell the dual meaning (a focused star that *persists*
  through its reactions: a reactive catalyst, a molecule that
  survives) would complete the chemistry and open autocatalytic,
  genuinely complex-system behavior, with divergence as the user's
  responsibility, consistent with logic-agnosticism. Not needed by
  circuits; recorded as the natural extension.

## 9. Superseded designs, kept so they are not rediscovered

- **Groundness ban** (`!X`, a `Ground` ban constructor). Wrong hook:
  `coherent_bans` re-checks the whole ban list on every fusion, and
  "not yet ground" is true by default, so the guard rejects the star's
  first unrelated fusion. The removed
  `docs/synchronization_in_circuits.md` (~Oct 2025) reached the same
  idea; the removed original `circuits.sg` carried unwired `|| (! X)`
  sketches. The instinct (do not fire on unbound wires) survives as
  join-priority.
- **Sequential star** (strict left-to-right ray consumption). Fixes
  the race but forces commutative premises into an arbitrary order.
- **The `?` lock design** (previous revision of this document, same
  day). Obligation marks on rays, a scoped lock, mark persistence
  through fusion, and discharge against actions, other states, or the
  own star. What it got right survives: the discharge cases are
  exactly the join of section 4, and the scoped-lock condition (hold
  back rays sharing variables with pending obligations; a whole-star
  lock deadlocks schedule-dependently on parallel branches joining
  into a gate) reappears as policy 2's trigger. What it got wrong:
  the waiting does not need annotation, polarity already encodes it,
  and a lock modality would have been a manual join-priority.

## 10. Still open: staging and `then`

`then` is cross-constellation: stage 2 must treat stage 1's entire
result as settled. A `stage` tag on rays, checked globally (no ray of
stage N+1 is a candidate while any stage-N ray lives in the state),
would fold `then` into `exec` the way `fire` folded into `*`. Blocker
unchanged: two independent pipelines in one `exec` must not block on
each other, so the tag is probably `(namespace, stage)` with `then`
minting a fresh namespace. Decide before implementing. `then` itself
works as a built-in; this is kernel debt, not a bug.

## 11. Status

`*` implemented. The join (section 4) is the kernel proposal: fusion
between dual focused rays, across and within stars, no new syntax.
With it, `@` reinterprets as solution membership (4.1): fully focused
constellations are the symmetric, everything-interacts mode (circuits,
proof nets, complex systems), and the state/action split survives as
the set-of-support strategy at the other end of the spectrum. The
ordering policy (section 6) is the one open decision, join-priority
recommended, to be validated in two steps (join alone first, then the
priority rule, auditing the test suite at each step).
`examples/circuits.sg` is the acceptance target in the markless
focused encoding; its `==` assertions turn green when the join lands.
The variable-capture renaming bug found during this work is fixed
(appendix A). See `issue_backlog.md` for scheduling.

---

## Appendix A: measured traces (2026-07-14)

The diamond circuit run on the current engine, before any of this
design exists, separates three pathologies. All runs post-date the
renaming fix below unless said otherwise.

**Without `*`: divergence.** The bare encoding does not terminate:
backward chaining through unconsumed premises (section 5) unrolls the
diamond forever. Killed by timeout; the trace shows the cycle
`-c3 -> fresh NOT copy -> -c1 -> fresh fork copy -> +c2 -> fresh AND
copy -> -c3`.

**With `*`, without the join: speculation and a stuck pair.** Input 1
with a linear collector gave
`{ [(+c3 0) (-c3 0) (+c4 0)] [(+c3 0) (-c3 1) 1] }`: the wrong guess
stole the collector and the right branch starved. With a reusable
collector both branches finish,
`{ [(+c3 0) (-c3 1) 1] [(+c3 0) (-c3 0) 0] }`, which is the honest
current output: both guesses, each carrying the residue that convicts
or acquits it. The two encodings of the fork (splitter through a
`(+s X X X)` row, or inlined in the gate star) produce byte-identical
results; an apparent difference between them was an artifact of the
pre-fix capture bug below.

**Variable capture, an engine bug found by these traces** (fixed
2026-07-14). `replace_indices` renamed a star's variables by stamping
one uniform index on all of them, so two same-named, still-unbound
variables that earlier fusions had correctly kept distinct as
`(R, i)`/`(R, j)` collapsed into one variable at the next fusion.
Binding one then bound the other: pre-fix, the NOT output leaked into
the AND result and the circuit printed a spurious single-star result.
Minimal repro, no circuits involved (A's variable must become 5 via t,
B's must become 7 via u, both named R):

```stellogen
(show (exec
  {[(-a) (+t R) (o1 R)]
   [(-b) (+u R) (o2 R)]
   [(-t 5)] [(-u 7)]}
  @[(+a) (+b)]))
; pre-fix: [(o1 5) (+u 5) (o2 5)], o2 captured; renaming B's variable
; to S changed the result, violating alpha-equivalence
; post-fix: [(o1 5) (o2 7)] regardless of naming
```

Wiki-style programs bind variables within a step or two, which is why
this went unnoticed; wire-style programs keep unbound variables alive
across many fusions and triggered it reliably. Fix:
`injective_renaming` in `src/core/constellation.ml` gives each
distinct variable its own fresh index instead of a uniform stamp.
Regression test: `test/syntax/var_renaming.sg`.

Division of labour, observed rather than argued: `*` removes the
divergence, the join removes the stuck pair, and the ordering policy
(section 6) decides what happens to speculation. The renaming fix was
a prerequisite for any of it to be measurable.
