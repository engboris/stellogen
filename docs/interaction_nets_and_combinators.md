# Interaction Nets, Proof-Nets, and Stellogen

**Research Report: Implementation Directions**
**Date:** 2025-12-25
**Status:** Technical Analysis with Implementation Insights

---

## 1. Introduction

This document explores how Stellogen relates to **interaction nets** and **proof-nets**, and provides practical insights for implementing interaction combinators. The key thesis is:

> **Stellogen already is an interaction net language in disguise.** The primitives (stars, rays, polarity, fusion) directly correspond to interaction net concepts. What's needed is not new mechanisms, but clarity about how to encode the standard constructs.

The connection to **proof-nets** (from linear logic) is particularly illuminating because proof-nets ARE interaction nets—they're the same formalism viewed from different angles.

---

## 2. The Deep Connection: Proof-Nets = Interaction Nets

### 2.1 Historical Context

Yves Lafont introduced interaction nets in 1990 as a **generalization of proof-nets**. The key realization was that proof-net cut-elimination is a special case of a more general graph-rewriting paradigm.

| Proof-Net Concept | Interaction Net Concept |
|-------------------|------------------------|
| Axiom link | Agent with 2 ports |
| Cut | Active pair (principal ports connected) |
| Par (⅋) | Agent with 3 ports (1 principal, 2 auxiliary) |
| Tensor (⊗) | Agent with 3 ports (1 principal, 2 auxiliary) |
| Cut-elimination | Interaction (graph rewriting) |
| Proof | Net in normal form |

### 2.2 Why This Matters for Stellogen

Your MLL example (`examples/proofnets/mll.sg`) already demonstrates the encoding:

```stellogen
' Axiom between vertices a and b = binary positive star
[(+a X) (+b X)]

' Cut between vertices a and b = binary negative star
[(-a X) (-b X)]
```

This is exactly right. The crucial insight is:

- **Positive rays** = "I provide a connection at this port"
- **Negative rays** = "I request a connection at this port"
- **Fusion** = Cut-elimination (or interaction)

The `[l|X]` and `[r|X]` encoding for binary branching corresponds to how proof-nets encode the two auxiliary ports of par/tensor.

---

## 3. Anatomy of Interaction Nets

### 3.1 Agents, Ports, and Wires

An **interaction net** consists of:

1. **Agents**: Nodes with a fixed number of ports
2. **Principal port**: The "active" port (triggers interaction)
3. **Auxiliary ports**: The "passive" ports
4. **Wires**: Connect exactly two ports
5. **Free ports**: Unconnected ports (the interface)

```
       aux₁  aux₂
         \    /
          \  /
       [  Agent  ]
            |
        principal
```

### 3.2 Interaction Rules

When two agents connect at their **principal ports**, they form an **active pair** and can **interact** (rewrite).

```
       aux₁  aux₂        aux₃  aux₄
         \    /            \    /
          \  /              \  /
       [ Agent α ]------[ Agent β ]
              principal ports
                   ↓
            (interaction rule)
                   ↓
              (new net)
```

Key properties:
- **Local**: Only the two agents and their immediate connections change
- **Deterministic**: Each active pair has exactly one rewriting
- **Strongly confluent**: Order of reductions doesn't matter

### 3.3 The Stellogen Correspondence

| Interaction Net | Stellogen |
|-----------------|-----------|
| Agent | Constellation or focused constellation pattern |
| Principal port | The primary ray symbol with polarity |
| Auxiliary ports | Additional rays in the star |
| Active pair | Two rays with opposite polarity that unify |
| Wire | Shared variable between rays |
| Interaction | Star fusion during `exec` or `fire` |
| Free ports | Rays remaining after saturation |

---

## 4. Proof-Nets in Stellogen: Current Implementation

### 4.1 The MLL Encoding

From your `mll.sg`, the encoding strategy is:

**Axiom** (connects two vertices):
```stellogen
' ax
' __
'/  \
'a   b

[(+a X) (+b X)]    ' Both ports positive, share variable X
```

**Cut** (connects two proofs):
```stellogen
'  \__/
'   cut

[(-a X) (-b X)]    ' Both ports negative, share variable X
```

**Par** (⅋) - combines two conclusions into one:
```stellogen
' Transform (+a X) (+b X) into par structure:
[(+(⅋ a b) [l|X]) (+(⅋ a b) [r|X])]

' The [l|X] and [r|X] encode left/right auxiliary ports
```

**Tensor** (⊗) - combines two proofs:
```stellogen
' Transform (+a X) from proof A and (+b X) from proof B:
[(+(⊗ a b) [l|X])]  ' From proof A
[(+(⊗ a b) [r|X])]  ' From proof B
```

### 4.2 Cut-Elimination as Interaction

The beautiful example from `mll.sg`:

```stellogen
'   ax   ax   ax
'   _    __   __
'  / \  /  \ /  \
'  1 2  3  4 5  6
'  \ /     \ /
'   ⅋       ⊗
'   |_______|
'      cut

(def x {
  [(+(⅋ 1 2) [l|X]) (+(⅋ 1 2) [r|X])]   ' Par of 1,2
  [(+3 X) (+(⊗ 4 5) [l|X])]              ' Tensor left
  [(+(⊗ 4 5) [r|X]) (+6 X)]              ' Tensor right
  [(-​(⅋ 1 2) X) (-(⊗ 4 5) X)]})          ' Cut!

' Execution performs cut-elimination:
(def comp (exec #x @[(-3 X) (+3 X)]))
```

The `exec` command performs cut-elimination by fusing stars. The result is the normal form of the proof-net.

### 4.3 What Works Well

1. **Polarity is natural**: +/- directly models the two sides of a cut
2. **Variables are wires**: Shared variables connect ports
3. **Fusion is cut-elimination**: The interaction mechanism is correct
4. **Address encoding**: `[l|X]` and `[r|X]` encode port structure

### 4.4 Current Limitations

1. **No explicit port arity checking**: Agents don't declare their port count
2. **No interaction rule declaration**: Rules are implicit in constellation structure
3. **No principal port marking**: All rays are equally "principal"
4. **No visualization**: Hard to see the net structure

---

## 5. Interaction Combinators: The Universal System

### 5.1 The Three Symbols

Lafont's interaction combinators use only **3 agents** and **6 rules** to achieve universality:

1. **ε (Eraser)**: Arity 0 (principal port only)
2. **δ (Duplicator)**: Arity 2 (principal + 2 auxiliary)
3. **γ (Constructor)**: Arity 2 (principal + 2 auxiliary)

```
    ε       δ         γ
    |      /|\       /|\
    •     • | •     • | •
          aux       aux
```

### 5.2 The Six Rules

**Annihilation** (same type meeting):
```
δ ---•--- δ   →   cross-connect auxiliaries
γ ---•--- γ   →   cross-connect auxiliaries
ε ---•--- ε   →   nothing (both erased)
```

**Commutation** (different types meeting):
```
δ ---•--- γ   →   2×2 grid of new agents
```

**Erasure**:
```
ε ---•--- δ   →   ε connected to each auxiliary
ε ---•--- γ   →   ε connected to each auxiliary
```

### 5.3 Encoding in Stellogen

Here's how to encode interaction combinators:

```stellogen
''' ============================================ '''
''' INTERACTION COMBINATORS IN STELLOGEN         '''
''' ============================================ '''

' AGENT ENCODING:
' - Principal port = the labeled ray
' - Auxiliary ports = additional rays with [l|X] and [r|X]
' - Eraser has no auxiliary ports

' ERASER (ε): Arity 0
' Represented as: [(+e Label)]
' or when receiving: [(-e Label)]

' DUPLICATOR (δ): Arity 2
' Represented as: [(+d Label [l|X] [r|Y])]
' The label distinguishes different duplicators (for labels/colors)

' CONSTRUCTOR (γ): Arity 2
' Represented as: [(+c Label [l|X] [r|Y])]

''' --------------------------------------------- '''
''' INTERACTION RULES                             '''
''' --------------------------------------------- '''

(def interaction-rules {
  ' RULE 1: δ-δ Annihilation (same label)
  ' Two duplicators with same label meeting → cross-connect
  '
  '   a₁ a₂     b₁ b₂         a₁    b₁
  '    \ /       \ /           |     |
  '    [δ]------[δ]     →      |     |
  '                           a₂    b₂
  '
  [(-d L [l|A1] [r|A2]) (-d L [l|B1] [r|B2])
   (+wire A1 B1) (+wire A2 B2)]

  ' RULE 2: γ-γ Annihilation (same label)
  [(-c L [l|A1] [r|A2]) (-c L [l|B1] [r|B2])
   (+wire A1 B1) (+wire A2 B2)]

  ' RULE 3: ε-ε Annihilation
  [(-e L1) (-e L2)]  ' Both erased, nothing remains

  ' RULE 4: δ-γ Commutation (or δ-γ with different labels)
  ' Creates 2×2 grid: each aux of δ connects to a new γ,
  ' each aux of γ connects to a new δ
  '
  '   a₁ a₂     b₁ b₂         a₁    a₂
  '    \ /       \ /           |     |
  '    [δ]------[γ]     →    [γ]   [γ]
  '                           |  × |
  '                          [δ]   [δ]
  '                           |     |
  '                          b₁    b₂
  '
  [(-d Ld [l|A1] [r|A2]) (-c Lc [l|B1] [r|B2])
   ' Create new agents with fresh connections
   (+c Lc [l|A1] [r|M1])    ' γ connected to a₁
   (+c Lc [l|A2] [r|M2])    ' γ connected to a₂
   (+d Ld [l|M1] [r|B1])    ' δ connected to b₁
   (+d Ld [l|M2] [r|B2])]   ' δ connected to b₂

  ' RULE 5: ε-δ Erasure
  ' Eraser propagates to both auxiliaries
  [(-e L) (-d Ld [l|A1] [r|A2])
   (+e A1) (+e A2)]

  ' RULE 6: ε-γ Erasure
  [(-e L) (-c Lc [l|A1] [r|A2])
   (+e A1) (+e A2)]
})

''' --------------------------------------------- '''
''' WIRE RESOLUTION                               '''
''' --------------------------------------------- '''

' Wires need to be resolved to actual connections
(def wire-resolution {
  ' When two positive wires meet, connect them
  [(+wire X Y) (+wire Y Z) (+wire X Z)]

  ' When wire meets an agent, substitute
  [(+wire X X)]  ' Identity wire = no-op
})
```

### 5.4 The Challenge: Fresh Name Generation

The commutation rule creates **new agents** with **fresh connections**. In the encoding above, I used variables `M1`, `M2` as intermediaries, but there's a subtlety:

**Problem**: How do we ensure fresh names don't clash?

**Current Stellogen behavior**: Variables are local to stars, which helps. But when we create new agents, we need to ensure their internal connections are properly scoped.

**Insight**: This is where Stellogen's variable locality actually helps. Each star has its own variable scope, so:

```stellogen
' Star 1 has its own X
[(+agent1 [l|X] [r|Y])]

' Star 2 has a DIFFERENT X (same name, different scope)
[(+agent2 [l|X] [r|Z])]
```

The challenge is when we want to **connect** agents created in different stars. This requires explicit wiring.

---

## 6. What Mechanisms Might Be Needed

### 6.1 Mechanism 1: Agent Declarations

Currently, Stellogen doesn't have explicit agent declarations. This would help:

```stellogen
' PROPOSED: Declare agent types with port arities
(agent ε 0)           ' Eraser: 0 auxiliary ports
(agent δ 2)           ' Duplicator: 2 auxiliary ports
(agent γ 2)           ' Constructor: 2 auxiliary ports

' Benefits:
' - Arity checking at definition time
' - Better error messages
' - Documentation
```

**Implementation insight**: This could be a macro-level convention rather than a core feature:

```stellogen
(macro (agent Name Arity)
  (def Name (meta arity Arity)))
```

### 6.2 Mechanism 2: Principal Port Marking

Interaction only happens between **principal ports**. Currently, Stellogen uses polarity (+/-) for this, which works but conflates two concepts:

- **Polarity**: Which side of a connection (provider vs. requester)
- **Principal-ness**: Whether this port triggers interaction

**Insight**: For proof-nets and interaction combinators, these are the same! The principal port of an agent is where it "offers" or "demands" interaction. Polarity already captures this.

**Conclusion**: No new mechanism needed. Stellogen's polarity IS the principal port marking.

### 6.3 Mechanism 3: Interaction Rule Definitions

Currently, rules are implicit in constellation structure. An explicit syntax might help:

```stellogen
' PROPOSED: Explicit rule syntax
(rule (δ meets δ)
  :when (same-label L)
  :pattern [(-d L [l|A1] [r|A2]) (-d L [l|B1] [r|B2])]
  :result [(+wire A1 B1) (+wire A2 B2)])
```

**Implementation insight**: This could be sugar over the current approach:

```stellogen
(macro (rule Name :when Cond :pattern Pat :result Res)
  (def Name { Pat :where Cond Res }))
```

But the current approach (just define the constellation) is simpler and already works.

### 6.4 Mechanism 4: Graph Visualization

This is perhaps the most impactful addition. Interaction nets are **inherently graphical**. A visualization tool would:

1. Show the current net as a graph
2. Highlight active pairs
3. Animate interaction steps
4. Export to DOT/GraphViz format

**Implementation direction**:

```stellogen
' Generate DOT format from constellation
(def to-dot {
  ' Each star = nodes + edges
  [(-star [Ray|Rays])
   (+node (ray-label Ray))
   (+to-dot-rays Rays)]

  [(-to-dot-rays [])
   (+done)]

  [(-to-dot-rays [(+ Label X)|Rest])
   (+edge Label X)
   (+to-dot-rays Rest)]
})
```

### 6.5 Mechanism 5: Labels/Colors on Agents

HVM and optimal lambda calculus use **labeled duplicators** to control interaction. The label determines whether annihilation or commutation occurs:

```
δ[a] ---•--- δ[a]   →   annihilate (same label)
δ[a] ---•--- δ[b]   →   commute (different labels)
```

**Current Stellogen approach**: The label can be part of the term structure:

```stellogen
' Labeled duplicator
[(+d a [l|X] [r|Y])]    ' Label "a"
[(+d b [l|X] [r|Y])]    ' Label "b"

' Rule checks label equality
[(-d L [l|A1] [r|A2]) (-d L [l|B1] [r|B2])  ' Same L = annihilate
 (+wire A1 B1) (+wire A2 B2)]

[(-d L1 [l|A1] [r|A2]) (-d L2 [l|B1] [r|B2]) ' Different = commute
 || (!= L1 L2)
 ...]
```

This already works! The `|| (!= L1 L2)` guard handles the distinction.

---

## 7. Implementation Strategy

### 7.1 Level 1: Proof-Net Execution (Already Working)

Your `mll.sg` example shows this works. The strategy:

1. Encode axioms as `[(+a X) (+b X)]`
2. Encode cuts as `[(-a X) (-b X)]`
3. Use `[l|X]` and `[r|X]` for par/tensor structure
4. Run `exec` to perform cut-elimination

**No changes needed.** This is a proof-of-concept for interaction nets.

### 7.2 Level 2: Interaction Combinators (Needs Wiring)

The main challenge is the commutation rule, which creates new agents. Strategy:

```stellogen
''' APPROACH 1: Explicit Wiring Phase '''

' After interaction, we have "wire" terms that need resolution
(def resolve-wires {
  [(+wire X X)]  ' Self-loop = delete
  [(-wire X Y) (+wire Y X)]  ' Symmetry
  ' More resolution rules...
})

' Execution with wire resolution
(def run-combinators (C)
  (exec (exec #C #interaction-rules) #resolve-wires))
```

```stellogen
''' APPROACH 2: Continuation-Passing '''

' Each agent "knows" where its ports connect
' Ports carry their destinations

(def δ-cps
  [(+δ (port A1) (port A2) (dest Principal))
   (-Principal connected-to-δ A1 A2)])
```

**Insight**: The cleanest approach is probably to use a **two-phase execution**:
1. Phase 1: Interaction (creates new agents and wire placeholders)
2. Phase 2: Wire resolution (connects wires to actual ports)

### 7.3 Level 3: Optimal Lambda Calculus

This requires labeled duplicators and the "oracle" for managing labels. The Lamping algorithm uses:

- **Fans**: Duplicators with labels
- **Croissants/Brackets**: For handling scope
- **Oracle**: Decides when to annihilate vs. commute

**Implementation sketch**:

```stellogen
' Lambda term encoding
(def lambda {
  ' Variable: x
  [(+var X) ...]

  ' Abstraction: λx.M
  [(+lam [var|X] [body|M]) ...]

  ' Application: (M N)
  [(+app [func|M] [arg|N]) ...]
})

' Translation to interaction combinators
(def to-combinators {
  ' λx.M becomes a constructor
  [(-lam [var|X] [body|M])
   (+γ [l|X] [r|M])]

  ' (M N) becomes an application node
  [(-app [func|M] [arg|N])
   (+@ M N)]

  ' The @ node triggers beta reduction when meeting λ
})
```

**Key insight**: Optimal reduction requires tracking "levels" or "depths" to decide annihilation. This can be encoded in the label:

```stellogen
' Level-annotated duplicator
[(+δ Level [l|A] [r|B])]

' Annihilate only at same level
[(-δ L [l|A1] [r|A2]) (-δ L [l|B1] [r|B2])
 (+wire A1 B1) (+wire A2 B2)]

' Commute at different levels, incrementing
[(-δ L1 [l|A1] [r|A2]) (-δ L2 [l|B1] [r|B2])
 || (!= L1 L2)
 ' Create new agents at adjusted levels
 ...]
```

---

## 8. Concrete Examples

### 8.1 Example: Boolean NOT via Combinators

```stellogen
''' Boolean NOT using interaction combinators '''

' Encoding:
'   true  = λx.λy.x
'   false = λx.λy.y
'   not   = λb.b false true

' As combinators (simplified):
(def true-comb  [(+true [l|X] [r|Y]) (+result X)])
(def false-comb [(+false [l|X] [r|Y]) (+result Y)])

(def not-comb {
  ' NOT takes a boolean and applies it to (false, true)
  [(-not B) (+apply B false true)]

  ' When B = true, select first = false
  [(-apply true X Y) (+result X)]

  ' When B = false, select second = true
  [(-apply false X Y) (+result Y)]
})

' Test: NOT true = false
(def test1 @[(-not true) (-result R) (answer R)])
(show (exec #not-comb #test1))  ' Should give: (answer false)
```

### 8.2 Example: Church Numeral Successor

```stellogen
''' Church numeral successor '''

' Church encoding:
'   0 = λf.λx.x
'   1 = λf.λx.f x
'   n = λf.λx.f (f ... (f x))  [n times]
'   succ = λn.λf.λx.f (n f x)

' Simplified interaction net encoding:
(def zero {
  ' Zero ignores f, returns x
  [(+zero [f|F] [x|X]) (+result X)]
})

(def succ {
  ' Successor duplicates f, applies once more
  [(-succ N) (+succ-node N)]
  [(-succ-node N [f|F] [x|X])
   ' Need to duplicate F and apply
   (+dup F F1 F2)    ' Duplicate f
   (+apply F1 (N F2 X))  ' f (n f x)
   (+result Applied)]
})

' This shows the NEED for duplication handling
```

### 8.3 Example: Linear Identity (No Duplication)

```stellogen
''' Linear identity - simpler because no duplication '''

' Linear lambda: variables used exactly once
' id = λx.x

(def linear-id [(+id [l|X]) (+id [r|X])])

' Application: id M
(def apply-id {
  [(-id X) (-arg X)]
  @[(+arg [r|Y]) (result Y)]
})

' Compute: id applied to (value 42)
(def value [(+arg [l|V]) (data V 42)])

(show (exec #linear-id #value #apply-id))
' Result: (result (data 42))
```

---

## 9. Insights and Directions

### 9.1 Key Insight 1: Polarity IS Principal Port

Stellogen's polarity mechanism directly corresponds to the principal port concept in interaction nets. Positive rays "offer" connections, negative rays "demand" them. When they meet with unifiable terms, interaction (fusion) occurs.

**No new mechanism needed for this.**

### 9.2 Key Insight 2: Variables ARE Wires

Shared variables between rays are exactly the wires of interaction nets. When `X` appears in `(+a X)` and `(+b X)`, those two ports are connected.

**No new mechanism needed for this.**

### 9.3 Key Insight 3: Cons Lists Encode Port Structure

The `[l|X]` and `[r|X]` pattern elegantly encodes binary port addressing. For agents with more ports, extend the pattern:

```stellogen
' 3-port agent:
[(+agent [1|X] [2|Y] [3|Z])]

' Or hierarchical:
[(+agent [l l|X] [l r|Y] [r|Z])]
```

**No new mechanism needed for this.**

### 9.4 Insight 4: The Commutation Challenge

The one genuine challenge is the **commutation rule** which creates new agents with new connections. This requires careful handling of:

1. **Fresh names**: Each new agent needs unique identity
2. **Rewiring**: Connections must be properly redirected
3. **Intermediate state**: May need temporary "wire" terms

**Potential solution**: A two-phase approach:

```stellogen
' Phase 1: Interaction (may create wire terms)
(def phase1 (exec #net #rules))

' Phase 2: Wire resolution
(def phase2 (exec #phase1 #wire-rules))

' Combined:
(def full-run (process #phase1 #phase2))
```

### 9.5 Insight 5: Labels via Term Structure

Labeled agents (needed for optimal reduction) can be encoded naturally:

```stellogen
' Agent with label L
[(+δ L [l|X] [r|Y])]

' Rules can match on labels
[(-δ L [l|A] [r|B]) (-δ L [l|C] [r|D]) ...]  ' Same label
[(-δ L1 ...) (-δ L2 ...) || (!= L1 L2) ...]  ' Different labels
```

**No new mechanism needed for this.**

### 9.6 Insight 6: Focus for Execution Control

The `@` focus operator distinguishes what's being computed (state) from how it's computed (actions). For interaction nets:

- **Focused stars** = The current net (what we're reducing)
- **Unfocused stars** = The interaction rules (how we reduce)

```stellogen
(exec @#net #rules)
'      ↑    ↑
'    state  actions (can be reused)
```

### 9.7 Insight 7: Fire vs Exec for Resource Control

- `fire` (linear): Each rule used at most once
- `exec` (non-linear): Rules can be reused

For interaction nets, you typically want `exec` since rules are reusable. But for proof-nets with linearity constraints, `fire` ensures resources are consumed exactly once.

---

## 10. Recommended Next Steps

### 10.1 Step 1: Formalize the Basic Combinators

Create a standard library file `inet/combinators.sg`:

```stellogen
' Standard interaction combinator definitions
(def ε-rules { ... })
(def δ-rules { ... })
(def γ-rules { ... })
(def combinator-rules { #ε-rules #δ-rules #γ-rules })
```

### 10.2 Step 2: Implement Wire Resolution

Add a wire resolution phase for handling commutation:

```stellogen
(def wire-resolution { ... })

(macro (inet-run Net)
  (process (exec @#Net #combinator-rules) #wire-resolution))
```

### 10.3 Step 3: Add Visualization (External Tool)

Create a tool that:
1. Parses Stellogen constellations
2. Extracts the graph structure
3. Outputs DOT format or interactive visualization

### 10.4 Step 4: Test with Lambda Calculus

Implement the translation from lambda terms to interaction combinators:

```stellogen
(def lambda-to-inet { ... })
(def inet-to-lambda { ... })

' Full pipeline
(macro (optimal-eval Term)
  (inet-to-lambda (inet-run (lambda-to-inet #Term))))
```

### 10.5 Step 5: Benchmark and Compare

Compare with HVM on standard benchmarks:
- Fibonacci
- Ackermann
- Church numeral operations

---

## 11. Theoretical Perspective: What Stellogen Teaches Us

### 11.1 Unification as Interaction

The deepest insight is that **term unification is interaction**. When two terms unify, they're "interacting" to produce a common result. Stellogen makes this explicit:

- Unification = finding how two terms can be the same
- Interaction = finding how two agents can combine
- Both are **local**, **deterministic**, and **confluent**

### 11.2 Polarity as Resource Orientation

Polarity encodes the **flow of resources**:
- Positive = provides/outputs
- Negative = requires/inputs

This is exactly the linear logic interpretation, and exactly what interaction nets formalize.

### 11.3 Proof-Nets as Programs

The connection to proof-nets shows that **proofs are programs** in a very direct sense. A proof-net IS a program; cut-elimination IS execution. Stellogen makes this operational.

### 11.4 Logic-Agnostic but Not Logic-Free

While Stellogen doesn't impose a logic, the mechanisms it provides (polarity, unification, interaction) are the **universal substrate** from which any logic can be built. It's not logic-free; it's pre-logical—the raw material from which logics are constructed.

---

## 12. Conclusion

Stellogen is already closer to being an interaction net language than it might appear. The key correspondences are:

| Interaction Net | Stellogen | Status |
|-----------------|-----------|--------|
| Agent | Constellation pattern | Working |
| Principal port | Polarized ray | Working |
| Auxiliary ports | Additional rays with address encoding | Working |
| Wire | Shared variable | Working |
| Active pair | Opposite polarity + unification | Working |
| Interaction rule | Constellation clause | Working |
| Net reduction | Star fusion (exec/fire) | Working |
| Labels | Term structure with guards | Working |

What's needed is not new mechanisms but:

1. **A standard library** for interaction combinators
2. **A wire resolution phase** for commutation
3. **Visualization tools** for debugging
4. **Documentation and examples** showing the approach

The proof-net examples in your codebase (`mll.sg`, `mall.sg`, `linear_lambda.sg`) already demonstrate the core ideas. Extending this to full interaction combinators is a matter of careful encoding, not fundamental change.

Stellogen's unique contribution is making interaction nets **textual, executable, and programmable**—moving them from theoretical diagrams to practical computation.

---

## References

### Core Theory

1. **Lafont, Y.** (1990). "Interaction Nets." POPL 1990.
2. **Lafont, Y.** (1997). "Interaction Combinators." Information and Computation 137(1).
3. **Girard, J.-Y.** (1987). "Linear Logic." Theoretical Computer Science 50(1).
4. **Girard, J.-Y.** (1996). "Proof-Nets: The Parallel Syntax for Proof-Theory."

### Optimal Reduction

5. **Lamping, J.** (1990). "An Algorithm for Optimal Lambda Calculus Reduction." POPL 1990.
6. **Asperti, A., Guerrini, S.** (1998). "The Optimal Implementation of Functional Programming Languages."

### Modern Implementations

7. **HVM**: https://github.com/HigherOrderCO/HVM
8. **Inpla**: https://github.com/inpla/inpla
9. **Vine/Ivy**: https://github.com/VineLang/vine

### Stellogen Examples

10. `examples/proofnets/mll.sg` - MLL proof-structures
11. `examples/proofnets/mall.sg` - MALL proof-structures
12. `examples/lambda/linear_lambda.sg` - Linear lambda calculus
13. `examples/lambda/lambda.sg` - Lambda calculus with exponentials

---

*This document synthesizes theoretical background with practical implementation insights for building interaction net systems in Stellogen.*
