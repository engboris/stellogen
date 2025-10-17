# Scroll Nets as a Programming Paradigm

> Construction = Execution: A New Way to Think About Programming

## Abstract

This document explores scroll nets as a **programming language**, not just a proof formalism. Drawing on insights from Donato's paper and connections to **programming-by-demonstration** (PbD), we examine how scroll nets blur the boundary between program construction and execution, offering a radically different paradigm for interactive computation.

## 1. The Central Insight: Construction = Execution

### 1.1 Traditional Separation

In conventional programming:

```
Construction Phase          Execution Phase
├─ Write source code   →   ├─ Compile/interpret
├─ Define functions    →   ├─ Call functions
└─ Build data structures   └─ Manipulate data
```

These are **temporally distinct**:
- Construction happens at "programming time"
- Execution happens at "runtime"
- Clear boundary (compilation, loading, etc.)

### 1.2 Scroll Nets' Unification

In scroll nets, **there is no boundary**:

**Construction step**: Apply illative transformation (e.g., iterate a subgraph)
**Execution step**: Eliminate detour created by that transformation

**The same rules govern both**:
- **Open** (construction) ↔ **Close** (execution)
- **Iterate** (construction) ↔ **Delete** (execution)
- **Insert** (construction) ↔ **Deiterate** (execution)

**Metaphor**: Programming is like drawing on a canvas, and execution is like erasing what you drew to reveal the result hidden beneath.

### 1.3 Implications

1. **Programs are traces**: A scroll net is the **history** of its own construction
2. **Execution is proof-search**: Finding which constructions to undo
3. **Debugging = Visual inspection**: See exactly what steps were taken
4. **Incremental development**: Build and run simultaneously

**Quote from user's prompt**:
> "In this theory, there is a strong connection between the construction of programs and their execution (they follow the same rules)."

This is the **essence** of scroll nets' contribution to programming paradigms.

## 2. Programming by Demonstration

### 2.1 What is PbD?

**Programming by Demonstration** (PbD): Users show the system what they want by performing examples, and the system generalizes to a program.

**Classic example** (text editing):
```
User action:  Delete "Hello" → Type "Greetings"
System learns: Replace first word with "Greetings"
Future use: Applies to other documents
```

**Key idea**: **Show, don't tell**. The demonstration **is** the program.

### 2.2 Scroll Nets as PbD

**Connection**: In scroll nets, inference rules (illative transformations) are **manipulations of the state** (sheet of assertion).

Donato writes:
> "Peirce called them 'illative transformations'... they consist in either inserting/deleting an arbitrary graph at a given location, duplicating an arbitrary graph from a source location, or deduplicating an arbitrary graph from a target location."

This is **precisely PbD**:
- **Insert/Delete**: Add or remove content (editing)
- **Duplicate**: Copy-paste
- **Deduplicate**: Merge identical content

**Analogy**:
| Scroll Net Operation | PbD Analogy |
|---------------------|-------------|
| Insert graph at negative location | "Assume this data exists" |
| Delete graph from positive location | "Discard this intermediate result" |
| Iterate graph | "Copy this pattern here" |
| Deiterate graph | "This is redundant, merge with source" |

### 2.3 Recording the Demonstration

Traditional PbD systems face a challenge: **How to record the demonstration?**

Scroll nets solve this elegantly:
- **Arrows** (justifications) record dependencies
- **Interactions** (expansions/collapses) record structural changes
- The **final scroll net** is the demonstration, frozen in time

**Example**: Teaching a system to prove modus ponens:
1. Start with `a ∧ (a → b)` on sheet
2. "Delete this `a` from the scroll outloop" (deiterate)
3. "Close the scroll" (interaction)
4. Result: `b`

The scroll net **remembers** these steps as arrows and interactions.

### 2.4 Generalization

PbD requires **generalization**: from one example to a pattern.

In scroll nets, generalization is **parametrization**:
- Replace specific atoms (`a`, `b`) with **variables** (`X`, `Y`)
- The scroll net becomes a **template**
- Apply to new data by **unification**

**Stellogen connection**: This is exactly how constellations work!
```stellogen
(:= template {
  [(+input X)]
  [(+process X Y)]  ' Generalized transformation
  @[(+output Y)]})
```

## 3. Peirce's Inference Rules as Imperative Commands

### 3.1 Inference as Mutation

Peirce described illative transformations in **imperative** language:
- "Scribe this graph on the sheet"
- "Erase this graph from the sheet"
- "Draw a scroll around this area"

This is **imperative programming**:
```python
# Peirce's "Insert"
sheet.add(graph, location=negative_context)

# Peirce's "Iterate"
sheet.copy(source, target=positive_location)
```

### 3.2 State = Sheet of Assertion

The **sheet of assertion** is the **program state**:
- Initially: The premiss (input)
- After transformations: Intermediate states
- Finally: The conclusion (output)

**Imperative paradigm**:
```
State₀ →[transform₁] State₁ →[transform₂] ... →[transformₙ] Stateₙ
 ↑                                                             ↑
Premiss                                                   Conclusion
```

**Functional paradigm** (for contrast):
```
Output = transformₙ(...(transform₂(transform₁(Input)))...)
```

Scroll nets are **imperative**, but **reversible** (every transformation has an inverse).

### 3.3 Edit History as Computation History

Donato writes:
> "if you record the sequence of rule applications, like a history of edits of a program, this gives you scroll nets, which possess a notion of detour/redex, as in functional programming."

**Insight**: The **undo history** in a text editor is a **computation trace**!

**Example** (text editing):
```
1. Type "Hello"
2. Delete "Hello"
3. Type "World"

History: [Type("Hello"), Delete("Hello"), Type("World")]
```

Steps 1-2 are a **detour** (write then delete). Normalizing the history:
```
Optimized: [Type("World")]
```

This is **β-reduction** in the editing domain!

## 4. Scroll Nets as an Interactive Language

### 4.1 Characteristics

Scroll nets as a programming language have:

1. **Visual/Spatial**: Code is 2D diagrams (scrolls, arrows)
2. **Interactive**: Programs built incrementally via transformations
3. **Reversible**: Every operation has an inverse (undo)
4. **Proof-carrying**: Programs are their own correctness proofs
5. **Normalization-driven**: Execution = detour elimination

### 4.2 Comparison to Existing Paradigms

| Paradigm | Scroll Nets Analog |
|----------|-------------------|
| **Functional** | Detour elimination = β-reduction |
| **Imperative** | Illative transformations = statements |
| **Logic** | Scroll structure = formula |
| **Visual** | Diagrams on sheet = code |
| **Dataflow** | Justifications = data dependencies |

**Verdict**: Scroll nets are **multi-paradigm**, but closest to **visual dataflow** languages.

### 4.3 Target Domain: Interactive Theorem Proving

Donato's motivation:
> "The aim is to represent proof objects in addition to proof traces... This should allow for a new approach to interactive theorem provers (ITPs)."

**ITP workflow** (current):
1. Write proof script (tactics)
2. Script generates proof term
3. Kernel checks proof term

**ITP workflow** (with scroll nets):
1. Draw proof on sheet (interactive)
2. Each transformation recorded automatically
3. Scroll net **is** the proof object

**Advantages**:
- **Transparency**: See proof structure directly
- **Incremental**: Build proof step-by-step
- **Debugging**: Inspect intermediate states
- **Exploration**: Try different paths, backtrack easily

## 5. Connection to Stellogen's Philosophy

### 5.1 Shared Vision: Minimalism

Both scroll nets and Stellogen reject:
- Heavyweight syntax
- Predefined abstractions (types, classes, etc.)
- Separation of proof and program

Both embrace:
- Elementary operations (insert, delete, iterate)
- Emergent complexity
- User-defined meaning

### 5.2 Interactive Building Blocks

Stellogen's tagline (from CLAUDE.md):
> "Elementary interactive building blocks where computation and meaning coexist in the same language."

This **perfectly describes** scroll nets:
- **Elementary**: Six illative transformations
- **Interactive**: Applied dynamically to the sheet
- **Computation ∩ Meaning**: Arrows are both dependencies and proof steps

### 5.3 Logic-Agnostic

Stellogen:
> "Logic-agnostic programming language based on term unification."

Scroll nets:
> Intuitionistic, classical, and intermediate logics are **subsets** of scroll nets with specific topological properties.

**Common principle**: The system doesn't impose logic—users build it.

## 6. Programming Patterns in Scroll Nets

### 6.1 Pattern 1: Iteration as Loops

**Code (pseudocode)**:
```
for x in list:
    process(x)
```

**Scroll net analog**:
Iterate over list elements, justifying processing at each step:
```
[atom 1] ⊢ [process 1 → result 1]
[atom 2] ⊢ [process 2 → result 2]
[atom 3] ⊢ [process 3 → result 3]
```

**Stellogen encoding**:
```stellogen
(:= loop_pattern {
  [(+list [x|xs])]
  [(+process x result1)]
  [(+loop xs results)]
  @[(+output [result1|results])]})
```

### 6.2 Pattern 2: Branching as Polarity

**Code**:
```
if condition:
    positive_branch()
else:
    negative_branch()
```

**Scroll net analog**:
Polarity determines path:
- **Positive context**: Execute one branch
- **Negative context**: Execute dual branch

**Stellogen encoding**:
```stellogen
(:= branch {
  [(+cond true) (+pos_branch)]
  [(+cond false) (-neg_branch)]})
```

### 6.3 Pattern 3: Recursion as Nested Scrolls

**Code**:
```
def factorial(n):
    if n == 0:
        return 1
    else:
        return n * factorial(n-1)
```

**Scroll net analog**:
Nested scrolls represent recursive calls:
```
[n → [(n-1) → [(n-2) → ... → [0 → 1]]]]
```

Each inner scroll is a recursive invocation.

**Stellogen encoding**:
```stellogen
(:= factorial {
  [(+fact 0 1)]
  [(-fact (s N) R) (+fact N R1) (+mult (s N) R1 R)]})
```

## 7. Open Questions: Practical Programming

### 7.1 Expressiveness

**Question**: Can scroll nets express all computable functions?

**Approach**:
- Encode Turing machines or lambda calculus
- Donato shows STLC encoding → scroll nets are at least as expressive as STLC
- But STLC is not Turing-complete (no general recursion)

**Conjecture**: Adding cyclic scrolls (recursion) makes scroll nets Turing-complete.

### 7.2 Efficiency

**Question**: Is scroll net execution efficient?

**Challenge**:
- Detour elimination requires graph traversal (potentially expensive)
- Sharing (DAG structure) could save space, but...
- ...complexity of composition operations unclear

**Comparison to lambda calculus**:
- β-reduction is linear in term size (with sharing)
- Scroll net reduction complexity: **open problem**

### 7.3 Ergonomics

**Question**: Can programmers realistically write scroll nets by hand?

**Challenges**:
- Diagrams are verbose (vs. text)
- Maintaining graph structure manually is error-prone
- Need good tooling (editors, debuggers)

**Opportunities**:
- Visual editors (like circuit simulators)
- Interactive construction (like proof assistants)
- Automatic layout (like graph drawing algorithms)

**Stellogen advantage**: Textual encoding makes scroll nets **writable** without GUI!

## 8. Programming by Demonstration in Stellogen

### 8.1 Recording Interactions

**Idea**: Let users interact with constellations, and **record** their actions as new constellations.

**Example**:
```stellogen
' User interacts:
(show (interact #constellation1 #constellation2))
' => Result: [...]

' System records:
(:= recorded_pattern {
  [(-input1 C1) (-input2 C2)]
  [(+interact C1 C2 R)]
  @[(+output R)]})
```

This **generalizes the demonstration** to a reusable pattern.

### 8.2 Trace Replay

**Idea**: Capture interaction traces and replay them:

```stellogen
' Record trace
(:= trace [
  (step1 input1 output1)
  (step2 output1 output2)
  (step3 output2 output3)])

' Replay trace
(:= replay {
  [(-trace [(step1 I O1)|Rest])]
  [(+apply step1 I O1)]
  [(+replay Rest)]})
```

This is **programming by example**.

### 8.3 Stellogen as a PbD Platform

**Vision**: Stellogen + scroll nets = **interactive programming environment** where:
1. Users build proofs/programs graphically (via scrolls)
2. Each step recorded as constellation
3. Detours optimized automatically (via unification)
4. Result is both **executable** and **verifiable**

**Use cases**:
- Education: Visualize proof construction
- Verification: Extract programs from proofs
- Exploration: Experiment with different approaches

## 9. Tomas Petricek's Insight

**Quote**:
> "I think Pablo's work has some interesting potential as a 'logically grounded' foundational programming-by-demonstration system."

**Why "logically grounded"?**
- Traditional PbD lacks formal semantics (what does a demonstration *mean*?)
- Scroll nets provide **proof-theoretic semantics**: demonstrations are proofs
- Correctness criterion ensures demonstrations are **valid**

**Why "foundational"?**
- Not just a UI paradigm—it's a **theory** of how programming and reasoning relate
- Connects to deep results (Curry-Howard, proof nets, bigraphs)
- Could unify disparate programming paradigms under one framework

**Stellogen's role**:
- Provides **computational substrate** for scroll nets
- Makes PbD **executable** (not just pedagogical)
- Bridges theory and practice

## 10. Towards a Scroll Net Programming Language

### 10.1 Design Principles

1. **Visual-first**: Diagrams are primary, text is secondary
2. **Interactive**: Programs built in dialog with system
3. **Proof-aware**: Every program has built-in correctness evidence
4. **Reversible**: All operations have inverses (undo/redo)
5. **Exploratory**: Easy to try ideas, backtrack, refine

### 10.2 Minimal Syntax (Hypothetical)

```scrollnet
' Define a scroll net transformation
transform modus_ponens:
  premiss: a ∧ (a → b)
  steps:
    1. deiterate a from scroll outloop
    2. close scroll
  conclusion: b

' Apply transformation
apply modus_ponens to (P ∧ (P → Q))
' => Q
```

### 10.3 Integration with Stellogen

**Proposal**: Stellogen as the **backend** for a scroll net language:
- Scroll nets compile to Stellogen constellations
- Normalization uses Stellogen's unification
- Users write high-level scroll net syntax
- System generates low-level Stellogen code

**Example**:
```scrollnet
scroll(a → b)  # High-level

# Compiles to:
(:= impl_a_b {
  [(+outloop a)]
  [(+inloop b)]
  [(-scroll X) (+impl X)]})
```

## Conclusion

Scroll nets offer a radically different view of programming:
- **Programs are traces** of their own construction
- **Execution is optimization** (detour elimination)
- **Demonstration = specification**

This aligns perfectly with Stellogen's philosophy of elementary interactive building blocks. By encoding scroll nets in Stellogen, we can:
1. Make Peirce's 19th-century vision **executable**
2. Create a **programming-by-demonstration** system with formal foundations
3. Explore a **new paradigm** where construction and execution are unified

The implications extend beyond programming to **education** (visualizing proofs), **verification** (programs carry their correctness proofs), and **human-computer interaction** (show, don't tell).

**Final thought**: If "programming is theorem proving" (Curry-Howard), then **scroll nets suggest programming is also drawing**—a visual, spatial, interactive act of creation where every stroke has logical meaning.

---

**Key takeaway**: Scroll nets aren't just a representation of proofs—they're a **new way to think about what programs are** and how we create them.
