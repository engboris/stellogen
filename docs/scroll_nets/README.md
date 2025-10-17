# Scroll Nets in Stellogen

> Exploring Pablo Donato's scroll nets as a programming paradigm in Stellogen

## Overview

This directory contains comprehensive research on **scroll nets**—a graphical proof formalism based on C. S. Peirce's 19th-century existential graphs—and their natural encoding in Stellogen.

**Paper**: Pablo Donato, "Scroll nets," arXiv:2507.19689, 2025

## What Are Scroll Nets?

Scroll nets are a proof system where:
- **Judgments = Statements** (scribing on a "sheet of assertion")
- **Inference = Manipulation** (inserting, deleting, copying content)
- **Proofs = Traces** (the history of manipulations, frozen as arrows)
- **Computation = Elimination** (removing detours/redexes)

**Key insight**: Construction and execution follow the **same rules** (illative transformations).

## Why Stellogen?

Scroll nets and Stellogen share remarkable similarities:

| Scroll Nets | Stellogen |
|-------------|-----------|
| Term unification + polarity | Term unification + polarity |
| DAG (scroll structure) | Constellation graph |
| Forest (argumentation) | Interaction paths |
| Detour elimination | Fusion |
| Depth-based polarity | Nested contexts |
| Sharing via DAGs | Sharing via variables |

**Both are logic-agnostic**: meaning emerges from interaction, not predefined types.

## Documentation Structure

### 1. [overview.md](./overview.md)
**Core concepts and encoding design**

- What scroll nets are (formal definition)
- Historical context (Peirce's existential graphs)
- Three encoding approaches:
  - A: Direct graph encoding (explicit)
  - B: Unification-native (implicit, leverages Stellogen's strength)
  - C: Hybrid (recommended)
- Design challenges (sharing, polarity, detour elimination)
- Why Stellogen is well-suited

**Start here** to understand scroll nets and how they map to Stellogen.

### 2. [correctness.md](./correctness.md)
**Test-based validation**

- The correctness problem (not all scroll nets are valid)
- Donato's sequential criterion (derivability from premiss)
- Geometric criteria (acyclicity, polarity, scope)
- Test-based validation in Stellogen (via `spec`)
- Hybrid approach (fast geometric tests + sequential validation)

**Read this** to understand how to distinguish valid from invalid scroll nets.

### 3. [normalization.md](./normalization.md)
**Detour elimination and computation**

- Four detour types (ii, ia, ai, aa)
- Donato's reduction rules (experimental)
- Unification-based normalization (emergence hypothesis)
- Why some detours require explicit composition
- Connection to lambda calculus β-reduction
- Termination and confluence (open problems)

**Read this** to understand how scroll nets compute and why normalization is challenging.

### 4. [programming_paradigm.md](./programming_paradigm.md)
**Scroll nets as a programming language**

- Construction = Execution (the central insight)
- Programming by demonstration (PbD)
- Peirce's rules as imperative commands
- Edit history as computation history
- Scroll nets as interactive, visual, proof-carrying programs
- Tomas Petricek's insight: "logically grounded foundational PbD system"

**Read this** for philosophical insights about what scroll nets reveal about programming.

### 5. [category_theory.md](./category_theory.md)
**Categorical structure and semantics**

- Dual structure (DAG + forest) as bigraphs
- Horizontal (⊔) and vertical (∘) composition
- Scroll nets as a monoidal category (conjectured)
- Polarity as adjunction
- Connection to linear logic and interaction nets
- Stellogen constellations as categorical morphisms

**Read this** for the algebraic/mathematical perspective on scroll nets.

### 6. [examples.sg](./examples.sg)
**Concrete Stellogen encodings**

- Basic primitives (atoms, scrolls, polarity)
- Six illative transformations (open, close, insert, delete, iterate, deiterate)
- Four detour types with reduction examples
- Identity function and modus ponens
- Justification forests and DAG sharing
- Correctness specs and normalization
- Lambda calculus encoding

**Run this file** to see scroll nets in action in Stellogen.

## Key Findings

### 1. Scroll Nets Vindicate Stellogen's Design

The DAG + forest duality, polarity-driven interaction, and emergence of computation from unification are design patterns **independently discovered** by Donato in proof-net theory. This validates Stellogen's architecture.

### 2. Partial Emergence of Normalization

Simple detours (ii, ai) can reduce via unification alone. Complex detours (ia, aa) require explicit graph composition. Full emergence remains an aspirational goal.

### 3. Programming by Demonstration Potential

Scroll nets blur the line between:
- Proof construction and execution
- Programming and theorem proving
- Syntax and semantics

This suggests a **new programming paradigm** where programs are demonstrations, and execution is proof search.

### 4. Category-Theoretic Foundations

Scroll nets are not ad hoc—they exhibit monoidal structure, adjunctions, and connections to bigraphs and linear logic. This provides algebraic foundations for understanding Stellogen.

## Open Research Questions

1. **Completeness of unification-based normalization**: Can all detours be eliminated via unification?
2. **Geometric correctness criterion**: Are acyclicity + polarity + scope sufficient?
3. **Termination and confluence**: Does normalization always terminate? Is the result unique?
4. **Categorical semantics**: Do scroll nets form a symmetric monoidal category?
5. **Expressiveness**: Are scroll nets Turing-complete (with cyclic scrolls)?
6. **Efficiency**: What is the complexity of detour elimination?

## Practical Next Steps

### For Experimenters
1. Run `examples.sg` to see encodings in action
2. Implement simple examples (identity, modus ponens)
3. Test automatic reduction via unification

### For Theorists
1. Prove correctness of geometric criteria
2. Characterize normal forms
3. Formalize composition operations

### For Language Designers
1. Design visual editor for scroll nets
2. Implement interactive proof assistant
3. Explore applications (verified compilation, proof search)

## Connections to Existing Work

### In Stellogen Codebase
- `examples/mll.sg`: Proof net correctness via tests (similar philosophy)
- `examples/lambda.sg`: Lambda calculus encoding (scroll nets generalize this)
- `examples/automata.sg`: State machines (justifications as transitions)

### In Proof Theory
- Girard's proof nets (linear logic)
- Hughes' combinatorial proofs
- String diagrams (categorical logic)
- Deep inference (calculus of structures)

### In Programming Languages
- Visual/dataflow languages (LabVIEW, Pure Data)
- Interactive theorem provers (Coq, Lean)
- Term rewriting systems
- Graph rewriting (Maude, GrGen)

## Further Reading

**Primary source**:
- Pablo Donato, "Scroll nets," arXiv:2507.19689, 2025
- Available at: https://arxiv.org/abs/2507.19689

**Background**:
- C. S. Peirce, "Prolegomena to an Apology for Pragmaticism," 1906
- Jean-Yves Girard, "Linear Logic," Theoretical Computer Science, 1987
- Robin Milner, "Bigraphical Reactive Systems," CONCUR 2001

**Related Stellogen docs**:
- [CLAUDE.md](../../CLAUDE.md): Project overview
- [docs/basics.md](../basics.md): Stellogen fundamentals

## Contributing

This is ongoing research. Contributions welcome in:
- Implementing more examples
- Formalizing open conjectures
- Improving encodings
- Finding bugs or inaccuracies

## License

Documentation: Same as Stellogen project (GPL-3.0)

## Acknowledgments

- **Pablo Donato**: For the scroll nets paper and inspiring this exploration
- **Stellogen maintainers**: Boris Eng and Pablo Donato (!)
- **Tomas Petricek**: For recognizing the PbD potential

---

**Status**: Research / Design Exploration (Not production-ready)

**Last Updated**: October 2025

**Contact**: See main Stellogen README for maintainer info
