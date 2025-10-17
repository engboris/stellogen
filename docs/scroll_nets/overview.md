# Scroll Nets: Overview and Encoding Design

> Based on Pablo Donato's paper "Scroll nets" (arXiv:2507.19689)

## Abstract

This document explores the encoding of **scroll nets** in Stellogen, examining their theoretical foundations, design space, and connections to proof nets. Scroll nets are a graphical proof formalism based on Peirce's 19th-century existential graphs, extended via Curry-Howard methodology to represent proof objects statically.

The central insight is that scroll nets possess a **dual structure**: a **DAG** (the scroll structure, representing logical form) paired with a **forest with loops** (the argumentation/interaction, representing computational content). This duality mirrors Stellogen's own architecture and suggests natural encoding strategies.

## 1. What Are Scroll Nets?

### 1.1 Historical Context

Scroll nets originate from C. S. Peirce's **existential graphs** (EGs), a diagrammatic logic system from ~1896 that predates modern proof theory. EGs represent logical reasoning as topological transformations on a "sheet of assertion"—a spatial canvas where:

- **Juxtaposition** = conjunction
- **Scrolls** (nested closed curves) = implication
- **Illative transformations** = inference rules

Peirce emphasized **illative atomicity**: reasoning decomposes into atomic steps of insertion/deletion. Unlike symbolic logic's sequential manipulation of formulas, EGs embed statements in 2D space, enabling direct manipulation of nested contexts.

### 1.2 From Proof Traces to Proof Objects

Traditional EGs capture only **proof traces** (sequences of transformations) but lack explicit **proof objects** (static witnesses). Donato's contribution applies **Curry-Howard methodology**: just as lambda terms internalize natural deduction derivations, scroll nets internalize illative transformations within the syntax itself.

**Key idea**: Represent inference steps as **arrows** (justifications) connecting subgraphs, creating a static record of the proof construction process.

### 1.3 Formal Structure

A **scroll net** is a triple `⟨𝒮, 𝒜, ℐ⟩`:

1. **𝒮 (Scroll Structure with Sharing)**:
   - A **directed acyclic graph (DAG)** where nodes are either:
     - **Atoms** (labeled leaves)
     - **Seps** (closed curves, nodes in the DAG)
   - **Attachments** `𝒜tt ⊆ 𝔼`: edges connecting inloops to outloops of scrolls
   - **Polarity**: nodes at even depth are positive (+), odd depth are negative (-)
   - **Sharing**: DAG structure allows inloops to share children (unlike forests)

2. **𝒜 (Argumentation)**: A **directed forest** of:
   - **Justifications** `𝒥`: edges `u ⊢ v` representing iteration/deiteration
   - **Self-justifications** `ℬ`: loops representing insertion/deletion
   - Captures the "vehicle" (computational transport mechanism)

3. **ℐ (Interaction)**:
   - **Expansions** `𝒪`: opening transformations
   - **Collapses** `𝒞`: closing transformations
   - Act on scroll attachments (not nodes)

### 1.4 The Six Illative Transformations

Donato identifies six atomic proof steps, divided into two categories:

**Interaction rules** (act on scroll boundaries):
- **Open**: introduce empty scroll around a graph
- **Close**: eliminate empty scroll

**Argumentation rules** (act on graph content):
- **Insert**: introduce graph in negative context (assumption)
- **Delete**: eliminate graph from positive context (discard)
- **Iterate**: duplicate graph from source to positive target (copy)
- **Deiterate**: deduplicate graph from source to negative target (share)

These correspond precisely to structural rules in sequent calculus, but applicable at **any depth** (deep inference).

## 2. Encoding Approaches in Stellogen

Stellogen's core features align remarkably well with scroll nets:

| Scroll Net Concept | Stellogen Analog |
|-------------------|------------------|
| Scroll structure (DAG) | Constellation graph (stars+rays) |
| Polarity (+/-) | Ray polarity (+/-) |
| Justifications (forest) | Interaction paths via unification |
| Illative transformations | Fusion/interaction dynamics |
| Atoms | Variables or function symbols |
| Scrolls (implication) | Nested constellations |

### 2.1 Approach A: Direct Graph Encoding

**Strategy**: Represent scroll nets as explicit graph data structures using Stellogen terms.

**Scroll structure as terms**:
```stellogen
' Node: (node id polarity children)
' Scroll: (scroll outloop inloop)
' Atom: (atom id label)

(:= example_scroll {
  [(+structure [
    (scroll
      (node 1 pos [(atom 2 a)])
      (node 3 neg [(atom 4 b)]))])]})
```

**Argumentation as justification graph**:
```stellogen
' Justification: (just source target)
' Self-justification: (self node)

(:= argumentation {
  [(+args [
    (just 1 2)
    (self 3)])]})
```

**Pros**:
- Explicit control over graph structure
- Easy to inspect/debug
- Direct translation from paper's formalism

**Cons**:
- Does not leverage Stellogen's unification-based computation
- Requires explicit rewrite rules for normalization
- Verbose representation

### 2.2 Approach B: Unification-Native Encoding

**Strategy**: Exploit term unification to **implicitly encode** scroll net dynamics. The scroll structure becomes a **pattern space**, and argumentation emerges from **complementary polarities** seeking unification.

**Core insight**: Donato notes that scroll nets have four types of "detours" (redexes). In Stellogen, detours could manifest as **opposite-polarity rays** that unify, triggering reduction automatically.

**Scroll as nested constellation**:
```stellogen
' Scroll [A ⊸ B] encoded as layered contexts
(:= scroll_impl {
  [(+outloop A)]    ' antecedent (positive context)
  [(+inloop B)]     ' consequent emerges after interaction
  [(-scroll X) (+impl X)]})  ' scroll elimination
```

**Justification as shared variables**:
```stellogen
' Iteration: same variable X appears in multiple locations
' Unification automatically connects them
(:= iterated {
  [(+source X)]
  [(+target1 X)]  ' justified by source
  [(+target2 X)]  ' also justified by source
})
```

**Detour as complementary rays**:
```stellogen
' Detour: node is both introduced and eliminated
(:= detour {
  [(+intro (scroll A B))]   ' introduced (opened/iterated)
  [(-elim (scroll A B))]    ' eliminated (closed/deleted)
  ' These rays unify → automatic reduction!
})
```

**Pros**:
- Normalization emerges "for free" from unification
- Compact representation (sharing via variables)
- Aligns with Stellogen's philosophy (computation = unification)

**Cons**:
- Less explicit structure (harder to inspect)
- Requires careful polarity management
- May need inequality constraints `|| (!= X Y)`

### 2.3 Approach C: Hybrid (Recommended)

**Strategy**: Use explicit graph structure for the **scroll structure** (DAG), but **implicit argumentation** via unification patterns.

**Rationale**:
- The scroll structure (logical form) is static → explicit encoding aids clarity
- The argumentation (computational content) is dynamic → implicit encoding leverages Stellogen's strength

**Example**:
```stellogen
' Explicit scroll structure
(:= scroll_dag {
  [(+node 1 [pos (scroll 2 3)])]
  [(+node 2 [pos (atom a)])]
  [(+node 3 [neg (atom b)])]})

' Implicit justifications via shared variables
(:= proof {
  [(-node N1 Content) (+source Content)]    ' node N1 justified
  [(+source X) (+target X)]                  ' iteration via sharing
  @[(-target Y) (conclusion Y)]})            ' final output
```

This combines:
- **Inspectability** (explicit scroll structure)
- **Automatic normalization** (implicit dynamics)

## 3. Key Design Challenges

### 3.1 Representing Sharing (DAG vs Forest)

Scroll structures are **DAGs**, not forests, because inloops can share children. In Stellogen:

**Option 1**: Explicit parent lists
```stellogen
(:= shared_node (node id [parent1 parent2] content))
```

**Option 2**: Multiple references to same variable
```stellogen
{
  [(+inloop1 X)]   ' X has two parents
  [(+inloop2 X)]   ' implicitly forms DAG
  [(+content X (atom a))]  ' X is shared
}
```

Option 2 aligns better with Stellogen's unification semantics.

### 3.2 Polarity Tracking

Scroll nets rely on **depth-based polarity**: even depth = positive, odd = negative. In Stellogen:

**Option A**: Explicit depth/polarity annotations
```stellogen
(:= node (nd id depth content))
```

**Option B**: Polarity via nesting in constellations
```stellogen
{
  [(+outer A)]          ' depth 0 (positive)
  [(+scroll [
    [(-inner B)]        ' depth 1 (negative)
    [(+inloop [
      [(+deep C)]])])]  ' depth 2 (positive)
}
```

Option B mirrors the paper's topological interpretation.

### 3.3 Detour Elimination Without Explicit Rewrites

Donato's paper sketches four detour types (ii, ia, ai, aa) with diagrammatic reduction rules. The challenge: **can these emerge from unification alone**?

**Hypothesis**: Yes, if we encode detours as **opposite-polarity rays seeking fusion**.

Example (ii-detour: interaction/interaction):
```stellogen
' Opened then closed scroll
(:= ii_detour {
  [(+opened (scroll A B))]
  [(-closed (scroll A B))]
  ' These unify → scroll disappears, B remains
  [(+result B)]})
```

The unification of `+opened` and `-closed` on the same scroll term triggers the reduction. The constellation's interaction rules handle the rest.

**Challenge**: Formalizing all four detour types this way requires careful design of the encoding scheme.

## 4. Why Stellogen Is Well-Suited

### 4.1 Shared Philosophical Foundations

Both scroll nets and Stellogen reject:
- **Primitive types**: Meaning emerges from interaction, not predefined categories
- **Fixed logical framework**: The system is logic-agnostic

Both embrace:
- **Spatial reasoning**: Nested contexts, depth-based semantics
- **Curry-Howard**: Proofs as computational objects
- **Minimalism**: Elementary building blocks compose into complex behavior

### 4.2 Technical Alignments

| Feature | Scroll Nets | Stellogen |
|---------|-------------|-----------|
| Fundamental mechanism | Term matching + polarity | Term unification + polarity |
| Reduction | Detour elimination | Fusion |
| Structure | DAG + Forest | Constellation graph |
| Sharing | Inloops share children | Variables unify |
| Nesting | Scrolls nest arbitrarily | Stars nest in constellations |

### 4.3 The "Vehicle" Analogy

Donato describes argumentation as **Girard's vehicle**: a directed structure that transports justifications. In proof nets, the vehicle is the axiom/cut links. In scroll nets, it's the forest of justifications.

Stellogen's **interaction mechanism** plays precisely this role: rays with opposite polarities "seek each other out" via unification, creating a computational flow that mirrors the vehicle's transport function.

## 5. Open Research Questions

### 5.1 Completeness of Unification-Based Normalization

**Question**: Can all four detour types be encoded such that unification alone performs reduction, without explicit rewrite rules?

**Approach**: Formalize each detour as a constellation pattern where complementary rays unify. Verify that:
1. Unification preserves boundaries (premiss/conclusion)
2. Reduction terminates
3. Normal forms correspond to detour-free scroll nets

### 5.2 Correctness Criterion as Stellogen Type

In the paper, a scroll net is **correct** iff there exists a derivation from its premiss. Can this be encoded as a Stellogen type specification?

```stellogen
(spec correct_scroll_net {
  [(-premiss P) (-scroll_net S) (+derivation P S) ok]
  ' S is correct if we can derive it from P
})
```

This would enable **type checking = proof checking**.

### 5.3 Bigraph Connection

Donato notes scroll nets resemble **bigraphs**: a place graph (DAG) + link graph (hypergraph). Bigraphs have:
- Compositional semantics
- Categorical models

Can we leverage bigraph theory to understand scroll net composition in Stellogen?

## 6. Next Steps

1. **Implement core primitives**: Define atoms, scrolls, justifications
2. **Encode simple examples**: Identity, modus ponens
3. **Test normalization**: Verify detour elimination emerges from interaction
4. **Formalize correctness**: Translate Donato's criterion to Stellogen
5. **Explore extensions**: Classical logic, first-order logic, modalities

## References

- Pablo Donato, "Scroll nets," arXiv:2507.19689, 2025
- C. S. Peirce, "Prolegomena to an Apology for Pragmaticism," 1906
- Jean-Yves Girard, "Linear Logic," 1987
- Milner, "Bigraphical Reactive Systems," 2001

---

**Key Takeaway**: Scroll nets are not just encodable in Stellogen—they reveal **why Stellogen's architecture works**. The DAG + forest duality, polarity-driven interaction, and emergence of computation from unification are all design patterns vindicated by Donato's independent discovery in proof-net theory.
