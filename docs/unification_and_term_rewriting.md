# Unification and Term Rewriting: Stellogen's Computational Foundation

**Author:** Research Analysis
**Date:** October 2025
**Status:** Theoretical Exploration

## Abstract

This document explores the theoretical relationship between unification and term rewriting systems, with specific focus on how Stellogen's unification-based approach can simulate general term rewriting. We examine the bridge between these formalisms through narrowing, investigate connections to completion theory and Gröbner bases, and analyze how Stellogen's polarity-based fusion mechanism positions it within this theoretical landscape.

## 1. Introduction

Stellogen is built on **term unification** as its fundamental computational mechanism. This raises an interesting question: Can a system based purely on unification simulate general **term rewriting**? The answer is nuanced and connects to deep theoretical results in automated reasoning, functional-logic programming, and completion theory.

### Key Question

How can Stellogen, which only performs unification, simulate the directed rewriting steps of a term rewriting system?

## 2. Fundamental Concepts

### 2.1 Unification

**Unification** is the problem of finding a substitution σ such that two terms t₁ and t₂ become identical:

```
t₁σ = t₂σ
```

Properties:
- **Bidirectional**: Both terms can be instantiated
- **Symmetric**: Unifying t₁ with t₂ is the same as unifying t₂ with t₁
- **Solution-finding**: Searches for a substitution that makes terms equal

**In Stellogen** (from `src/unification.ml`):
```ocaml
type term =
  | Var of idvar
  | Func of idfunc * term list

type substitution = (idvar * term) list
type equation = term * term
type problem = equation list
```

The unification algorithm uses standard techniques:
- **Orient**: Transform (t, Var x) into (Var x, t)
- **Eliminate**: Substitute variables throughout the problem
- **Decompose**: Break down (Func f ts, Func g us) into subproblems
- **Occurs check**: Prevent infinite terms

### 2.2 Term Rewriting

**Term rewriting** applies directed rules l → r to transform terms:

```
If t contains a subterm matching l with substitution σ,
then replace it with rσ
```

Properties:
- **Directed**: Only left-to-right rewriting
- **Pattern matching**: Only l is matched (not both sides)
- **Operational**: Defines computation steps

Example:
```
add(0, Y) → Y
add(s(X), Y) → s(add(X, Y))
```

### 2.3 Key Difference

The crucial distinction:

| Operation | Matching Type | Directionality |
|-----------|--------------|----------------|
| **Unification** | Both terms can be instantiated | Bidirectional |
| **Rewriting** | Only pattern (lhs) is matched | Left-to-right |

When rewriting with rule l → r against term t, we seek σ such that:
```
lσ = subterm of t    (one-sided matching)
```

versus unification where both sides can contain variables.

## 3. The Bridge: Narrowing

### 3.1 Narrowing Definition

**Narrowing** combines unification and rewriting. Given a term t and rewrite rule l → r:

1. Find a subterm s of t and substitution σ such that **sσ = lσ** (unification!)
2. Replace s in t with r to get t'
3. Return t'σ (the instantiated result)

Narrowing was introduced to solve **E-unification problems**: finding substitutions that make terms equal modulo an equational theory E.

### 3.2 Key Insight

Narrowing **generalizes** term rewriting:
- When t contains no variables: narrowing = rewriting
- When t contains variables: narrowing explores multiple instantiation paths

**Soundness**: Every narrowing derivation corresponds to a family of rewriting derivations.

**Completeness**: For confluent and terminating systems, narrowing can enumerate all solutions to equational problems.

### 3.3 Connection to Logic and Functional Programming

Narrowing is recognized as the key mechanism to **unify functional and logic programming**:

- **Functional**: Directed computation via rewrite rules
- **Logic**: Non-deterministic search via unification
- **Narrowing**: Computes by searching for substitutions that enable rewriting

Languages implementing narrowing:
- **Curry**: Functional-logic language with narrowing
- **TOY**: Similar paradigm
- **ALF** (Algebraic Logic Functional): Combines Horn clauses + equations
- **Maude**: Rewriting logic with narrowing

## 4. Gröbner Bases and Completion Theory

### 4.1 Knuth-Bendix Completion

The **Knuth-Bendix completion algorithm** transforms a set of equations into a **confluent term rewriting system**:

**Input**: Set of equations E
**Output**: Convergent (confluent + terminating) TRS R
**Property**: t =ₑ s ⟺ t ↓ᴿ = s ↓ᴿ (decidable equality)

**Algorithm**:
1. Orient equations into rewrite rules
2. Compute **critical pairs** (potential conflicts between rules)
3. Add new rules to resolve conflicts
4. Repeat until convergent or failure

### 4.2 Critical Pairs

A **critical pair** arises when two rewrite rules overlap:

Given rules:
- l₁ → r₁
- l₂ → r₂

If a subterm of l₁ unifies with l₂ under σ, we get terms that can reduce differently. The critical pair is (r₁σ, r₂σ).

**Critical Pair Lemma**: A TRS is locally confluent ⟺ all critical pairs are convergent.

**Role of Unification**: Critical pairs are found by **unifying** overlapping patterns!

### 4.3 Connection to Gröbner Bases

**Buchberger's algorithm** computes Gröbner bases for polynomial ideals. Remarkably, it has the **same structure** as Knuth-Bendix:

| Knuth-Bendix | Buchberger |
|--------------|------------|
| Rewrite rules | Polynomial basis |
| Critical pairs | S-polynomials |
| Completion | Gröbner basis |
| Confluence | Unique normal forms |

Both are instances of **normalized completion** - a general framework for completion procedures.

**Unified View** (Marche 1995, Bachmair & Ganzinger):
- Both perform completion via critical pair computation
- Both use unification to find overlaps
- Both produce canonical rewrite systems

### 4.4 The Unification Connection

Completion theory reveals that **unification is central to term rewriting**:

1. **Pattern matching** in rewriting is specialized unification
2. **Critical pairs** are found via unification of rule patterns
3. **Confluence checking** requires unification
4. **E-unification** can be solved by completion + narrowing

This suggests: A sufficiently expressive unification-based system could internalize rewriting as a pattern of unification interactions.

## 5. Stellogen's Polarity-Based Approach

### 5.1 Polarity and Fusion

Stellogen introduces **polarized terms** with fusion semantics:

```stellogen
' Positive ray
(+add 0 Y Y)

' Negative ray
(-add X Y Z)

' Constellation (set of rays)
(def add {
  [(+add 0 Y Y)]
  [(-add X Y Z) (+add (s X) Y (s Z))]})
```

**Polarity**:
- `+` : positive (producer)
- `-` : negative (consumer)
- Fusion occurs when rays of opposite polarity unify

### 5.2 Interaction as Bidirectional Rewriting

In Stellogen, computation happens through **interaction** (from examples):

```stellogen
' Query: compute 2 + 2
(def query [(-add <s s 0> <s s 0> R) R])

' Interaction performs fusion
(show (exec #add @#query))
```

The `interact` operation:
1. Takes a constellation (set of rays) and a star (initial rays)
2. Finds rays that can **fuse** (unify with compatible polarity)
3. Applies substitutions from unification
4. Continues until no more fusions possible

This resembles term rewriting but with key differences:
- **Symmetric fusion**: Both sides can have variables
- **Polarity control**: Direction determined by polarity, not rule orientation
- **Concurrent**: Multiple fusions can happen simultaneously

### 5.3 Encoding Directed Rewriting

Can Stellogen simulate l → r rewriting?

**Strategy**: Encode the rewrite rule asymmetrically:

```stellogen
' Traditional rewrite rule: add(s(X), Y) → s(add(X, Y))
'
' Stellogen encoding:
(def add_rule {
  [(-add (s X) Y Z) (+add X Y Z') (+s Z' Z)]})
```

Analysis:
- `-add (s X) Y Z`: Matches redex patterns
- `+add X Y Z'`: Triggers recursive rewriting
- `+s Z' Z`: Rebuilds result

The polarity controls flow:
1. Negative ray consumes the query
2. Positive rays produce subproblems/results
3. Unification binds variables

This approximates directed rewriting but through bidirectional unification.

### 5.4 Limitations and Extensions

**Challenge**: Stellogen's symmetric unification may produce non-terminating interactions where directed rewriting would terminate.

Example:
```stellogen
' These could unify in either direction
[(+foo X Y) (-foo A B)]
```

**Possible Solutions**:
1. **Polarity discipline**: Design constellations where polarity enforces directionality
2. **Linearity constraints**: Use `fire` (linear) vs `interact` (non-linear) strategically
3. **Meta-level control**: Explicit strategy specification

From `examples/prolog.sg`, we see Stellogen already encodes logic programs naturally:
```stellogen
(def add {
  [(+add 0 Y Y)]
  [(-add X Y Z) (+add (s X) Y (s Z))]})
```

This is structurally similar to narrowing-based functional-logic languages.

## 6. Theoretical Position

### 6.1 Stellogen as a Narrowing System

**Hypothesis**: Stellogen's interaction mechanism is a form of **polarized narrowing**.

Evidence:
1. **Unification-based**: Like narrowing, uses full unification
2. **Non-deterministic search**: Explores multiple fusion paths
3. **Functional-logic hybrid**: Combines directed computation with search

Differences from standard narrowing:
- **Polarity semantics**: Additional structure not in classical narrowing
- **Concurrent fusion**: Multiple simultaneous reductions
- **Constellation grouping**: Rules bundled with polarity constraints

### 6.2 Simulating Term Rewriting

**Can Stellogen simulate general term rewriting?**

**Yes, in principle**, through several approaches:

#### Approach 1: Encoding as Polarized Constellations

Translate each rewrite rule l → r into:
```stellogen
[(-match_l ...) (+build_r ...)]
```

Polarity provides directionality.

#### Approach 2: Completion Internalization

Since completion is unification-driven, Stellogen could:
1. Represent rewrite rules as constellations
2. Implement critical pair computation via interaction
3. Perform completion at the meta-level

This would require meta-programming capabilities.

#### Approach 3: Narrowing Simulation

Direct narrowing implementation:
1. Represent terms as rays
2. Rules as constellations with polarity
3. `interact` performs narrowing steps

This is closest to Stellogen's current design.

### 6.3 Gröbner Basis Connection

The connection to Gröbner bases suggests a fascinating possibility:

**Conjecture**: Stellogen's polarity-based unification could be extended to perform completion, enabling:
- Automatic derivation of confluent rule sets
- Decidable equality checking
- Polynomial ideal computation (if terms represent polynomials)

This would position Stellogen as a **completion engine** rather than just a term rewriter.

## 7. Related Systems

### 7.1 Interaction Nets

Yves Lafont's **interaction nets** also use polarity for computation:
- Agents have typed ports with polarity
- Active pairs: connections between opposite polarities
- Deterministic reduction via interaction rules

**Similarity to Stellogen**:
- Polarity-driven computation
- Local interaction rules
- Graphical interpretation

**Difference**:
- Interaction nets: Fixed agent types, deterministic
- Stellogen: Term unification, potentially non-deterministic

Research (Fernández & Mackie 1999) bridges interaction nets and term rewriting, showing they can simulate each other.

### 7.2 Maude and Rewriting Logic

**Maude** implements rewriting logic with narrowing:
- Equations for confluent rewriting
- Rules for non-confluent state transitions
- Narrowing for symbolic execution

Stellogen shares philosophical ground:
- Minimalist foundations
- Unification-centric
- Multi-paradigm support

### 7.3 Logic Programming with Equality

**Equality in logic programming** has long been approached through:
1. **Negation as failure** (Prolog) - incomplete
2. **Unification + constraints** (CLP) - more expressive
3. **Narrowing** (ALF, Curry) - functional-logic integration

Stellogen's approach is novel in using **polarity** as the organizing principle rather than mode annotations or evaluation strategies.

## 8. Open Questions and Future Research

### 8.1 Theoretical Questions

1. **Completeness**: Is Stellogen's interaction complete for narrowing? Under what conditions?

2. **Termination**: Can polarity ensure termination where unrestricted unification wouldn't?

3. **Confluence**: How does polarity affect confluence properties?

4. **Expressiveness**: What computational class does Stellogen occupy? Turing-complete? More restricted?

5. **Completion as computation**: Can Stellogen perform Knuth-Bendix completion through interaction?

### 8.2 Practical Directions

1. **Implement completion**: Meta-level critical pair computation

2. **Narrowing strategies**: Implement known strategies (needed narrowing, lazy narrowing)

3. **Type inference**: Use unification for Hindley-Milner-style inference

4. **Constraint solving**: Extend to constraint domains (CLP(X))

5. **Gröbner bases**: Encode polynomial completion

### 8.3 Language Design

1. **Polarity inference**: Automatic polarity assignment for user-defined constellations

2. **Strategy specification**: User control over interaction scheduling

3. **Linearity control**: Fine-grained control over `fire` vs `interact` semantics

4. **Meta-programming**: Reflection and reification for completion algorithms

## 9. Conclusion

The relationship between unification and term rewriting is deep and multifaceted:

- **Narrowing** bridges unification and rewriting, enabling simulation of rewriting through unification
- **Completion theory** shows unification is central to confluence and critical pair computation
- **Gröbner bases** reveal a deep structural similarity between algebraic and term rewriting completion

**Stellogen's position**:
- Built on pure unification with polarity for directionality
- Can simulate term rewriting through polarized constellation design
- Naturally expresses narrowing-style computation
- Offers a unique foundation that could internalize completion procedures

The polarity mechanism is Stellogen's distinctive contribution - it provides structure and control while maintaining the generality of unification. This positions Stellogen as a potential framework for **completion as computation**, where systems evolve toward confluence through interaction.

### Key Insight

Stellogen doesn't choose between unification and rewriting - it recognizes that **rewriting is a restricted pattern of unification**, and uses polarity to encode those restrictions while keeping the full power of unification available.

This makes Stellogen a fascinating experimental platform for exploring:
- The boundaries between declarative and operational semantics
- Completion as a computational paradigm
- Polarity as a structuring principle for computation

## References

### Key Academic Papers

1. **Narrowing**:
   - J. M. Hullot (1980) - "Canonical Forms and Unification"
   - S. Antoy (2005) - "Programming with Narrowing: A Tutorial"
   - J. Meseguer (2007) - "Narrowing and Rewriting Logic"

2. **Completion Theory**:
   - D. Knuth & P. Bendix (1970) - "Simple Word Problems in Universal Algebras"
   - L. Bachmair & N. Dershowitz (1989) - "Completion for Rewriting Modulo a Congruence"
   - C. Marche (1995) - "Normalized Rewriting: A Unified View"

3. **Interaction Nets**:
   - Y. Lafont (1990) - "Interaction Nets"
   - I. Mackie & M. Fernández (1999) - "Interaction Nets and Term Rewriting Systems"

4. **Functional-Logic Programming**:
   - M. Hanus (2007) - "Multi-paradigm Declarative Languages"
   - S. Antoy & M. Hanus (2010) - "Functional Logic Programming"

5. **Gröbner Bases & Completion**:
   - B. Buchberger (1985) - "Gröbner Bases: An Algorithmic Method"
   - F. Winkler (1998) - "Knuth-Bendix Procedure and Buchberger Algorithm: A Synthesis"

### Implementation References

- **Curry**: curry-lang.org
- **Maude**: maude.cs.illinois.edu
- **ALF**: Algebraic Logic Functional language (historical)

### Stellogen Source References

- `src/unification.ml:66-88` - Unification algorithm implementation
- `src/sgen_eval.ml:10-23` - Interaction and fusion mechanism
- `examples/prolog.sg` - Logic programming examples
- `examples/nat.sg` - Natural number arithmetic with polarities

---

*This document represents a theoretical exploration of Stellogen's foundations. As the language evolves, these connections may become more explicit through implementation.*

**Last Updated**: October 2025
