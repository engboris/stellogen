# TUNES and Stellogen: Is There a Real Connection?

**Date:** 2026-07-14
**Status:** analysis and opinion, written in response to people suggesting
Stellogen / transcendental syntax could have a role in TUNES, or even be
"a key" to it. No action required; a recommendation is at the end.

---

## 1. What TUNES actually is

TUNES (tunes.org) is a project started in 1992-95 by François-René Rideau
and others, out of the remains of the MOOSE OS project. The stated aim was
a "free reflective computing system": a unified system where the OS, the
language and the user environment are one reflective whole, built around a
High-Level Language (HLL) and a Low-Level Language (LLL), with orthogonal
persistence, migration of objects between machines and representations,
and metaprogramming everywhere.

Two facts matter before any comparison:

1. **TUNES never existed as software.** In thirty years it produced
   essays, a language review wiki, and almost no code. The front page
   itself now says the project "was never clearly defined, and it
   succumbed to design-by-committee syndrome and gradually failed."
2. **TUNES is inactive.** The wiki froze around 2006, the mailing list is
   a marginally active group of a couple dozen people. Whoever approached
   you speaks for an intellectual tradition and a small community of
   admirers, not for a living engineering project that could adopt
   Stellogen.

So the question "could Stellogen be a key to TUNES" cannot mean "should
Stellogen join TUNES". It can only mean: does transcendental syntax answer
questions TUNES posed and failed to answer, and is that lineage worth
engaging with?

## 2. Where the resonance is real

Reading the TUNES HLL "semantic principles" next to the thesis, the
overlap is not superficial. Several of their founding requirements are
close to restatements of the Stellogen philosophy, written twenty years
earlier from the systems side instead of the logic side.

**Uniformity.** TUNES: "All computer abstractions are made equal in the
same whole system, whether you give them the name object, function, term,
pattern, or whatever." Stellogen is an extreme execution of this: there is
exactly one raw material (terms, stars, constellations) and both programs
and their meanings (tests, types, proofs) are made of it. TUNES asked for
uniformity; stellar resolution says what the uniform substance is.

**Security through specifications, with meaning owned by the user.**
TUNES: "Objects come with their full specification, so that system
security is never endangered", with the note that specifications may
involve proofs in computational logic, at multiple levels of confidence.
This is the closest single point of contact. Types-as-tests is exactly a
regime where every block carries the checks it must pass, where the
trusted base is minimal (unification plus the base observations `==`/`~=`)
and where the *strength* of a specification is chosen per module rather
than fixed by a global type system. The thesis's "open proof assistant"
horizon (logic as a library, several logics coexisting, certainty relative
to tests known to be adequate) is essentially the mechanism TUNES's
security principle presupposed but never had.

**Reflection and self-extension.** TUNES: "The language can talk about
itself, manipulate code at any level"; "the syntax must be able to evolve
according to the context." The epidictic-as-macro-system reading (thesis
conclusion, and Stellogen's actual macro layer) matches this: a minimal
object level plus a user-extensible meta level, where "closed systems" and
logics are built as syntax on top rather than baked in.

**Genericity and precision.** TUNES wanted a language where nothing forces
you to overspecify or underspecify, and where no arbitrary restriction is
added. A logic-agnostic substrate where typing discipline is opt-in,
per-value, and user-defined is a coherent answer to that pair of demands.
Conventional typed languages structurally cannot satisfy both; Stellogen
was designed around exactly this refusal to impose a fixed discipline.

There is also a diagnostic resonance. TUNES failed, by its own admission,
because it demanded a unified reflective substrate and never identified
one. Every candidate (Lisp variants, CLOS, Self, Smalltalk, their HLL-
sketches) already carried too much commitment. Transcendental syntax is a
serious, technically worked-out proposal for what such a neutral substrate
could be: computation as primitive, meaning reconstructed by interaction
and testing. In that precise sense the people who contacted you are not
wrong: TS addresses the hole at the center of TUNES.

## 3. Where the resonance breaks down

**Most of TUNES is somewhere Stellogen doesn't go and shouldn't.** The
requirements list is dominated by systems engineering: orthogonal
persistence, garbage collection, migration between machines, scheduling
and parallelism directives, partial evaluation, hardware consciousness,
interactive development, integration with foreign systems. Stellogen has
nothing to say about these today, and its known complexity issues (thesis,
"Complexity issues": graph isomorphism in concrete execution, exponential
correctness tests) make it a poor candidate for the performance-critical
lower layers. Being "a key to TUNES" would require accepting the whole
requirements list; that is a trap, not an opportunity.

**"Reflection" means different things in the two traditions.** TUNES means
runtime reflection: a running system inspecting and rewriting its own
implementation, compilers manipulating their own intermediate
representations. Transcendental syntax is foundational reconstruction:
logic rebuilt from computation. The slogans align ("no fixed semantics
imposed from above") but the technical content barely intersects. Mapping
one onto the other takes real work that nobody has done, and hand-waving
that gap is how projects like TUNES accumulated their reputation.

**The "universal neutral substrate" pitch has prior art the TUNES
community already knew.** Rewriting logic (Meseguer, Maude) was explicitly
marketed as a universal logical framework; so were LF/Twelf, λProlog, and
in a different way ludics. TUNES reviewed several of these and adopted
none. Stellar resolution differs in substance (the Usine/tests apparatus,
no primitive judgement at all, asynchronous unification as the only
mechanism), but anyone claiming TS is "the key" should be able to say why
it succeeds where rewriting logic, which had a mature implementation and a
large community, did not move TUNES an inch. The honest answer is that
TUNES's problem was not a missing formalism.

**A dead project confers no momentum.** Association with TUNES buys a very
small audience and a strong odor of vaporware. TUNES is remembered, when
it is remembered, as the canonical example of a maximal vision with zero
deliverables. That is precisely the perception risk Stellogen already
manages by calling itself an experimental proof of concept and shipping
runnable examples.

## 4. The uncomfortable mirror

The real value of studying TUNES is not the ideas overlap, it is the
failure-mode overlap. TUNES died from: a vision stated only at the level
of principles; refusal to commit to a domain; every concrete step looking
too small compared to the vision; energy going into essays and reviews of
other systems rather than artifacts. Stellogen's open question ("should
this be general-purpose or find a niche") is the same fork TUNES faced,
and TUNES chose "general, later" every time until there was no later.

The lesson runs opposite to the suggestion you received. The way for
Stellogen to matter is not to attach itself to the largest available
vision; it is to keep producing small, checkable, runnable things (the
prelude, proof nets as tests, the phase separation, the exercises) that a
TUNES could never show. If anything, Stellogen is an argument that the
TUNES program only becomes tractable once you shrink it to one question:
what is the minimal substrate on which meaning can be user-built and
mechanically checked? That question Stellogen actually answers.

## 5. Verdict

Is there true relevance? **Intellectually, yes, and it is specific**: the
uniformity principle, the security-via-carried-specifications principle,
and the self-extension principle of the TUNES HLL are early, informal
statements of things transcendental syntax makes precise, and the "open
proof assistant" direction is close to what TUNES's security story always
needed. It is fair, and true, to say Stellogen inhabits a corner of the
design space TUNES pointed at and never reached.

Is Stellogen "a key to the project"? **No, because there is no project.**
There is a body of requirements prose, a frozen wiki, and a community
memory. A key to a door with no building behind it. And the parts of TUNES
that were a real engineering agenda (persistence, migration, an OS) are
the parts Stellogen has no stake in.

## 6. If you engage

Worth doing, cheap, and honest:

- A short essay (blog or `ai/research` graduating to the wiki) reading the
  TUNES HLL principles through transcendental syntax: which ones stellar
  resolution satisfies by construction, which ones become user-space
  practices (types as tests), which ones are out of scope. This is a good
  vehicle for explaining Stellogen to the systems-language audience, and
  the TUNES vocabulary (uniformity, genericity, specifications carried by
  objects) is a useful bridge.
- If the people who approached you want more, ask them for the concrete
  artifact they have in mind. "X could be key to TUNES" has been said of
  many systems since the 90s and has never once produced code. A specific
  proposal (say, a TUNES-style module system where linking is test
  passage) could become a Stellogen example; a general alliance cannot.

Not worth doing: adopting TUNES branding, scope, or requirements;
positioning Stellogen as a TUNES successor; spending implementation effort
on persistence/migration-style features to fit their list.
