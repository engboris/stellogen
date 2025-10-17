# Scroll Nets: Normalization and Detour Elimination

> How computation emerges from unification in scroll nets

## Abstract

This document explores **normalization** in scroll nets—the process of eliminating **detours** (redexes) to obtain canonical proof forms. Following Donato's paper, we identify four types of detours and examine how they can be reduced. Crucially, we investigate whether detour elimination can **emerge automatically** from Stellogen's term unification, avoiding the need for explicit rewrite rules.

## 1. What is a Detour?

### 1.1 Intuition

In proof theory, a **detour** occurs when:
- A formula is **introduced** by one rule, then
- Immediately **eliminated** by another rule on the same formula

This is redundant—we could have bypassed the introduction entirely. Removing detours yields a **more direct** proof.

**Examples**:
- Natural deduction: ∧-introduction followed by ∧-elimination
- Lambda calculus: β-redex `(λx.t) u` where λ is immediately applied
- Linear logic proof nets: Cut elimination

### 1.2 Detours in Scroll Nets

Donato defines a **detour** as a scroll node that is both:
- **Introduced** (entirely scribed on the sheet of assertion)
- **Eliminated** (entirely erased from the sheet)

Since there are 2 categories of illative transformations (interaction, argumentation) and each can introduce or eliminate, we get **4 detour types**:

| Detour Type | Introduction | Elimination | Description |
|-------------|-------------|-------------|-------------|
| **ii** | Open | Close | Interaction/Interaction |
| **ia** | Open | Delete | Interaction/Argumentation |
| **ai** | Iterate | Close | Argumentation/Interaction |
| **aa** | Iterate | Delete | Argumentation/Argumentation |

(Also: Insert/Close, Insert/Deiterate as dual variants)

Each type has a **reduction rule** that eliminates the detour while preserving boundaries.

## 2. The Four Detour Types

### 2.1 Detour ii: Interaction/Interaction

**Pattern**: A scroll is **opened** then **closed**.

```
Open:  ∅  →  [( )]     (introduce empty scroll)
Close: [( )] → ∅       (eliminate empty scroll)

Detour: [( Content )]  where scroll is both opened and closed
```

**Reduction**: Remove the scroll, leaving `Content`.

**Diagrammatic (from paper)**:
```
Before:  [( 𝒩 )]     where 𝒩 is a subnet (proof inside the scroll)
         \___/
      opened & closed

After:   𝒩           (scroll disappears, content remains)
```

**Key insight**: The scroll acts as a "transparency"—it introduces then removes itself, leaving only its content.

### 2.2 Detour ia: Interaction/Argumentation

**Pattern**: A scroll is **opened** (interaction) then **deleted** (argumentation).

```
Open:   ∅  →  [( )]
Delete: [( 𝒩 | 𝒫 )] → [( 𝒫 )]   (delete 𝒩 from outloop)

Detour: [( 𝒩 | 𝒫 )] where scroll was opened then 𝒩 deleted
```

**Reduction**: Replace with `𝒩 ∘ 𝒫` (superposition of subnets).

**Intuition**: Opening introduces a scroll structure; deleting removes the antecedent. The composition `𝒩 ∘ 𝒫` "short-circuits" this.

### 2.3 Detour ai: Argumentation/Interaction

**Pattern**: A scroll is **iterated** (copied via argumentation) then **closed** (interaction).

```
Iterate: Copy scroll from source location
Close:   Eliminate the copied scroll

Detour: A scroll node that was iterated then closed
```

**Reduction**: Remove the iteration, leaving only the source.

**Intuition**: We duplicated something we didn't need (it's immediately closed).

### 2.4 Detour aa: Argumentation/Argumentation

**Pattern**: A scroll (or atom) is **iterated** then **deleted**.

```
Iterate: source ⊢ target   (copy from source to positive target)
Delete:  target is self-justified (deleted)

Detour: target is both iterated and deleted
```

**Reduction (scroll case)**:
```
Before:  source ⊢ [( 𝒩 | 𝒫 )]_target  where target is deleted
After:   source becomes [( 𝒩 | 𝒫 ∘ source )]
```

Replace target with composition of its subnets and source.

**Reduction (atom case)**:
```
Before:  source ⊢ a_target  where target is deleted
After:   Remove target entirely (no reference remains)
```

**Note**: This is the most complex detour type, with distinct cases for scrolls vs atoms.

## 3. Reduction Rules (Donato's Approach)

### 3.1 Formal Specification

Donato provides **diagrammatic** reduction rules but notes they are **experimental**. Full formalization is future work.

**Properties they should satisfy**:
1. **Boundary preservation**: `premiss(𝒩) = premiss(𝒩')` and `conclusion(𝒩) = conclusion(𝒩')` after reduction
2. **Termination**: Repeated reduction eventually reaches a detour-free normal form
3. **Confluence** (ideal): Reduction order doesn't matter (Church-Rosser property)

### 3.2 Challenge: Incomplete Characterization

The paper states:
> "Currently these rules are experimental... A deeper analysis of detours and detour elimination would require an entire dedicated article."

This means:
- Not all edge cases are covered
- Confluence is unproven
- Interaction with other detours is unclear

**Implication for Stellogen**: We have design freedom to explore alternative reduction mechanisms!

## 4. Normalization via Unification (Stellogen Approach)

### 4.1 Core Hypothesis

**Can detour elimination emerge from term unification, without explicit rewrite rules?**

**Inspiration**: In the MLL proof net encoding (`examples/mll.sg`), cut-elimination happens automatically via constellation interaction. The vehicle and cuts fuse, and unification handles the reduction.

**Proposal**: Encode detours as **opposite-polarity rays** that naturally seek unification.

### 4.2 Detour ii: Unification-Based Reduction

**Encoding**:
```stellogen
' A scroll that is both opened and closed
(:= detour_ii {
  [(+opened (scroll Out In))]   ' Introduced (positive)
  [(-closed (scroll Out In))]   ' Eliminated (negative)
  ' These rays have opposite polarities → they unify!
  @[(+result In)]})             ' After fusion: inloop content remains
```

**Mechanism**:
1. `+opened` and `-closed` unify (same scroll term, opposite polarities)
2. Fusion removes the scroll node
3. Only the inloop content `In` flows to the result

**Why it works**:
- Polarity drives interaction (Stellogen's core mechanic)
- Unification enforces identity (only the *same* scroll reduces)
- The `@` focus ensures we extract the result

### 4.3 Detour ia: Composition via Superposition

**Encoding**:
```stellogen
' Opened then deleted
(:= detour_ia {
  [(+opened (scroll Out In))]
  [(-deleted (scroll Out In))]  ' Self-justified deletion
  ' After unification, compose Out and In
  [(+compose Out In Result)]
  @[(-result Result)]})

' Composition operator (mimics paper's ∘)
(:= compose {
  [(-compose Net1 Net2 R)]
  [(+premiss Net1 P1) (+conclusion Net1 C1)]
  [(+premiss Net2 P2) (+conclusion Net2 C2)]
  [(-unify C1 P2)]              ' Boundary match
  [(+result P1 C2)]})           ' Compose: premiss of Net1, conclusion of Net2
```

**Challenge**: Composition is more complex than simple unification—it involves matching boundaries and "stacking" proofs. This may require explicit composition logic.

### 4.4 Detour ai: Source-Only Justification

**Encoding**:
```stellogen
' Iterated then closed
(:= detour_ai {
  [(+source S)]
  [(+iterated S Target)]        ' Justification: S ⊢ Target
  [(-closed Target)]            ' Target is closed
  ' Cancel the iteration: only source remains
  @[(+result S)]})
```

**Mechanism**: The `-closed` ray "consumes" the `+iterated`, leaving only `+source`.

### 4.5 Detour aa: The Complex Case

**Atom case**:
```stellogen
' Iterated atom then deleted
(:= detour_aa_atom {
  [(+source (atom a))]
  [(+iterated_atom (atom a))]
  [(-deleted_atom (atom a))]
  ' Deletion consumes the iterated copy
  ' Source remains available for other justifications
  @[(+source (atom a))]})
```

**Scroll case** (more intricate):
```stellogen
' Iterated scroll then deleted
(:= detour_aa_scroll {
  [(+source (scroll Out In))]
  [(+iterated_scroll Src (scroll Out In))]
  [(-deleted_scroll (scroll Out In))]
  ' Replace target with composition
  [(+compose In Src NewOut)]
  @[(+result (scroll NewOut In))]})
```

**Challenge**: This requires **grafting** the source subnet into the target's structure, which goes beyond simple unification.

### 4.6 Limitations of Pure Unification

While detours **ii** and **ai** can plausibly reduce via unification, **ia** and **aa** require:
- **Composition** (matching boundaries, superposing subnets)
- **Grafting** (embedding one subnet into another)

These are **graph transformations** more complex than term unification.

**Solution**: Hybrid approach:
1. Use unification for "local" detours (ii, ai)
2. Implement composition/grafting as explicit constellation operations
3. Let unification trigger these operations when detours are detected

## 5. Emergence of Computation

### 5.1 Why Emergence Matters

**Philosophical goal**: In scroll nets, proof **construction** and **execution** follow the same rules (illative transformations). Detour elimination is not an external operation—it's intrinsic to the system.

**Stellogen alignment**: Computation = unification-based interaction. Ideally, normalization should be **computation**, not a meta-level rewrite.

### 5.2 Partial Success

We achieve partial emergence:
- **Detection** of detours emerges from polarity (opposite polarities signal redex)
- **Simple reductions** (ii, ai) emerge from unification
- **Complex reductions** (ia, aa) require graph operations

**Analogy to lambda calculus**:
- β-reduction `(λx.t) u → t[x := u]` requires **substitution** (not just unification)
- Stellogen doesn't have first-class substitution (yet)
- Similarly, scroll net composition requires operations beyond unification

### 5.3 Path Forward: Enriching Stellogen

**Option A**: Implement composition as a **macro**:
```stellogen
(macro (compose N1 N2) (superpose (conclusion N1) (premiss N2) N2))
```

**Option B**: Extend Stellogen with **graph rewriting** primitives:
```stellogen
' Hypothetical syntax
(:= rewrite {
  [(-graph G) (-pattern P) (+match P G Subst)]
  [(+match P G S) (-apply_rule R S) (+graph G')]})
```

**Option C**: Accept that **some** detours require explicit handling:
```stellogen
' Explicit detour elimination function
(:= normalize {
  [(-scrollnet N) (+detour N D Type)]
  [(+detour N D ii) (+reduce_ii D N')]
  [(+detour N D aa) (+reduce_aa D N')]
  [(-scrollnet N') (+normalize N')]    ' Recurse
  @[(+normal N')]})
```

This is pragmatic but loses the elegance of pure emergence.

## 6. Connection to Lambda Calculus

### 6.1 Simulating STLC (from paper)

Donato shows how to encode simply typed lambda calculus terms as scroll nets:

| λ-term | Scroll Net |
|--------|-----------|
| Variable `x` | Atom node labeled `x` |
| Abstraction `λx.t` | Scroll with `x` in outloop, `t` in inloop |
| Application `t u` | Superposition of scroll nets for `t` and `u` |

**β-reduction** `(λx.t) u → t[x := u]` is simulated by:
1. Detour **aa** (iteration of `u` into abstraction, then deletion)
2. Detour **ii** (opening of scroll, then closing after substitution)

**Key insight**: Substitution is **not explicit**—it emerges from cascading detour reductions!

### 6.2 Implications for Stellogen

If scroll nets can encode lambda calculus and normalization, then:
- **Stellogen + scroll nets = functional programming**
- Detour elimination = function evaluation
- Normal forms = values (irreducible terms)

This provides a **proof-theoretic foundation** for functional programming in Stellogen.

## 7. Termination and Confluence

### 7.1 Open Problem: Termination

**Question**: Does detour elimination always terminate?

**Known**: For simply typed lambda calculus, strong normalization holds (all reduction sequences terminate).

**Conjecture**: If scroll nets faithfully simulate STLC, they inherit strong normalization.

**Challenge**: Donato's reduction rules are experimental; termination is unproven.

**Stellogen implication**: If using unification-based reduction, termination depends on:
- Constellation interaction always terminating (we believe it does)
- No unbounded creation of new rays during reduction

### 7.2 Open Problem: Confluence

**Question**: Do different reduction orders yield the same normal form?

**Known**: λ-calculus has Church-Rosser property (confluence).

**Conjecture**: Scroll nets should be confluent if sound.

**Challenge**: Interaction between different detour types is unclear. Can reducing one detour create another? If so, does order matter?

**Stellogen implication**: Unification is inherently **non-deterministic** (order of ray fusion). Confluence would mean this doesn't matter—reassuring!

## 8. Stellogen-Specific Insights

### 8.1 Fusion = Local Detour Elimination

Stellogen's **fusion** (opposite-polarity rays unifying) is precisely **local detour elimination**:
- `+intro X` and `-elim X` are a detour
- They fuse → detour eliminated

This is not coincidental—it's the **same computational principle** Donato discovered independently!

### 8.2 Process Construct as Sequential Reduction

The `process` construct in Stellogen chains interactions:
```stellogen
(:= example (process
  (+n0 0)
  [(-n0 X) (+n1 (s X))]
  [(-n1 X) (+n2 (s X))]))
```

This is **sequential composition** of proof transformations—similar to chaining detour reductions!

### 8.3 `eval` and `interact` as Reduction Strategies

- `fire`: **linear** interaction (each ray used once) → call-by-name?
- `interact`: **non-linear** (rays reusable) → call-by-need?

Could these correspond to different reduction strategies in scroll nets?

## 9. Practical Recommendations

### 9.1 Prototype with Simple Detours

**Start with ii and ai**:
- Implement as opposite-polarity constellations
- Verify automatic reduction via unification
- Test on examples (identity function, modus ponens)

### 9.2 Explicit Composition for Complex Detours

**For ia and aa**:
- Define `compose` and `graft` operations
- Use `process` to chain them
- Accept that full emergence is future work

### 9.3 Type-Guided Reduction

**Idea**: Encode reduction as a type specification:
```stellogen
(spec normalizable {
  [(-scrollnet N) (+normalize N N') (+detour_free N') ok]})
```

Attempting to inhabit this type **forces** reduction.

## 10. Future Work

### 10.1 Complete Formalization

- Prove termination for Donato's rules
- Prove confluence
- Characterize all edge cases

### 10.2 Extend to Richer Logics

- First-order logic: Quantifiers introduce new detour types
- Classical logic: Additional symmetries (duality)
- Modal logic: Box/diamond operators as "scroll variants"

### 10.3 Practical Implementation

- Build a scroll net normalizer in Stellogen
- Benchmark against lambda calculus implementations
- Explore applications (verified compilation, proof search)

## Conclusion

Normalization in scroll nets reveals a deep connection between:
- **Proof theory** (detour elimination)
- **Type theory** (β-reduction)
- **Unification** (Stellogen's core mechanic)

While full emergence of reduction from unification remains aspirational, we achieve partial success:
- Simple detours reduce naturally
- Complex detours require explicit graph operations
- The computational paradigm is validated: **interaction = reduction**

Scroll nets vindicate Stellogen's architecture: **polarity-driven unification is the essence of computation**.

---

**Key takeaway**: Normalization is not about applying rewrite rules—it's about **letting opposite forces (polarities) resolve conflicts through unification**. This is as true in scroll nets as in Stellogen, suggesting a **universal computational principle**.
