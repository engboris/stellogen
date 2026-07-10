# Local Modalities: Synchronization, Linearity, and Staging as Star/Ray Properties

**Date:** 2026-07-10
**Status:** Design note, open question, nothing implemented. Prompted by
revisiting the boolean-circuit synchronization problem (`examples/circuits.sg`
and `docs/synchronization_in_circuits.md`, both removed 2025/2026 as
unfinished — see section 9) and `meta_kernel.md` section 3's observation that
`then` is kernel debt.

---

## 1. The problem: circuits need synchronization `exec` doesn't give locally

A gate with two inputs must not fire until both inputs are concrete. Nothing
in stellar resolution enforces this, because a star is an unordered set of
rays and the executor is free to pick any compatible pair. Minimal repro:

```stellogen
(def semantics {
  [(+and 1 V V)]
  [(+and 0 V 0)]
})

(def gate @[(-in1 X) (-in2 Y) (-and X Y R) (+out R)])

(show (exec #semantics #gate))
```

With no `in1`/`in2` facts yet (they are still "waiting on an upstream gate"),
the current executor's ray scan (`try_ray` in `src/eval/executor.ml`) tries
ray 0, finds no match, tries ray 1, finds no match, tries ray 2 — and
`(-and X Y R)` matches the semantics table directly, since X and Y are still
bare unification variables and unify trivially with either fact. Both
`(+and 1 V V)` and `(+and 0 V 0)` match, `find_action_matches` collects both,
and the engine produces two speculative branches (`X:=1` and `X:=0`) before
either input has said anything. Whichever branch turns out to disagree with
the real input later just sits as dead residue — not an error, silently
wrong/incomplete output next to the right one.

`examples/binary4.sg`'s existing gates avoid this by baking literal 0/1 into
each rule at macro-expansion time (`(if A = 0 and B = _ then R = 0)`) rather
than using one free variable across a semantics table shared by both
branches, so the query ray is never that unconstrained. That sidesteps the
bug in one style of encoding without fixing the underlying gap.

## 2. Rejected fix: whole-star groundness ban

The obvious move is to reuse the existing `ban` mechanism that already
backs `!=`/`slice` (`src/core/constellation.ml`, `star.bans`), adding a
`Ground of ray` constructor checked by `coherent_bans`
(`src/eval/executor.ml`). This does not work: `coherent_bans` re-checks the
*entire* merged ban list on *every* single-ray fusion the star undergoes,
not just the fusion touching the guarded variable. Disequality survives
this because "not syntactically equal" is trivially true while a variable
is unbound and only becomes a real check once both sides resolve.
Groundness has the opposite shape — "not yet ground" is true by default and
only flips at the resolving step — so a `Ground R` ban would reject the
*first* fusion of the star (e.g. consuming `-in1`, unrelated to `R`) just as
hard as it (correctly) rejects consuming `+out R` early. The gate could
never start.

The right hook, if this route were taken, is inside candidate generation
(`raymatcher`/`find_action_matches`), checked once at the exact moment the
guarded ray is proposed as a fusion candidate, not as a whole-star
post-condition re-evaluated on unrelated steps.

## 3. Superseded fix: strict left-to-right ("sequential star")

A second candidate: mark a star as ordered and only ever offer its leftmost
unconsumed ray as a fusion candidate (in both `try_state_star` and
`find_action_matches`). This fixes the race (an output ray placed after its
inputs textually cannot be reached before they're gone) but is stronger
than necessary: it forces even commutative premises into an arbitrary total
order. `[(-parent X Y) (-parent Y Z) ...]` has no real dependency between
its two premises — either may resolve first — and a strict order would
block legitimate concurrent progress for no reason.

## 4. Lock/open: a join instead of a queue

The better shape: partition a star's rays into **open** (freely matchable,
any order, independently) and **locked** (ineligible until every open ray
of the same set has vanished). This is a join/barrier, not a queue:

```stellogen
[open (-in1 X) (-in2 Y)] [locked (-and X Y R) (+out R)]   ; syntax TBD
```

Order among `in1`/`in2` doesn't matter — whichever resolves first, resolves
first — but neither `-and` nor `+out` becomes a candidate until *both* are
gone. This fixes the AND-gate race without over-constraining commutative
premises, and it composes: once the open set is exhausted the locked rays
behave exactly as today (no order preference among themselves either,
unless further partitioned).

## 5. Generalizing scope: from one star to the whole constellation — recovering `then`

Lock scoped to a single star does not reach `then`. `then`'s job is
cross-constellation: stage 2's rules must treat stage 1's *entire result*
(however many stars it ends up as, produced by fusions inside stage 1) as
settled, and stage 1's result isn't one star with a fixed, known-in-advance
ray list. It's also blocked by the state/action tagging rule (a freshly
fused result is always retagged State, so two independently State-tagged
stars can never fuse directly) — an orthogonal reason `then`'s staging
exists at all, already covered by the `then` fix landed earlier this cycle
(the final-step-unfocused change to `src/core/expression.ml`).

The generalization that recovers `then`: let the open/locked tag be a
**stage number on a ray**, and check it globally, over every live ray in the
constellation currently being executed, not just a ray's own star: *no ray
tagged stage N+1 is a fusion candidate while any ray tagged stage N still
exists anywhere in the state*. That reproduces `then`'s entire left fold —
for arbitrarily many stages, not just two — as a property attached to data,
with no meta-level fold operator and no repeated refocus-and-reexec calls.

## 6. The larger unification: one `exec`, modalities as local tags

**`linear` on a star, subsuming `fire`, is done** (2026-07-10): `fire` is
removed; `*star` is a per-star tag orthogonal to `@`, mirroring focus
exactly (`*{...}` marks every star of a group consumable, same as `@{...}`
does for focus). `Marked.star` carries the flag alongside State/Action;
`find_ray_fusions` checks the star's own flag instead of a global
`exec_config.linear`. See `KERNEL.md` 1.4/1.5 for the settled semantics.

Still open: **`stage` on a ray**, which would subsume `then` the same way,
per section 5. `(then c1 c2 c3)` would become `exec` with `c1`'s rays
tagged stage 0, `c2`'s stage 1, `c3`'s stage 2 — a strictly stronger
version of what `meta_kernel.md` section 3 already argues for `then`
alone. Section 7's open question (scope of a "wave") blocks this half.

## 7. Open question: what is the scope of a "wave"?

If two independently-authored `then`-style pipelines are dumped into the
same `exec` call, a single global stage counter makes them wrongly block on
each other — pipeline A's stage 3 would wait on pipeline B's unrelated
stage 2 just because the numbers collide. The tag likely needs to be
`(namespace, stage)` rather than a bare integer, with `then`'s expansion
minting a fresh namespace per invocation, rather than one global counter
per `exec` call. Not resolved; needs deciding before any of section 6 is
implementable, since it changes what the `stage` tag actually *is*.

## 8. Status

The `linear`-tag half of section 6 is implemented (see above). Lock/open
synchronization (section 4) and the `stage` tag for `then` (sections 5, 7)
remain open; sections 2–3 are recorded as rejected/superseded so they
aren't re-discovered from scratch. See `issue_backlog.md` for scheduling.

## 9. Relationship to prior work

`docs/synchronization_in_circuits.md` (removed, commit history ~Oct 2025)
explored seven fixes for the circuit-only version of this problem and
recommended a `!X` groundness marker checked at unification time —
essentially section 2 above, independently reached and independently
rejected here once checked against the actual fusion loop.
`examples/circuits.sg` itself was removed marked `FIXME`, with a half-sketched
`|| (! X)` constraint that was never wired up — the instinct was already
there, just not the mechanism. Lock/open (section 4) supersedes that
recommendation with something that also resolves `then`'s staging, unifying
two previously-separate concerns into one.
