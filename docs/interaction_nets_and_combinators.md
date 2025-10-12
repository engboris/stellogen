# Interaction Nets and Combinators in Stellogen

> **Disclaimer**: This document was written with the assistance of Claude Code and represents exploratory research and analysis. The content may contain inaccuracies or misinterpretations and should not be taken as definitive statements about the Stellogen language implementation.

**Author:** Research Report
**Date:** 2025-10-12
**Status:** Research Document

## Table of Contents

1. [Introduction](#introduction)
2. [Background: Interaction Nets](#background-interaction-nets)
3. [Interaction Combinators](#interaction-combinators)
4. [Related Projects](#related-projects)
5. [Encoding Interaction Nets in Stellogen](#encoding-interaction-nets-in-stellogen)
6. [Stellogen vs. Traditional Interaction Combinators](#stellogen-vs-traditional-interaction-combinators)
7. [Examples and Analysis](#examples-and-analysis)
8. [Future Directions](#future-directions)
9. [References](#references)

---

## Introduction

This document explores the relationship between **interaction nets**, **interaction combinators**, and **Stellogen**. Stellogen's design, based on term unification with polarity and fusion, shares deep conceptual similarities with interaction nets—a graphical model of computation introduced by Yves Lafont. This report:

1. Explains the theory of interaction nets and interaction combinators
2. Examines how other languages (Par, HVM) compile to interaction combinators
3. Analyzes how Stellogen's primitives (stars, rays, polarity, constellations) naturally encode interaction nets
4. Provides concrete examples from the Stellogen codebase

**Key Insight:** Stellogen can be understood as a textual notation for interaction nets, where stars represent networks of connected agents, rays encode ports with polarity, and constellations define interaction rules.

---

## Background: Interaction Nets

### Overview

**Interaction nets** were introduced by French mathematician Yves Lafont in 1990 as a graphical model of computation and a generalization of linear logic proof structures. They provide:

- **Graph-based computation**: Programs are graphs where nodes interact through local rewriting
- **Inherent parallelism**: Multiple reductions can occur simultaneously with strong confluence
- **Constant-time operations**: Each interaction step is local and happens in constant time
- **Determinism**: The order of reductions doesn't affect the final result

### Formal Components

#### 1. Agents and Ports

An **agent** is a node in the interaction net with:
- **One principal port** (the "active" connection point)
- **Zero or more auxiliary ports** (passive connection points)

Agents are typed by their **signature** (name and arity):
- Signature Σ: The set of all agent types
- Arity: The number of auxiliary ports

#### 2. Edges and Wiring

- **Edges** connect exactly two ports
- **Free ports** are unconnected ports forming the net's interface
- Ports can be connected to at most one edge

#### 3. Active Pairs

An **active pair** forms when two agents connect at their principal ports. This is the only configuration that can trigger interaction.

```
    [Agent A]        [Agent B]
        |                |
    principal        principal
        └────────────────┘
           active pair
```

#### 4. Interaction Rules

For each pair of agent types (α, β), there is an **interaction rule** that specifies how the active pair rewrites into a new net. Rules are:
- **Local**: Only the two agents and their immediate connections are involved
- **Deterministic**: Each active pair has exactly one rewriting outcome
- **Strongly confluent**: Different reduction orders produce the same result

#### 5. Reduction and Normal Form

- **Reduction**: Repeatedly find active pairs and apply interaction rules
- **Normal form**: A net with no active pairs (computation complete)
- **Parallel reduction**: Multiple active pairs can be reduced simultaneously

### Properties

1. **Strong Confluence**: All reduction paths lead to the same normal form
2. **Locality**: Reductions are local graph transformations
3. **Parallelism**: Independent reductions can execute concurrently
4. **Efficiency**: Each step is O(1) in the size of the net

---

## Interaction Combinators

### The Universal System

In 1997, Lafont introduced **interaction combinators**—a universal system of interaction nets with only:
- **3 symbols** (agent types)
- **6 interaction rules**

This minimal system can simulate any interaction net and serves as a universal model of distributed computation.

### The Three Symbols

Traditional interaction combinators use three agent types:

1. **ε (epsilon)** - Eraser (arity 0)
   - Deletes/erases structures
   - No auxiliary ports

2. **δ (delta)** - Duplicator (arity 2)
   - Duplicates structures
   - Two auxiliary ports

3. **γ (gamma)** - Constructor (arity 2)
   - Constructs/links structures
   - Two auxiliary ports

### The Six Interaction Rules

The rules define interactions between active pairs:

#### Annihilation Rules (same symbol types)

```
δ --- δ  →  ══  ══
    ∧         │   │
```

When two duplicators (or two constructors) connect at their principal ports, they annihilate and connect their corresponding auxiliary ports.

#### Commutation Rules (different symbol types)

```
δ --- γ  →  δ   γ
    ∧       │ ╳ │
           γ   δ
```

When a duplicator meets a constructor, they commute: each creates a copy of the other, rotated and reconnected.

#### Erasure Rules

```
ε --- δ  →  ε   ε
```

When an eraser meets a duplicator (or constructor), it propagates erasure to all auxiliary ports.

### Universality

This simple system can encode:
- Lambda calculus
- Turing machines
- Any computable function

The encoding process involves representing computational structures as interaction nets and compiling them to the three basic combinators.

---

## Related Projects

### The Par Language

**Par** is an experimental programming language that compiles to interaction combinators.

**Key Features:**
- Based on linear logic
- Automatic concurrent execution
- Type-safe with structural types (pairs, functions, eithers, choices)
- Total and deterministic (mostly)
- Prevents deadlocks through structured concurrency

**Compilation Strategy:**
- Uses "CP" (Classical Processes) from Phil Wadler's "Propositions as Sessions"
- Translates programs directly to linear logic proofs
- Compiles to interaction combinators as the execution target

**Philosophy:** Brings linear logic's expressive power into practical programming with emphasis on parallelism and type safety.

**Repository:** https://github.com/faiface/par-lang

### HVM (Higher-Order Virtual Machine)

**HVM** is Victor Taelin's massively parallel runtime based on interaction combinators.

**Key Features:**
- Implements Symmetric Interaction Combinators
- Enables near-ideal speedup on parallel hardware (GPUs)
- Low-level IR for specifying interaction nets
- Compilation target for high-level languages (Python, Haskell, Bend)

**Node Types in Interaction Calculus:**
- **VAR** - Variables (affine, used once)
- **ERA** - Erasure
- **LAM** - Lambda abstraction
- **APP** - Application
- **SUP** - Superposition
- **DUP** - Duplication

**Interaction Rules Include:**
- APP-LAM: Beta reduction
- APP-SUP: Splits superposition when applied
- DUP-LAM: Handles duplication in lambda terms
- DUP-SUP: Manages duplication/superposition interaction

**Key Innovation:** Uses labels on duplicators to control interaction behavior:
- Matching labels → annihilation
- Different labels → commutation

This enables optimal lambda calculus reduction (Lamping's algorithm).

**Repository:** https://github.com/HigherOrderCO/HVM

### Other Implementations

Several research implementations exist on GitHub:

- **nkohen/InteractionCombinators** - Lambda calculus implementations in Java
- **dowlandaiello/ic-sandbox** - Rust-based research sandbox with REPL
- **ia0/lafont** - 3D visualization of Lafont's original system
- **noughtmare/lafont90** - Compiler in Rascal
- **chemlambda/molecular** - Graph rewrite systems with interaction combinators

These projects demonstrate the versatility and ongoing research interest in interaction combinators.

---

## Encoding Interaction Nets in Stellogen

### Conceptual Mapping

Stellogen's design aligns naturally with interaction nets. Here's the correspondence:

| Interaction Net Concept | Stellogen Equivalent | Notes |
|------------------------|----------------------|-------|
| **Agent** | Constellation or Star | A constellation defines an agent type |
| **Principal Port** | Ray with primary label | The main interaction point (e.g., `add`, `id`) |
| **Auxiliary Ports** | Numbered rays or parameters | Secondary connection points (e.g., `-1`, `+2`, `-3`) |
| **Polarity** | Ray polarity (`+`/`-`) | Built-in mechanism for principal port duality |
| **Active Pair** | Opposite polarity rays | `(+add ...)` and `(-add ...)` can fuse |
| **Interaction Rule** | Constellation clause | Each clause defines how agents interact |
| **Wiring/Edges** | Variables & cons lists | Variables connect ports; `[l\|X]` encodes direction |
| **Network** | Star with multiple rays | A star is a collection of connected agents |

### Stars as Blocks of Addresses/Ports

The user's insight is key: **Stars can be used as blocks of addresses/ports**. A star represents a network fragment with:

1. **Multiple rays** (ports) that can connect to other agents
2. **Polarity on each ray** indicating whether it's active or passive
3. **Complex address encoding** through structured terms

### Port Addressing Schemes

Stellogen examples demonstrate several encoding strategies:

#### 1. Numeric Addressing (Simple)

```stellogen
(:= agent {
  [(-1 X) (+out X)]      ' Port 1 connects to output port
  [(-2 Y) (+out Y)]})    ' Port 2 connects to output port
```

Ports are numbered: `-1`, `+2`, `-3`, etc.

#### 2. Direction Encoding with Cons Lists

```stellogen
(:= id {
  [(-5 [l|X]) (+1 X)]    ' Left branch of port 5 → port 1
  [(-5 [r|X]) (+2 X)]    ' Right branch of port 5 → port 2
  [(+5 [l|X]) (+6 [l|X])]  ' Connect left branches
  [(+5 [r|X]) (+6 [r|X])]}) ' Connect right branches
```

Uses `[l|X]` for left and `[r|X]` for right, encoding binary tree structure.

#### 3. Complex Structured Addressing

```stellogen
(:= var_x [(x (exp X Y)) (+arg (exp [l|X] Y))])
```

Combines multiple levels: `exp` wrapper with depth tracking and directional lists.

### Polarity as Principal Port Mechanism

Stellogen's **polarity** (`+`/`-`) directly models the principal port concept:

- **Positive ray** (`+name`) represents one "side" of the principal port
- **Negative ray** (`-name`) represents the dual "side"
- **Active pair formation**: When `(+name ...)` meets `(-name ...)`, they can fuse
- **Interaction trigger**: Fusion corresponds to applying an interaction rule

This is a native feature of Stellogen, not requiring explicit encoding.

### Constellations as Interaction Rules

A **constellation** in Stellogen defines the behavior of an agent and its interaction rules:

```stellogen
(:= add {
  [(+add 0 Y Y)]                        ' Rule 1: 0 + Y = Y
  [(-add X Y Z) (+add (s X) Y (s Z))]}) ' Rule 2: S(X) + Y = S(Z) if X + Y = Z
```

This is equivalent to defining interaction rules:
- When `add` receives arguments `0, Y`, it returns `Y`
- When `add` receives `(s X), Y`, it recursively calls itself

Each clause is an interaction rule specifying:
1. **Pattern** on input rays (what configuration triggers this rule)
2. **Result** rays (what the net becomes after interaction)

---

## Stellogen vs. Traditional Interaction Combinators

### Similarities

1. **Graph-based computation**: Both models use graphs with nodes and connections
2. **Local rewriting**: Interactions are local transformations
3. **Strong confluence**: Reduction order doesn't matter
4. **Parallelism**: Independent interactions can happen simultaneously
5. **Polarity/Duality**: Both use dual connection points (principal ports vs. +/- polarity)

### Differences

| Aspect | Traditional Interaction Combinators | Stellogen |
|--------|-------------------------------------|-----------|
| **Symbol Set** | Fixed 3 symbols (ε, δ, γ) | User-defined constellations (unlimited) |
| **Rule Count** | Fixed 6 rules | User-defined interaction rules |
| **Encoding** | Everything compiled to 3 symbols | Direct high-level representation |
| **Type System** | Structure-based | Interaction-based (specs as tests) |
| **Polarity** | Implicit in ports | Explicit on rays (`+`/`-`) |
| **Addresses** | Simple port numbers | Flexible: numbers, cons lists, structured terms |
| **Abstraction Level** | Low-level IR | High-level, user-facing |

### Advantages of Stellogen's Approach

1. **Higher abstraction**: No need to compile everything to 3 primitives
2. **Readability**: Programs remain close to their logical structure
3. **Flexibility**: Port addressing can be arbitrarily complex
4. **Logic-agnostic**: Not tied to a specific logical system
5. **Direct encoding**: No intermediate compilation step to interaction combinators

Stellogen can be seen as:
- A **generalized interaction net system** where users define their own agents
- A **textual notation** for interaction nets with flexible addressing
- A **meta-level** above interaction combinators, allowing direct expression of computational patterns

---

## Examples and Analysis

### Example 1: Linear Logic Identity (from `mll.sg`)

```stellogen
(:= id {
  [(-5 [l|X]) (+1 X)]
  [(-5 [r|X]) (+2 X)]
  [(-6 [l|X]) (+3 X)]
  [(-6 [r|X]) (+4 X)]
  [(+5 [l|X]) (+6 [l|X])]
  [(+5 [r|X]) (+6 [r|X])]})
```

**Analysis:**

**Ports:**
- Ports 1, 2, 3, 4: Auxiliary ports
- Ports 5, 6: Principal ports (they connect to each other)

**Structure:**
- Port 5 is a binary structure with left and right branches
- When port 5 receives input, it routes based on direction:
  - Left branch (`[l|X]`) → Port 1
  - Right branch (`[r|X]`) → Port 2
- Port 6 mirrors port 5's structure

**Interaction Net Interpretation:**
This encodes the identity agent in multiplicative linear logic (MLL):
- Two principal ports (input and output of the linear arrow)
- The left/right branching represents the proof structure
- Variables X connect corresponding auxiliary ports

**Graph Visualization:**
```
        Port 5 (-)
         /  \
        l    r
        |    |
     +1 X    +2 X

        Port 6 (-)
         /  \
        l    r
        |    |
     +3 X    +4 X

  Port 5 (+l) ←→ Port 6 (+l)
  Port 5 (+r) ←→ Port 6 (+r)
```

### Example 2: Cut Elimination (from `mll.sg`)

```stellogen
(:= ps1 {
  [+vehicle [
    [(+7 [l|X]) (+7 [r|X])]
    @[(3 X) (+8 [l|X])]
    [(+8 [r|X]) (6 X)]]]
  [+cuts [
    [(-7 X) (-8 X)]]]})

(:= vehicle (eval (interact #ps1 @[-vehicle])))
(:= cuts    (eval (interact #ps1 @[-cuts])))

(show (interact #vehicle #cuts))
```

**Analysis:**

**Constellation ps1 defines two agents:**

1. **vehicle agent**:
   - Has ports 7 and 8 (both positive)
   - Port 7 splits: left and right branches
   - Port 8 splits: left and right branches
   - Internal wiring connects port 3 and port 6

2. **cuts agent**:
   - Has ports 7 and 8 (both negative)
   - This forms active pairs with vehicle's ports!

**Interaction:**
When `vehicle` and `cuts` interact:
- `(+7 X)` from vehicle meets `(-7 X)` from cuts → Active pair
- `(+8 X)` from vehicle meets `(-8 X)` from cuts → Active pair
- These active pairs trigger **cut elimination** (annihilation)

**Interaction Net Interpretation:**
This is the classic **cut elimination** from linear logic proof theory:
- A "cut" is a link between a formula and its dual
- Eliminating the cut simplifies the proof net
- The interaction removes the active pair and rewires connections

### Example 3: Linear Lambda Calculus Identity (from `linear_lambda.sg`)

```stellogen
' identity function (\x -> x)
(:= id [(+id [l|X]) (+id [r|X])])

' id id
(:= id_arg [(ida [l|X]) (+arg [l r|X])])

(:= linker [
  [(-id X) (-arg X)]
  @[(+arg [r|X]) (out X)]])

(show (interact #id #id_arg #linker))
```

**Analysis:**

**Lambda Term Encoding:**
- Lambda abstraction: Two ports (left for variable binding, right for body)
- Application: Three ports (left for function, right for argument, output)

**id constellation:**
- `(+id [l|X])` and `(+id [r|X])`: Binary structure
- Represents λx.x (identity function)

**id_arg constellation:**
- Represents the application (id id)
- `[l r|X]`: Nested list structure encoding the application

**linker constellation:**
- Connects the function and argument
- Extracts the result to `out`

**Interaction Net Interpretation:**
This implements lambda calculus using proof-nets:
- Each lambda term is a proof structure
- Reduction corresponds to cut elimination
- The [l|X]/[r|X] structure represents the binary tree of the proof-net

### Example 4: Lambda Calculus with Exponentials (from `lambda.sg`)

```stellogen
(:= id [(+id (exp [l|X] d)) (+id [r|X])])

(:= var_x [(x (exp X Y)) (+arg (exp [l|X] Y))])

(:= lproj {
  [(+lproj [l|X])]           ' weakening
  [(lproj (exp [r l|X] d)) (+lproj [r r|X])]})
```

**Analysis:**

**Exponential Modality:**
- `(exp Term Depth)` encodes the exponential modality from linear logic
- Required for non-linear lambda calculus (variables used multiple times)

**id with exponentials:**
- More complex encoding than linear case
- Depth parameter `d` tracks nesting level

**lproj (left projection):**
- Implements weakening (discarding unused variables)
- `[(+lproj [l|X])]` - erases left branch
- Recursive case handles nested structures

**Interaction Net Interpretation:**
This is the full lambda calculus encoding using proof-nets with exponentials:
- Exponentials allow contraction and weakening
- Enables non-linear use of variables
- More complex than linear lambda calculus

---

## Future Directions

### 1. Formal Encoding of Interaction Combinators in Stellogen

Stellogen could implement the three classic interaction combinators (ε, δ, γ) directly:

```stellogen
' Eraser
(:= epsilon {
  [(+e)]})  ' Erases anything connected to it

' Duplicator
(:= delta {
  [(+d [1|X] [2|Y]) (-d [1|X] [2|Y])]  ' Annihilation with another delta
  [(+d [1|A] [2|B]) (-g [1|X] [2|Y])   ' Commutation with gamma
   (+g [1|C] [2|D]) (+d [1|C] [2|D])
   (connect A X) (connect B Y)]})

' Constructor
(:= gamma {
  [(+g [1|X] [2|Y]) (-g [1|X] [2|Y])]  ' Annihilation with another gamma
  [(+g [1|A] [2|B]) (-d [1|X] [2|Y])   ' Commutation with delta
   (+d [1|C] [2|D]) (+g [1|C] [2|D])
   (connect A X) (connect B Y)]})
```

This would demonstrate that Stellogen can serve as a **host language** for interaction combinators.

### 2. Optimal Evaluation Strategy

Stellogen could adopt strategies from HVM:
- **Labeled duplicators** to optimize lambda calculus reduction
- **Parallel reduction** of independent active pairs
- **Symbolic execution** where terms reduce as they're needed

### 3. Visual Interaction Net Editor

A graphical interface could:
- Visualize Stellogen programs as interaction nets
- Allow direct manipulation of nets (drag-and-drop agents)
- Animate reduction steps
- Generate Stellogen code from visual nets

### 4. Compilation Targets

Stellogen programs could compile to:
- **HVM runtime** for massively parallel execution
- **Interaction combinator assembly** for efficient evaluation
- **GPU kernels** for hardware parallelism
- **Distributed systems** leveraging natural concurrency

### 5. Type System Extensions

Stellogen's interaction-based types could incorporate:
- **Session types** (from linear logic / process calculi)
- **Gradual linearity** (mix linear and non-linear code)
- **Dependent interaction types** (types that compute via interaction)

### 6. Proof Net Verification

Tools could verify that Stellogen programs represent valid proof-nets:
- Check correctness criteria (acyclicity, connectedness)
- Verify cut-elimination terminates
- Ensure strong normalization properties

### 7. Benchmarking and Performance

Systematic comparison of Stellogen's evaluation against:
- Traditional lambda calculus interpreters
- HVM runtime
- Par language
- Standard functional languages

### 8. Higher-Order Features

Explore encoding:
- **Higher-order functions** with interaction nets
- **Recursive types** and fixpoints
- **Polymorphism** and generics
- **Effects** and computational modalities

### 9. Practical Applications

Develop real-world programs demonstrating:
- Concurrent algorithms (parallel sorting, search)
- Distributed protocols (consensus, replication)
- Logic programming (Prolog-style querying)
- Functional programming (standard library)

---

## References

### Academic Papers

1. **Lafont, Y.** (1990). *Interaction Nets*. In Proceedings of POPL 1990 (Principles of Programming Languages).
   https://dl.acm.org/doi/10.1145/96709.96718

2. **Lafont, Y.** (1997). *Interaction Combinators*. Information and Computation, 137(1), 69-101.
   https://www.sciencedirect.com/science/article/pii/S0890540197926432

3. **Wadler, P.** (2012). *Propositions as Sessions*. In Proceedings of ICFP 2012.
   (Theoretical foundation for Par language)

### Projects and Implementations

1. **Par Language**
   https://github.com/faiface/par-lang
   Experimental language compiling to interaction combinators

2. **HVM (Higher-Order Virtual Machine)**
   https://github.com/HigherOrderCO/HVM
   Massively parallel interaction combinator runtime

3. **Victor Taelin's Interaction Calculus**
   https://github.com/VictorTaelin/Interaction-Calculus
   Optimal lambda calculus reduction system

4. **Symmetric Interaction Calculus**
   https://github.com/VictorTaelin/Symmetric-Interaction-Calculus
   Symmetric variant with uniform rules

5. **Interaction Nets Research Sandbox (Rust)**
   https://github.com/dowlandaiello/ic-sandbox
   REPL for interaction combinators and lambda calculus

6. **Lafont Animation (3D visualization)**
   https://github.com/ia0/lafont
   Visual representation of interaction combinator execution

### Articles and Tutorials

1. **Interaction Nets, Combinators, and Calculus**
   https://zicklag.katharos.group/blog/interaction-nets-combinators-calculus/
   Accessible introduction to the theory

2. **The Symmetric Interaction Calculus** (Medium article)
   https://medium.com/@maiavictor/the-abstract-calculus-fe8c46bcf39c
   Victor Taelin's explanation of SIC

3. **Wikipedia: Interaction Nets**
   https://en.wikipedia.org/wiki/Interaction_nets
   Comprehensive overview with formal definitions

### Related Stellogen Examples

1. `examples/mll.sg` - Multiplicative linear logic proof-nets
2. `examples/linear_lambda.sg` - Linear lambda calculus with proof-nets
3. `examples/lambda.sg` - Lambda calculus with exponentials
4. `examples/prolog.sg` - Logic programming (related to linear logic)

---

## Conclusion

Stellogen's design naturally aligns with interaction nets and interaction combinators:

1. **Stars** serve as blocks of agents with complex port addressing
2. **Rays** with polarity (`+`/`-`) encode principal and auxiliary ports
3. **Constellations** define interaction rules
4. **Fusion** implements the active pair reduction mechanism
5. **Variables and cons lists** represent wiring/edges

Stellogen operates at a **higher level of abstraction** than traditional interaction combinators:
- Users define domain-specific agents (constellations)
- Port addressing is flexible and expressive
- No need to compile to a fixed 3-symbol system
- Programs remain readable and close to their logical structure

At the same time, Stellogen **could** implement interaction combinators directly, serving as a host language for the universal system. This positions Stellogen as:

- A **generalization** of interaction nets
- A **practical notation** for interaction-based computation
- A **research platform** for exploring new interaction models

The connection to projects like Par and HVM suggests exciting future directions:
- Compilation to parallel hardware (GPUs)
- Optimal evaluation strategies
- Formal verification of interaction properties
- Integration with existing interaction combinator ecosystems

Stellogen's **logic-agnostic** philosophy makes it an ideal environment for experimenting with interaction-based computation, free from the constraints of any particular logical system while retaining the benefits of graph-based, parallel, deterministic reduction.
