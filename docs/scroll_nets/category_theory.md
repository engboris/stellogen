# Scroll Nets: Category-Theoretic Perspective

> Exploring the algebraic structure of scroll nets

## Abstract

This document examines scroll nets through the lens of **category theory**, exploring their compositional structure, connections to **bigraphs** and **string diagrams**, and potential categorical semantics. We investigate how the dual nature of scroll nets (DAG + forest) might be understood categorically, and what this reveals about their computational properties.

## 1. The Dual Structure

### 1.1 Two Independent Graphs

A scroll net consists of:

1. **Scroll structure (𝒮)**: A **directed acyclic graph (DAG)**
   - Represents **logical form** (formulas, nesting)
   - Nodes: atoms + seps (closed curves)
   - Edges: parent-child relationships
   - Special edges: **attachments** (inloop → outloop)

2. **Argumentation (𝒜)**: A **directed forest + loops**
   - Represents **computational content** (proof steps)
   - Nodes: Same as scroll structure
   - Edges: **justifications** (u ⊢ v)
   - Loops: **self-justifications** (assumptions/deletions)

**Key insight**: These are **two graphs on the same vertex set** but with **independent edge sets**.

### 1.2 Analogy: Bigraphs

Donato notes that scroll nets resemble **bigraphs** (Milner, 2001):

**Bigraph** = **topograph** (place/nesting) + **monograph** (linking/connectivity)

| Bigraph Component | Scroll Net Analog |
|-------------------|-------------------|
| Topograph (forest) | Scroll structure (DAG) |
| Monograph (hypergraph) | Argumentation (forest) |
| Vertices | Nodes (atoms + seps) |
| Controls (node types) | Polarity (+/-)  |

**Extensions**:
- **Bigraphs with sharing** (DAG topograph) ↔ Scroll structures with sharing
- **Directed bigraphs** (oriented monograph) ↔ Argumentation forest

**Significance**: Bigraphs have:
- **Compositional semantics** (horizontal and vertical composition)
- **Categorical models** (symmetric monoidal categories, adhesive categories)
- **Reactive systems** (graph rewriting with contexts)

Can we import these frameworks into scroll net theory?

## 2. Compositionality

### 2.1 Two Composition Operations

Donato defines:

#### Horizontal Composition (⊔)

**Definition**: Disjoint union of scroll nets
```
𝒩₁ ⊔ 𝒩₂ = ⟨𝒮₁ ⊔ 𝒮₂, 𝒜₁ ⊔ 𝒜₂, ℐ₁ ⊔ ℐ₂⟩
```

**Semantics**: Parallel execution (conjunction)
```
premiss(𝒩₁ ⊔ 𝒩₂) ≅ premiss(𝒩₁) ∧ premiss(𝒩₂)
conclusion(𝒩₁ ⊔ 𝒩₂) ≅ conclusion(𝒩₁) ∧ conclusion(𝒩₂)
```

**Category theory**: This is a **monoidal product** (⊗).

#### Vertical Composition (∘)

**Definition**: Sequential composition when `conclusion(𝒩₁) ≅ premiss(𝒩₂)`
```
𝒩₂ ∘ 𝒩₁ = superposition of 𝒩₂ onto conclusion of 𝒩₁
```

**Semantics**: Sequential execution (implication)
```
premiss(𝒩₂ ∘ 𝒩₁) = premiss(𝒩₁)
conclusion(𝒩₂ ∘ 𝒩₁) = conclusion(𝒩₂)
```

**Category theory**: This is **morphism composition** (∘).

### 2.2 Category of Scroll Nets

**Tentative definition**:

- **Objects**: Scroll structures (boundaries)
- **Morphisms**: Scroll nets 𝒩 : 𝒮₁ → 𝒮₂ where:
  - premiss(𝒩) = 𝒮₁
  - conclusion(𝒩) = 𝒮₂
- **Identity**: Empty scroll net (no justifications/interactions)
- **Composition**: Vertical composition (∘)

**Challenge**: Donato notes that superposition (the definition of ∘) is **not fully formalized**. Key questions:
1. Is composition **well-defined**? (Does it depend on choice of derivation?)
2. Is composition **associative**? (Does (𝒩₃ ∘ 𝒩₂) ∘ 𝒩₁ = 𝒩₃ ∘ (𝒩₂ ∘ 𝒩₁)?)
3. Does identity satisfy laws? (𝒩 ∘ id = id ∘ 𝒩 = 𝒩)

**Conjecture**: Correct scroll nets form a **category** under vertical composition.

### 2.3 Monoidal Structure

**Horizontal composition** adds monoidal structure:

- **Monoidal product**: ⊔
- **Unit**: Empty scroll net
- **Coherence**: (𝒩₁ ⊔ 𝒩₂) ⊔ 𝒩₃ ≅ 𝒩₁ ⊔ (𝒩₂ ⊔ 𝒩₃)

**Interchange law**: Does horizontal and vertical composition interact coherently?
```
(𝒩₂ ⊔ 𝒩₄) ∘ (𝒩₁ ⊔ 𝒩₃) = (𝒩₂ ∘ 𝒩₁) ⊔ (𝒩₄ ∘ 𝒩₃)
```

If yes, scroll nets form a **symmetric monoidal category**.

### 2.4 Comparison to Other Formalisms

| Formalism | Objects | Morphisms | Monoidal Product |
|-----------|---------|-----------|------------------|
| **Proof nets** | Formulas | Proof nets | ⊗ (tensor) |
| **String diagrams** | Objects | Morphisms (boxes) | ⊗ |
| **Scroll nets** | Scroll structures | Scroll nets | ⊔ (disjoint union) |

**Key difference**: Scroll nets have **richer boundaries** (DAGs, not just lists of formulas).

## 3. Polarity and Interaction

### 3.1 Polarity as Orientation

**Scroll structure polarity**: Determined by **depth** (even = +, odd = -)

**Argumentation polarity**: Determines **direction** of justification:
- **Positive target**: Iteration (copy into)
- **Negative target**: Deiteration (remove from)

**Category theory analog**: **Oriented graphs** or **signed edges** in multicategories.

### 3.2 Interaction as Annihilation

**Observation**: Opening and closing (expansions/collapses) are **adjoint**:
- **Expansion** (⊸): Introduce scroll (left adjoint?)
- **Collapse** (⊸⁻¹): Eliminate scroll (right adjoint?)

**Detour** (ii-type): Expansion followed by collapse = **counit** of adjunction?
```
𝒮 --expand--> [(  𝒮  )] --collapse--> 𝒮
```

This resembles **string diagram yanking** (straightening a bent wire).

### 3.3 Linear Logic Connection

**Observation**: Argumentation rules resemble **linear logic structural rules**:
- **Insert** ↔ Weakening (⊢ A, Γ from ⊢ Γ)
- **Delete** ↔ Coweakening (⊢ Γ from ⊢ A, Γ)
- **Iterate** ↔ Contraction (⊢ A, A, Γ from ⊢ A, Γ)
- **Deiterate** ↔ Cocontraction (⊢ A, Γ from ⊢ A, A, Γ)

**Interaction rules** ↔ **Exponentials** (! and ?):
- Scrolls "box" content (like ! boxes in proof nets)
- Expansions/collapses manage boxing depth

**Speculation**: Scroll nets might be a **2-dimensional linear logic**, where:
- 1st dimension: Formula structure (scroll DAG)
- 2nd dimension: Proof structure (argumentation forest)

## 4. Categorical Semantics

### 4.1 Desiderata

A categorical semantics for scroll nets should:
1. **Interpret scroll structures** as objects in a category
2. **Interpret scroll nets** as morphisms
3. **Validate composition** (show ∘ is associative, etc.)
4. **Soundness**: Valid derivations map to valid morphisms
5. **Completeness** (ideal): Every morphism arises from a scroll net

### 4.2 Candidate Categories

#### Option A: Sets and Relations

- **Objects**: Scroll structures
- **Morphisms**: Relations between boundary atoms
- **Composition**: Relational composition

**Pro**: Simple, well-understood
**Con**: Ignores proof structure (only tracks input/output)

#### Option B: Coherence Spaces

- **Objects**: Coherence spaces (formulas with cliques)
- **Morphisms**: Linear maps (proof nets)
- **Scroll nets**: Embedded via lambda calculus encoding

**Pro**: Connects to linear logic semantics
**Con**: Not a direct interpretation (indirect via STLC)

#### Option C: Adhesive Categories

- **Objects**: Graphs (scroll structures as graph objects)
- **Morphisms**: Graph homomorphisms
- **Rewriting**: Bigraphical reactive systems

**Pro**: Handles graph structure natively, supports rewriting
**Con**: Abstract, requires substantial categorical machinery

#### Option D: Stellogen Constellations (Novel!)

- **Objects**: Stellogen types (specs)
- **Morphisms**: Constellations (scroll nets as terms)
- **Composition**: Process chaining or superposition

**Pro**: Direct computational interpretation
**Con**: Requires formalizing Stellogen category-theoretically

### 4.3 Towards a Stellogen-Based Semantics

**Proposal**: Interpret scroll nets in a **category of Stellogen programs**:

**Objects**: Types (specs)
```stellogen
(spec scroll_structure {
  [(-structure S) (+valid S) ok]})
```

**Morphisms**: Constellations (scroll nets)
```stellogen
(:= scroll_net_morphism {
  [(-input S1)]
  [(+justification S1 S2)]  ' Argumentation
  [(+interaction S1 S2)]    ' Interaction
  @[(+output S2)]})
```

**Composition**: Process construct
```stellogen
(:= compose (process
  Net1     ' First morphism
  Net2))   ' Second morphism (acts on output of Net1)
```

**Identity**: Trivial scroll net (no transformations)
```stellogen
(:= id {
  [(-input S) (+output S)]})
```

**Challenge**: Prove:
1. Composition is associative
2. Identity laws hold
3. This interpretation is sound (valid scroll nets → valid programs)

## 5. The DAG + Forest Structure

### 5.1 Categorical Product?

**Observation**: A scroll net is **not** just a product 𝒮 × 𝒜:
- The vertices are **shared** between 𝒮 and 𝒜
- The edges are **independent**

**Better model**: A scroll net is a **span** in the category of directed graphs:
```
          𝒮
         /
    V  /
        \
         𝒜
```
Where:
- V = shared vertex set
- 𝒮 and 𝒜 are graphs over V with disjoint edge sets

### 5.2 Fibration/Opfibration?

**Speculation**: The scroll structure could be a **fibration** over the argumentation:
- **Base**: Argumentation (computational flow)
- **Fiber**: Scroll structure (logical form)
- **Projection**: Maps nodes to their polarity/depth

This would formalize the intuition that argumentation **drives** computation, while scroll structure **constrains** it.

### 5.3 Grothendieck Construction?

**Wild idea**: Could scroll nets arise from a **Grothendieck construction**?
- **Base category**: Argumentation (forest as category)
- **Fibered category**: For each node, the scroll structure "above" it
- **Total category**: Scroll nets

This remains highly speculative but could unify the two structures.

## 6. Interaction Nets Connection

### 6.1 Lafont's Interaction Nets

**Interaction nets** (Lafont, 1990):
- Graphs with typed nodes (agents)
- Edges connect ports
- **Interaction rules**: Local rewriting between adjacent agents

**Similarities to scroll nets**:
- Graph-based computation
- Local rewriting (detour elimination ↔ interaction rules)
- Polarity (ports have directions)

**Differences**:
- Interaction nets: **flat** (no nesting)
- Scroll nets: **nested** (scrolls within scrolls)

### 6.2 Interaction Combinators

**Interaction combinators** (Lafont, 1997): Minimal interaction net system with 3 agents:
- **γ** (constructor)
- **δ** (duplicator)
- **ε** (eraser)

**Analogy to scroll nets**:
- **Scroll introduction** ↔ Constructor
- **Iteration** ↔ Duplicator
- **Deletion** ↔ Eraser

**Question**: Can scroll nets be encoded in interaction combinators? If so, normalization inherits their properties (strong confluence, polynomial complexity).

## 7. Adjunctions and Duality

### 7.1 Illative Transformation Pairs

Many illative transformations come in **dual pairs**:

| Left | Right | Relationship |
|------|-------|--------------|
| Open | Close | Adjoint? |
| Insert | Deiterate | Adjoint? |
| Iterate | Delete | Adjoint? |

**Hypothesis**: These are **adjoint functors** in some category of scroll nets.

**Evidence**:
- Each pair creates then eliminates structure (unit/counit?)
- Detours arise when adjoints compose (β-redex?)

**Challenge**: Formalize the categories in which these are adjunctions.

### 7.2 Polarity Duality

**Observation**: Positive and negative contexts are **dual**:
- Positive: Iteration, deletion
- Negative: Deiteration, insertion

**Category theory**: **Opposite categories** (ℂᵒᵖ)?
- A positive-context operation in ℂ
- Becomes a negative-context operation in ℂᵒᵖ

**Implication**: Scroll nets might have a **self-dual** structure (like classical linear logic).

## 8. Monoidal Closed Structure

### 8.1 Internal Hom

**Question**: Do scroll nets have an **internal hom** [A ⊸ B]?

**Intuition**: A scroll structure is **exactly** an internal hom:
- Scroll [A ⊸ B] = "A implies B"
- Outloop = A (input)
- Inloop = B (output)

**Monoidal closed category**:
- **Tensor**: ⊔ (horizontal composition)
- **Internal hom**: Scrolls
- **Adjunction**: [A ⊸ B] ⊗ A ⊣ B

This would make scroll nets a **model of linear logic**.

### 8.2 Curry-Howard for Linear Logic

**Linear logic** has a well-known categorical semantics:
- **Formulas** = Objects
- **Proofs** = Morphisms
- **Proof nets** = Graphical morphisms

**Scroll nets** could provide an **alternative** graphical syntax:
- More **topological** (2D nesting)
- Less **sequential** (DAGs, not trees)
- More **interactive** (explicit proof traces)

## 9. Open Problems

### 9.1 Formalize Composition

**Problem**: Rigorously define vertical composition (∘) and prove:
- Well-defined (independent of derivation choice)
- Associative
- Has identities

**Approach**: Use **sequentialization theorem** (every scroll net has a canonical derivation).

### 9.2 Prove Coherence

**Problem**: Show that horizontal and vertical composition satisfy **interchange law** (making scroll nets a 2-category or double category).

**Approach**: Case analysis on derivation rules, show they respect 2D structure.

### 9.3 Find Functors

**Problem**: Define functors between scroll nets and other categorical structures:
- **F**: Scroll nets → Proof nets
- **G**: Lambda calculus → Scroll nets
- **H**: Scroll nets → Bigraphs

Show that these preserve composition.

### 9.4 Characterize Normal Forms

**Problem**: What is the **image** of the normalization functor?

**Question**: Do normal forms correspond to **cut-free** proofs or **β-normal** λ-terms?

**Conjecture**: Normal scroll nets = Detour-free scroll nets = Some canonical form in target category.

## 10. Stellogen-Specific Insights

### 10.1 Constellations as Morphisms

**Insight**: Stellogen constellations are already **morphism-like**:
- Input: Negative rays
- Output: Positive rays
- Computation: Fusion (composition)

**Hypothesis**: The **category of constellations** is isomorphic to (a subcategory of) **scroll nets**.

### 10.2 Unification as Composition

**Insight**: Term unification performs **variable substitution**, which is a form of **composition**:
- Terms with holes (variables) = Objects with boundaries
- Substitution = Gluing boundaries together
- Unification = Finding compatible boundaries

**Implication**: Stellogen's unification might **naturally implement** scroll net composition!

### 10.3 Polarity as Variance

**Insight**: In category theory, **contravariance** (ℂᵒᵖ) flips arrows.

**Analogy**:
- Positive polarity = **Covariant** (direction-preserving)
- Negative polarity = **Contravariant** (direction-reversing)
- Scrolls = **Profunctors** (ℂᵒᵖ × 𝔻 → Set)

This could explain why polarities alternate in nested contexts!

## 11. Future Directions

### 11.1 Bigraphical Reactive Systems

**Goal**: Formalize scroll nets as **BRS** (bigraphical reactive systems):
- Scroll structure = Place graph
- Argumentation = Link graph
- Detour reduction = Reaction rules

**Benefit**: Import results from BRS theory (modularity, bisimulation).

### 11.2 Adhesive Categories

**Goal**: Show scroll nets form an **adhesive category**:
- Objects = Scroll structures (as graphs)
- Morphisms = Graph homomorphisms
- Pushouts satisfy adhesive property

**Benefit**: Use double-pushout rewriting for detour elimination.

### 11.3 Higher Categories

**Goal**: Formalize scroll nets as a **bicategory** or **double category**:
- 0-cells = Scroll structures
- 1-cells = Scroll nets (morphisms)
- 2-cells = Derivations (proof traces)

**Benefit**: Capture the distinction between proof objects and proof traces categorically.

## Conclusion

Scroll nets exhibit rich categorical structure:
- **Monoidal** (horizontal composition)
- **Compositional** (vertical composition)
- **Dual** (polarity)
- **Adjoint** (illative transformations)

The dual DAG + forest structure resembles **bigraphs**, suggesting:
- Place graph = Scroll structure (logical nesting)
- Link graph = Argumentation (computational flow)

Key open problems:
1. Formalize composition rigorously
2. Prove coherence laws
3. Find functors to/from other categories

**Stellogen connection**: If constellations form a category, scroll nets provide:
- **Proof-theoretic semantics** (what do constellations mean?)
- **Compositional reasoning** (how do constellations combine?)
- **Optimization theory** (detour elimination = categorical equivalence?)

**Philosophical insight**: Category theory reveals that scroll nets are not ad hoc—they're a **natural structure** arising from the interplay of **nesting** (DAG) and **flow** (forest), unified by **polarity** (adjunction).

---

**Key takeaway**: Scroll nets are **2-dimensional proofs** where:
- 1st dimension = Logical structure (vertical nesting)
- 2nd dimension = Computational structure (horizontal flow)
- Category theory = Algebra of their composition

This duality is **fundamental**, not accidental—it reflects the Curry-Howard principle at a deeper level.
