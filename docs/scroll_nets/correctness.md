# Scroll Nets: Correctness Criterion

> Exploring test-based validation for scroll nets in Stellogen

## Abstract

This document examines how to determine whether a scroll net is **correct** (i.e., represents a valid proof). Inspired by proof net correctness criteria, we explore multiple approaches suitable for Stellogen, ranging from sequential (trace-based) to geometric (structure-based) validation.

## 1. The Problem

### 1.1 Why Do We Need a Correctness Criterion?

The formal definition of scroll nets (Definition 5 in Donato's paper) is **syntactically permissive**: it's easy to construct "scroll nets" that don't correspond to any valid proof. Examples of incorrect scroll nets include:

1. **Overlapping inloops**: Two inloops share content in invalid ways
2. **Identity violations**: Justification source ≠ target (different atoms/scrolls)
3. **Scope violations**: Justification escapes unopened/unclosed scroll boundary
4. **Cyclic justifications**: Circular dependencies in the argumentation forest

A correctness criterion must **reject** these while **accepting** all valid proofs.

### 1.2 Analogy to Proof Nets

In Girard's proof nets for linear logic, we face a similar problem:
- **Proof structures**: Syntactically valid graphs (formula trees + axiom/cut links)
- **Proof nets**: Subset of proof structures that correspond to actual sequent calculus proofs
- **Correctness criterion**: Distinguishes proof nets from invalid structures

Common criteria:
- **Long trip condition**: Graph connectivity test
- **Acyclicity of switching**: Contract nodes, check for cycles
- **Sequentialization**: Existence of a sequent calculus derivation

Scroll nets require analogous tests.

## 2. Donato's Sequential Criterion

### 2.1 Definition

A scroll net `𝒩` is **correct** if:
1. `𝒩` is **interpretable**: its premiss and conclusion are forests (not DAGs)
2. There exists a **derivation** `𝒫 ⟹* 𝒩` from premiss `𝒫` to `𝒩`

**Derivation**: A sequence of **derivation rules** (formalized analogues of illative transformations) that incrementally build the scroll net.

### 2.2 Derivation Rules

Each illative transformation has a corresponding derivation rule:

| Illative Transformation | Derivation Rule | Effect |
|------------------------|-----------------|--------|
| Open+ | `r_open+` | Add expansion to positive scroll |
| Open- | `r_open-` | Add expansion to negative scroll |
| Close+ | `r_close+` | Add collapse to positive scroll |
| Close- | `r_close-` | Add collapse to negative scroll |
| Insert | `r_ins` | Add self-justified node in negative context |
| Delete | `r_del` | Add self-justified node in positive context |
| Iterate | `r_iter` | Add justification from source to positive target |
| Deiterate | `r_deit` | Add justification from source to negative target |

**Key property**: Each rule **adds structure** (justifications, interactions) without changing boundaries (premiss/conclusion remain isomorphic).

### 2.3 Correctness as Sequentialization

The sequential criterion states:
```
𝒩 is correct  ⟺  ∃ sequence r₁, r₂, ..., rₙ such that
                   𝒫 →[r₁] 𝒩₁ →[r₂] ... →[rₙ] 𝒩
```

This is analogous to **sequentialization theorems** for proof nets: a proof net is correct iff it can be sequentialized into a sequent calculus derivation.

### 2.4 Advantages

- **Sound by construction**: Each derivation rule corresponds to a valid illative transformation
- **Complete**: If `𝒩` was built by illative transformations, a derivation exists
- **Modular**: Composition operations (horizontal ⊔, vertical ∘) preserve correctness

### 2.5 Disadvantages

- **Non-local**: Requires global traversal to find derivation sequence
- **Non-determinism**: Multiple valid orderings may exist
- **Computationally expensive**: Potentially exponential search space

## 3. Geometric Criteria (Speculative)

### 3.1 Motivation

In proof nets, **geometric criteria** (e.g., long trip, switching acyclicity) offer **polynomial-time** correctness checking by analyzing graph structure alone, without reconstructing derivations.

Can we devise analogous tests for scroll nets?

### 3.2 Potential Criteria

#### 3.2.1 Justification Acyclicity

**Test**: The argumentation forest `𝒜 = ⟨𝒥, ℬ⟩` must be **acyclic**.

**Rationale**: Cyclic justifications lead to circular reasoning ("A is true because B is true because A is true...").

**Stellogen encoding**:
```stellogen
(spec acyclic {
  [(-forest F) (+topsort F) ok]     ' Can topologically sort
  [(-forest F) (+cycle_detected) fail]})  ' Reject cycles
```

**Status**: Donato conjectures acyclicity is preserved by derivation rules, but full proof is future work.

#### 3.2.2 Polarity-Respecting Justifications

**Test**: For each justification `u ⊢ v`:
- If `v` is positive → `u` justifies via **iteration** (copy)
- If `v` is negative → `u` justifies via **deiteration** (delete)

**Rationale**: Polarity determines which illative transformation was applied.

**Stellogen encoding**:
```stellogen
(spec polarity_correct {
  [(-just U V) (+node V pos) (+iterate U V) ok]
  [(-just U V) (+node V neg) (+deiterate U V) ok]
  [(-just U V) (+node V _) (+polarity_mismatch) fail]})
```

#### 3.2.3 Boundary Interpretability

**Test**: Premiss and conclusion must be **forests** (not DAGs with sharing).

**Rationale**: Only the internal structure can have sharing (overlapping inloops). Boundaries must be plain formulas.

**Stellogen encoding**:
```stellogen
(spec interpretable {
  [(-structure S) (+boundary S B) (+is_forest B) ok]
  [(-structure S) (+boundary S B) (+has_sharing B) fail]})
```

#### 3.2.4 Scope Discipline

**Test**: A justification `u ⊢ v` must respect scroll boundaries:
- If `v` is inside a scroll `s`, then `u` must be:
  - In the same scroll, or
  - In a containing scroll (if `s` is opened/closed)

**Rationale**: Cannot justify content "from outside" a sealed scroll.

**Stellogen encoding**:
```stellogen
(spec scope_valid {
  [(-just U V) (+scope U Scope1) (+scope V Scope2) (+scope_ok Scope1 Scope2) ok]
  [(-just U V) (+scope U Scope1) (+scope V Scope2) (+scope_escape Scope1 Scope2) fail]})
```

### 3.3 Conjecture: Compositional Criterion

**Hypothesis**: A scroll net is correct iff it satisfies **all** of:
1. Acyclicity (argumentation forest)
2. Polarity discipline (justifications)
3. Identity (source ≈ target modulo renaming)
4. Scope discipline (no escapes)
5. Interpretability (boundaries are forests)

**Challenge**: Proving this is **sound and complete** (equivalent to sequential criterion) requires substantial work.

## 4. Test-Based Validation in Stellogen

### 4.1 Philosophy

Stellogen's type system (via `spec`) is inherently **test-based**: types are sets of interactive tests. A value inhabits a type iff it passes all tests.

Scroll net correctness fits this paradigm perfectly:
```stellogen
(spec correct_scroll_net {
  [(-scrollnet N) (+test1 N) (+test2 N) (+test3 N) ... ok]})
```

### 4.2 Incremental Testing

Rather than a monolithic "correct or not" judgment, we can provide **granular feedback**:

```stellogen
' Multiple test constellations for different properties
(spec acyclic_arg { [(-scrollnet N) (+acyclic N)] })
(spec polarity_ok { [(-scrollnet N) (+polarity_check N)] })
(spec scope_ok { [(-scrollnet N) (+scope_check N)] })

' Composite correctness
(spec correct {
  [(-scrollnet N)
   (+acyclic N) (+polarity_check N) (+scope_check N)
   ok]})
```

This enables:
- **Debugging**: Identify which test fails
- **Partial proofs**: Work with "almost correct" scroll nets
- **Progressive refinement**: Fix violations incrementally

### 4.3 Sequential Validation

To encode Donato's sequential criterion in Stellogen, we need to **simulate derivation rules**:

```stellogen
' Derivation step: apply rule R to scroll net N1, yielding N2
(:= derive_step {
  [(-scrollnet N1) (-rule R) (+applicable R N1)]  ' R can apply to N1
  [(+applicable R N1) (-apply R N1 N2)]           ' Apply R
  [(-apply R N1 N2) (+scrollnet N2)]})            ' N2 is result

' Derivation sequence: iterate until reaching target
(:= derive_seq {
  [(-scrollnet N) (+derive_seq N N)]               ' Base case: N derives N
  [(-scrollnet N1) (+derive_step N1 N2) (+derive_seq N2 N3)
   (+derive_seq N1 N3)]})                          ' Trans: N1 →* N3

' Correctness: exists derivation from premiss
(spec correct {
  [(-scrollnet N) (+premiss N P) (+derive_seq P N) ok]})
```

**Challenge**: Implementing `derive_step` requires encoding all derivation rules, which is complex.

### 4.4 Hybrid Approach

**Proposal**: Use geometric tests for **fast rejection**, fall back to sequential validation for uncertain cases.

```stellogen
(spec correct {
  ' Fast geometric checks
  [(-scrollnet N) (+acyclic N) (+polarity_ok N) (+scope_ok N)
   ' If all pass, likely correct → attempt sequentialization
   (+derive_seq N) ok]

  ' If any fast check fails, reject immediately
  [(-scrollnet N) (+has_cycle N) fail]
  [(-scrollnet N) (+polarity_violation N) fail]
  [(-scrollnet N) (+scope_violation N) fail]})
```

## 5. Stellogen-Specific Insights

### 5.1 Unification as Built-In Test

Stellogen's unification mechanism provides a **natural correctness test** for justifications:

```stellogen
' A justification u ⊢ v is valid iff source and target unify
(:= valid_justification {
  [(-just U V) (+node U Content1) (+node V Content2)]
  [(+node U C) (+node V C)]  ' Unify: Content1 = Content2 = C
  @[(+valid_just U V)]})
```

If source and target don't unify → identity violation → reject.

### 5.2 Polarity Interaction as Validation

In the unification-native encoding (Approach B), **ill-formed scroll nets simply fail to interact**:

```stellogen
' Correct: opposite polarities interact
{
  [(+source X)]
  [(-target X)]
  ' These fuse → computation proceeds
}

' Incorrect: same polarities don't interact
{
  [(+source X)]
  [(+target X)]  ' No fusion → stuck state
}
```

Stuck states signal incorrectness.

### 5.3 Type-Directed Construction

Rather than checking correctness post-hoc, we can **construct correct-by-design** scroll nets:

```stellogen
' Smart constructors that enforce invariants
(:= safe_iterate {
  [(-source S pos) (-content C) (+target_pos C)]  ' Positive target
})

(:= safe_deiterate {
  [(-source S neg) (-content C) (+target_neg C)]  ' Negative target
})
```

Using these ensures correctness from the start.

## 6. Open Problems

### 6.1 Completeness of Geometric Criteria

**Question**: Does the conjunction of acyclicity + polarity + scope + identity **fully characterize** correctness?

**Approach**:
1. Prove soundness: geometric properties → sequentializable
2. Prove completeness: sequentializable → geometric properties

This would enable **efficient Stellogen implementations**.

### 6.2 Decidability

**Question**: Is correctness **decidable**? If so, what's the complexity?

**Known**: Sequential criterion is decidable (bounded search), but complexity is unclear.

**Goal**: Polynomial-time geometric test (like proof nets).

### 6.3 Error Localization

When a scroll net is incorrect, **where** is the error?

**Desiderata**:
- Point to specific node/justification/interaction
- Suggest fix (e.g., "Change polarity of node 5")
- Explain violation (e.g., "Cycle: 1 ⊢ 2 ⊢ 3 ⊢ 1")

Stellogen's test-based approach naturally supports this via **labeled failures**.

## 7. Connections to Existing Stellogen Examples

### 7.1 MLL Proof Nets (`examples/mll.sg`)

The existing MLL encoding uses tests like:
```stellogen
(spec (larrow a a) {
  [+testrl [...]]  ' Test with right-left order
  [+testrr [...]]  ' Test with right-right order
  ...
})
```

This mirrors our proposed scroll net tests! The same philosophy applies:
- Multiple traversals test different properties
- Tests interact with the structure
- Pass all → correct

### 7.2 Automata (`examples/automata.sg`)

The finite automaton encoding:
```stellogen
(spec binary {
  [(-i []) ok]
  [(-i [0|X]) (+i X)]
  [(-i [1|X]) (+i X)]})
```

Shows how **acceptance = passing tests**. A scroll net is "accepted" (correct) iff it passes all validation tests.

## Conclusion

Scroll net correctness in Stellogen offers multiple design points:

1. **Sequential**: Faithful to Donato's definition, but expensive
2. **Geometric**: Fast but requires theoretical work to ensure soundness/completeness
3. **Hybrid**: Practical balance
4. **Unification-native**: Leverages Stellogen's strengths, makes correctness **observable** (computation succeeds/fails)

The test-based paradigm is a perfect fit: correctness is not a binary property but a **spec** that structures can inhabit by passing interactive tests.

---

**Recommendation**: Start with geometric tests (acyclicity, polarity, scope) for prototyping. Once validated on examples, formalize equivalence to sequential criterion for confidence.
