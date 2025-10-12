# Synchronization in Boolean Circuits: A Stellogen Challenge

> **Disclaimer**: This document was written with the assistance of Claude Code and represents exploratory research and analysis. The content may contain inaccuracies or misinterpretations and should not be taken as definitive statements about the Stellogen language implementation.

**Author:** Analysis based on `examples/circuits.sg`
**Date:** 2025-10-10
**Status:** Research Document

---

## Abstract

This document analyzes a fundamental challenge that arises when encoding boolean circuits in Stellogen: the need for **local synchronization** between multiple inputs before computation can proceed. Boolean gates require all inputs to be concrete values before producing an output, but Stellogen's eager unification-based evaluation allows partial computation with unknown variables, potentially causing infinite loops in finite circuits.

We explore the tension between Stellogen's philosophy of purely local term interaction and the implicit coordination requirements of certain computational models. Seven solution approaches are analyzed, ranging from manual encoding patterns to language extensions, evaluated on their alignment with Stellogen's design principles.

---

## 1. Problem Statement

### 1.1 The Circuit Encoding

In `examples/circuits.sg`, boolean semantics are encoded as constellations:

```stellogen
(:= semantics {
  [(+1 1)]
  [(+0 0)]
  [(+s X X X)]                    ' splitter: duplicates input
  [(+not 1 0)] [(+not 0 1)]       ' NOT gate
  [(+and 1 X X)] [(+and 0 X 0)]   ' AND gate
})
```

A circuit is constructed by connecting wires (represented as rays) through layers:

```stellogen
(process
  ' inputs
  [(-0 X) (+c0 X)]
  ' layer 1
  {[(-c0 X) (-not X R) (+c2 R)]
   [(-c1 X) (-not X R) (+c3 R)]}
  ' layer 2
  {(-c2 X) (-c3 Y) (-and X Y R) (+c4 R)}
  ' output
  [(-c4 R) R]
  ' apply semantics
  #semantics)
```

### 1.2 The Synchronization Problem

Consider the AND gate interaction in layer 2:

```stellogen
(-c2 X) (-c3 Y) (-and X Y R) (+c4 R)
```

This constellation waits for values on wires `c2` and `c3`, then computes their AND, producing a result on `c4`.

**The issue:** When the ray `(-and X Y R)` tries to interact with the semantics constellation `[(+and 1 X X)]`, Stellogen's unification proceeds even if only one input is known:

- Suppose wire `c2` carries value `1`, but wire `c3` hasn't received a value yet (`Y` is unbound)
- The unification `(-and 1 Y R)` with `(+and 1 X X)` **succeeds** with substitution `{Y ↦ X', R ↦ X'}` (fresh variable `X'`)
- The circuit continues with `R` bound to an unknown variable
- Downstream gates may now attempt to compute with this unknown, potentially triggering infinite loops

**Expected behavior:** The AND gate should **block** until both inputs are concrete values (0 or 1), only then producing an output.

### 1.3 Root Cause: Eager Unification

The raymatcher in `src/lsc_ast.ml:96-97`:

```ocaml
let raymatcher r r' : substitution option =
  if is_polarised r && is_polarised r' then solution [ (r, r') ] else None
```

invokes the standard first-order unification algorithm (`solution` from `src/unification.ml`), which:

1. **Does not distinguish** between "waiting for a value" and "matched with a fresh variable"
2. **Allows variables to unify with any term**, including other variables
3. **Proceeds eagerly** whenever a substitution exists, regardless of groundness

This is the correct behavior for logic programming (Prolog-style), where variables represent unknowns to be solved. But for circuits, variables represent **wires waiting for signals**, and computation should be **data-driven**: gates compute only when all inputs arrive.

---

## 2. When Synchronization Matters

### 2.1 Patterns That Work Without Synchronization

Many Stellogen programs work perfectly without explicit synchronization:

#### **Sequential/Pipeline Computation** (`examples/stack.sg`)

```stellogen
(process
  #(init 0)
  [(-stack 0 X) (+stack 1 [1|X])]      ' step depends on previous
  [(-stack 1 X) (+stack 2 [0|X])]      ' linear dependency chain
  [(-stack 2 [C|X]) (+stack 3 X) (+save C)])
```

Each step consumes the output of the previous step. Variables get bound progressively in a clear sequence.

#### **Recursive Unfolding** (`examples/nat.sg`, `examples/prolog.sg`)

```stellogen
(:= add {
  [(+add 0 Y Y)]
  [(-add X Y Z) (+add (s X) Y (s Z))]})
```

Addition recursively unfolds the first argument until reaching base case. At each step, pattern matching drives progress—there's a natural directionality.

#### **Database Queries** (`examples/prolog.sg`)

```stellogen
(:= grandparent {
  [(-grandparent X Z) (-parent X Y) (+parent Y Z)]})
```

Queries search through fact databases. Variables get instantiated by matching against facts, not by "waiting for incoming data."

### 2.2 When Synchronization Becomes Critical

The synchronization problem arises specifically in **data-driven convergent computation**:

1. **Multiple independent inputs** converge at a single point
2. **All inputs must be concrete** before computation proceeds
3. **No natural ordering** dictates which input arrives first
4. **Partial evaluation is meaningless** (e.g., `AND(1, ??)` has no sensible interpretation)

Boolean circuits are the canonical example, but this pattern appears in:
- **Join operations** in dataflow networks
- **Barrier synchronization** in concurrent systems
- **N-ary functions** requiring all arguments before evaluation
- **Pattern matching on multiple scrutinees** simultaneously

---

## 3. Philosophical Considerations

### 3.1 Stellogen's Design Principles

From the README and CLAUDE.md, Stellogen's core philosophy:

> "Compilers and interpreters no longer carry semantic authority: their role is only to check that blocks connect. The semantic power (and the responsibility that comes with it) belongs entirely to the user."

This suggests:
- **Minimalism**: The language provides mechanisms, not policies
- **Locality**: Computation happens through local ray interactions
- **User control**: Programmers encode their own semantics

### 3.2 The Synchronization Design Space

Three perspectives on handling synchronization:

#### **Option A: User Responsibility (Explicit Encoding)**
- Users manually encode synchronization using existing primitives
- Keeps language minimal and agnostic
- Cons: Verbose, error-prone, obscures intent

#### **Option B: Minimal Language Extension**
- Add a small, general primitive (e.g., strictness annotations)
- Extends "blocks connect" checking to include "groundness connects"
- Still local, still declarative
- Cons: Adds complexity to core unification

#### **Option C: Automatic Inference**
- Language analyzes code to infer synchronization needs
- Maximum convenience for users
- Cons: Non-local, semantic interpretation by compiler (violates philosophy)

### 3.3 Alignment with "Logic Agnosticism"

Stellogen aims to be **logic-agnostic**: not imposing a particular logical interpretation (classical, intuitionistic, linear, etc.). How does synchronization fit?

- **Eager unification** implicitly chooses a "don't care about groundness" logic
- **Strictness checking** doesn't impose a logic—it enforces user-specified data dependencies
- **Synchronization as a connection constraint** aligns with "checking that blocks connect"

**Conclusion:** Adding minimal synchronization primitives is consistent with Stellogen's philosophy if framed as **connection constraints** rather than computational semantics.

---

## 4. Solution Space

We explore seven approaches, ordered roughly by increasing invasiveness to the language.

### 4.1 Solution 1: Continuation-Passing Style (CPS)

**Idea:** Manually stage computation so gates can't fire until all inputs ready.

**Example:**

Original (broken):
```stellogen
[(-c2 X) (-c3 Y) (-and X Y R) (+c4 R)]
```

Rewritten (staged):
```stellogen
' Stage 1: Collect inputs
[(-c2 X) (+partial_and_left X)]
[(-c3 Y) (+partial_and_right Y)]

' Stage 2: Compute when both present
[(-partial_and_left A) (-partial_and_right B) (-and A B R) (+c4 R)]
```

**Mechanism:** Intermediate wires `partial_and_left` and `partial_and_right` act as accumulators. The final computation only triggers when both have fired.

**Pros:**
- Works with current Stellogen (no language changes)
- Purely local interactions
- Makes data flow explicit

**Cons:**
- Extremely verbose (circuit size explodes)
- Manual and error-prone
- Obscures the circuit structure
- Doesn't scale to N-ary gates

**Locality:** ✓✓✓ (Fully local)
**Invasiveness:** ✓✓✓ (Zero changes)
**Philosophy alignment:** High (user encodes semantics)

---

### 4.2 Solution 2: Value Wrappers

**Idea:** Introduce a `(ready V)` constructor to mark concrete values, and only match on wrapped values.

**Example:**

```stellogen
(:= semantics {
  [(+and (ready 1) (ready X) (ready X))]
  [(+and (ready 0) (ready X) (ready 0))]
})

' Circuit:
[(-c0 X) (+ready X)]                                    ' wrap input
[(-ready A) (-ready B) (-and (ready A) (ready B) R)]   ' only unwraps when both ready
```

**Mechanism:** Unification can only match `(ready V)` when `V` is actually bound. If `B` is unbound, `(ready B)` won't match `(ready X)` in the gate definition because `B` is still a variable.

**Wait, that doesn't work!** Unification would still succeed with `{B ↦ X}`. We need the wrapper to block unless the inner term is ground.

**Revised approach:** Use convention where gates check for groundness:

```stellogen
[(+and (ready !1) (ready !X) (ready X))]  ' hypothetical: ! means "must be ground"
```

But this reduces to Solution 4.3 (strictness annotations).

**Pros:**
- Explicit readiness semantics
- No language changes (if using convention)

**Cons:**
- Doesn't actually solve the problem without additional checks
- Syntactic overhead
- Easy to forget wrappers

**Locality:** ✓✓✓ (Local if working)
**Invasiveness:** ✓✓ (Convention-based, or needs language support)
**Philosophy alignment:** Medium

---

### 4.3 Solution 3: Strictness Annotations ⭐ (RECOMMENDED)

**Idea:** Add a `!` prefix in patterns to mark positions that **must be ground** (contain no variables) for unification to succeed.

**Example:**

```stellogen
(:= semantics {
  [(+and !1 !X X)]    ' ! means "must not contain any variables"
  [(+and !0 !X 0)]
})
```

When `(-and 1 Y R)` attempts to unify with `(+and !1 !X X)`:
- Check if `Y` is ground (fully instantiated, no variables)
- If `Y` is a variable, **unification fails** (gate doesn't fire)
- If `Y = 0` or `Y = 1`, unification proceeds normally

**Implementation sketch:**

1. Extend parser to recognize `!` prefix
2. Add AST node: `Strict of term`
3. Modify `raymatcher` in `lsc_ast.ml:96`:

```ocaml
let raymatcher r r' : substitution option =
  if is_polarised r && is_polarised r' then
    match solution [ (r, r') ] with
    | Some theta ->
        if satisfies_strictness_constraints theta r r'
        then Some theta
        else None
    | None -> None
  else None
```

4. `satisfies_strictness_constraints` checks that terms marked with `!` are ground after applying substitution `theta`

**A term is ground if:** `vars(subst(theta, t)) = ∅` (no variables remain after substitution)

**Pros:**
- **Declarative**: Gate semantics specify their requirements
- **Local**: Check happens during ray fusion
- **Minimal**: Single new syntactic form, small change to unification
- **Composable**: Each gate independently declares strictness
- **Backwards compatible**: Existing code without `!` works as before
- **Fits philosophy**: Extends "blocks connect" to "blocks connect appropriately"

**Cons:**
- Requires language modification (parser, AST, evaluator)
- Programmers must understand when to use `!`
- Potential performance cost (groundness checking on every unification)

**Locality:** ✓✓✓ (Fully local check)
**Invasiveness:** ✓✓ (Requires parser and evaluator changes)
**Philosophy alignment:** ✓✓✓ High (declarative constraints, user-specified)

---

### 4.4 Solution 4: Arity and Directionality Declarations

**Idea:** Explicitly declare which positions are inputs (must be ground) and which are outputs.

**Example:**

```stellogen
(gate-spec and
  (inputs [0 1])    ' positions 0 and 1 are inputs (must be ground)
  (outputs [2]))    ' position 2 is output

(:= semantics {
  [(+and 1 X X)]    ' evaluator automatically checks positions 0, 1 are ground
  [(+and 0 X 0)]
})
```

The evaluator consults `gate-spec` declarations to determine strictness.

**Pros:**
- Centralized specification (all gates declared in one place)
- Can enable optimizations (e.g., partial evaluation planning)
- Clear input/output separation

**Cons:**
- **Non-local**: Gate behavior depends on separate declaration
- **Violates philosophy**: Semantic interpretation by compiler
- More complex implementation (symbol table, lookup during unification)
- Less flexible (what if a gate sometimes has strict/non-strict behavior?)

**Locality:** ✗ (Requires non-local declarations)
**Invasiveness:** ✓ (Significant: new declaration form, evaluator complexity)
**Philosophy alignment:** ✓ Low (semantic interpretation by system)

---

### 4.5 Solution 5: Multi-Phase Interaction

**Idea:** Change fusion semantics to distinguish **accumulation** (collecting inputs) from **computation** (producing outputs).

**Example:**

```stellogen
' Phase 1: Accumulate inputs (special accumulator rays)
[(+and_acc left X) ...]
[(+and_acc right Y) ...]

' Phase 2: Compute when accumulator complete
[(-and_acc left X) (-and_acc right Y) (+and_compute X Y)]
[(+and_compute 1 X X)]
[(+and_compute 0 X 0)]
```

**Mechanism:** The evaluator distinguishes accumulator rays from computation rays. Accumulation happens first, computation only when all accumulators present.

**Pros:**
- Explicit two-phase model matches hardware intuition
- Could be generalized (stages, priorities, etc.)

**Cons:**
- **Very verbose**: Every gate needs accumulator logic
- **Not scalable**: N-ary gates need N accumulator rays
- **Obscures semantics**: What should be a simple gate becomes complex
- Still requires language support (how to mark accumulator vs compute rays?)

**Locality:** ✓✓ (Phases are local, but verbose)
**Invasiveness:** ✓✓ (New semantics for phases)
**Philosophy alignment:** Medium (explicit encoding, but complex)

---

### 4.6 Solution 6: Polarity-Based Synchronization

**Idea:** Use polarity not just for fusion direction, but also to encode synchronization.

**Example:** Use a special polarity (e.g., `~`) to mean "must be ground":

```stellogen
[(+and ~1 ~X X)]    ' ~ means positive polarity + groundness requirement
```

Or introduce **barrier polarities**:

```stellogen
[(+and ||1 ||X X)]  ' || means "synchronization barrier"
```

**Mechanism:** Extend the polarity system (`Pos | Neg | Null` in `lsc_ast.ml:3-7`) with additional tags. Modify `compatible` function to include groundness checks.

**Pros:**
- Reuses existing polarity mechanism
- Polarity already drives interaction, so conceptually unified

**Cons:**
- **Conflates orthogonal concerns**: Polarity is about fusion direction, groundness is about data readiness
- **Less clear**: Overloading polarity reduces readability
- Similar invasiveness to strictness annotations but less intuitive

**Locality:** ✓✓✓ (Local check)
**Invasiveness:** ✓✓ (Polarity system extension)
**Philosophy alignment:** ✓✓ Medium (reuses existing concept, but overloaded)

---

### 4.7 Solution 7: Constraint-Based Delayed Unification

**Idea:** Don't fail when unification encounters non-ground terms; instead, record a **constraint** that must be satisfied before the interaction completes.

**Example:**

When `(-and 1 Y R)` tries to unify with `(+and !1 !X X)`:
1. Unification produces substitution `{Y ↦ X', R ↦ X'}` **and** constraint `ground(Y)`
2. The ray remains in a **suspended** state
3. When `Y` later gets bound to a concrete value, the constraint is checked
4. If satisfied, the suspended interaction completes; otherwise, it fails

**Mechanism:**
- Extend constellation state to include suspended interactions
- Each interaction carries a constraint set
- Evaluator periodically checks constraints and resumes suspended interactions

**Pros:**
- **Most flexible**: Supports partial evaluation and constraint propagation
- **General**: Can express many kinds of constraints, not just groundness
- Aligns with constraint logic programming (CLP)

**Cons:**
- **Very complex implementation**: Requires constraint store, suspension/resumption mechanism
- **Non-local in time**: Interaction doesn't complete immediately
- **Performance**: Overhead of managing suspended states
- **Violates Stellogen's simplicity**: Adds substantial conceptual and implementation complexity

**Locality:** ✗ (Suspended state is non-local)
**Invasiveness:** ✗✗✗ (Major redesign of evaluator)
**Philosophy alignment:** ✓ Low (significant semantic machinery)

---

## 5. Comparative Analysis

| Solution | Locality | Invasiveness | Manual Effort | Expressiveness | Philosophy Fit |
|----------|----------|--------------|---------------|----------------|----------------|
| **1. CPS** | ✓✓✓ | ✓✓✓ (none) | ✗ (very high) | ✓ (limited) | ✓✓✓ |
| **2. Value Wrappers** | ✓✓✓ | ✓✓ | ✓ (high) | ✓ | ✓✓ |
| **3. Strictness `!`** ⭐ | ✓✓✓ | ✓✓ | ✓✓✓ (low) | ✓✓✓ | ✓✓✓ |
| **4. Arity Decls** | ✗ | ✓ | ✓✓ | ✓✓ | ✓ |
| **5. Multi-Phase** | ✓✓ | ✓✓ | ✗ | ✓✓ | ✓✓ |
| **6. Polarity Sync** | ✓✓✓ | ✓✓ | ✓✓ | ✓✓ | ✓✓ |
| **7. Constraints** | ✗ | ✗ | ✓✓✓ | ✓✓✓ | ✓ |

**Legend:**
- ✓✓✓ = Excellent
- ✓✓ = Good
- ✓ = Acceptable
- ✗ = Poor

---

## 6. Recommendations

### 6.1 Short-Term: Experiment with CPS (Solution 1)

**Action:** Manually rewrite `examples/circuits.sg` using continuation-passing style to:
1. Validate that the approach works
2. Understand the verbosity cost
3. Identify common patterns that could be abstracted

**Why:** No language changes required, provides immediate feedback on the problem.

**Example rewrite:**

```stellogen
' Instead of:
[(-c2 X) (-c3 Y) (-and X Y R) (+c4 R)]

' Write:
[(-c2 X) (+left_and_0 X)]
[(-c3 Y) (+right_and_0 Y)]
[(-left_and_0 A) (-right_and_0 B) (-and A B R) (+c4 R)]
```

### 6.2 Medium-Term: Implement Strictness Annotations (Solution 3) ⭐

**Rationale:**
- **Best alignment** with Stellogen's philosophy: local, declarative, minimal
- **Solves the problem cleanly** without excessive verbosity
- **Extensible**: `!` can be applied to any sub-term, enabling fine-grained control
- **Teaches users** about data dependencies (makes implicit assumptions explicit)

**Implementation roadmap:**
1. Extend lexer to recognize `!` prefix (trivial)
2. Add `Strict of expr` to AST (`sgen_ast.ml`)
3. Update parser to handle `!` in patterns
4. Implement `is_ground : term -> bool` in `lsc_ast.ml`
5. Modify `raymatcher` to check groundness after unification
6. Add tests for strictness checking
7. Update documentation and examples

**Estimated effort:** Medium (2-3 days for experienced OCaml developer)

### 6.3 Long-Term: Consider Polarity Extension (Solution 6)

If strictness annotations prove insufficient or too verbose in practice, explore integrating groundness into the polarity system. This would be a more radical change but could provide a unified model for interaction control.

### 6.4 Not Recommended

- **Solution 4 (Arity Declarations)**: Too non-local, violates philosophy
- **Solution 7 (Constraints)**: Too complex, major semantic shift

---

## 7. Open Questions

### 7.1 Are There Other Domains with Similar Needs?

Where else does Stellogen encounter "wait for multiple inputs" patterns?
- **Dataflow networks**: Stream processing with joins
- **Concurrent systems**: Barrier synchronization, rendezvous
- **Pattern matching**: Matching multiple scrutinees simultaneously
- **Parallel reduction**: Combining results from multiple branches

### 7.2 Connection to Linear Logic

Linear logic distinguishes between:
- **Multiplicative conjunction** (⊗): "I have A **and** B simultaneously"
- **Additive conjunction** (&): "I offer A **or** B, your choice"

Could Stellogen's synchronization be framed as encoding multiplicative conjunction? Does the polarity system already partially encode linear logic, and could this be made explicit?

### 7.3 Relationship to Type Systems

Strictness annotations resemble **call-by-value** vs **call-by-name** distinctions in typed lambda calculi. Could this inform a more general "type system" for Stellogen where types are constraint sets on interaction?

Example:
```stellogen
(spec strict-and {
  [(-test X Y) (ground? X) (ground? Y) ok]
})

(:: semantics.and strict-and)  ' assert AND gate is strict
```

### 7.4 Performance Implications

Groundness checking on every unification could be expensive. Optimizations:
- **Caching**: Mark terms as ground/non-ground during construction
- **Lazy checking**: Only check strictness when necessary
- **Static analysis**: Infer which interactions need strictness checks

### 7.5 User Experience

How should errors be reported when strictness fails?
- "AND gate received non-ground input: Y is unbound"
- Should there be a debug mode showing which interactions are blocked?
- Can we provide suggestions ("Did you mean to add a splitter before this gate?")?

---

## 8. Concrete Examples

### 8.1 Original Circuit (Broken)

```stellogen
(:= semantics {
  [(+1 1)]
  [(+0 0)]
  [(+not 1 0)] [(+not 0 1)]
  [(+and 1 X X)] [(+and 0 X 0)]
})

<show interact (process
  [(-0 X) (+c0 X)]
  {[(-c0 X) (-not X R) (+c2 R)]
   [(-c0 X) (-not X R) (+c3 R)]}
  {(-c2 X) (-c3 Y) (-and X Y R) (+c4 R)}
  [(-c4 R) R]
  #semantics)>
```

**Problem:** When `c0` fires, it sends value `0` to both NOT gates. But the AND gate at layer 2 might fire before both `c2` and `c3` have values.

### 8.2 CPS Rewrite (Solution 1)

```stellogen
<show interact (process
  [(-0 X) (+c0 X)]

  ' Layer 1: Split and compute
  [(-c0 X) (+dup X X)]  ' explicit duplication
  [(-dup A B) (+wire_to_not_1 A) (+wire_to_not_2 B)]

  [(-wire_to_not_1 X) (-not X R) (+left_input R)]
  [(-wire_to_not_2 X) (-not X R) (+right_input R)]

  ' Layer 2: Synchronized AND
  [(-left_input A) (+left_ready A)]
  [(-right_input B) (+right_ready B)]
  [(-left_ready A) (-right_ready B) (-and A B R) (+c4 R)]

  [(-c4 R) R]
  #semantics)>
```

**Analysis:** Works, but verbose. Every gate needs explicit staging wires.

### 8.3 Strictness Annotation (Solution 3) ⭐

```stellogen
(:= semantics {
  [(+1 1)]
  [(+0 0)]
  [(+not !1 0)] [(+not !0 1)]     ' NOT requires ground input
  [(+and !1 !X X)] [(+and !0 !X 0)]  ' AND requires both inputs ground
})

' Original circuit (unchanged):
<show interact (process
  [(-0 X) (+c0 X)]
  {[(-c0 X) (-not X R) (+c2 R)]
   [(-c0 X) (-not X R) (+c3 R)]}
  {(-c2 X) (-c3 Y) (-and X Y R) (+c4 R)}
  [(-c4 R) R]
  #semantics)>
```

**Analysis:** Clean, declarative. Gate semantics explicitly state requirements. Circuit structure unchanged.

### 8.4 Polarity-Based (Solution 6)

```stellogen
' Introduce new polarity ~+ for "strict positive"
(:= semantics {
  [(~+and 1 X X)]    ' ~+ means "positive + must be ground"
  [(~+and 0 X 0)]
})

' Circuit uses normal negative polarity:
{(-c2 X) (-c3 Y) (-and X Y R) (+c4 R)}
```

**Analysis:** Reuses polarity mechanism, but semantics less clear (why is strictness a polarity?).

---

## 9. Conclusion

The synchronization problem in boolean circuits reveals a fundamental tension in Stellogen's design: purely local, eager unification is elegant and powerful, but some computational patterns require **coordinated readiness** across multiple inputs.

Among the solutions explored, **strictness annotations** (Solution 3) best balance:
- **Practicality**: Solves the problem without excessive verbosity
- **Philosophy**: Remains local and declarative, extending "connection checking" naturally
- **Simplicity**: Minimal language change, clear semantics

The path forward:
1. **Immediate**: Manually encode circuits using CPS to validate the problem
2. **Short-term**: Prototype strictness annotations and test on circuits
3. **Long-term**: Explore connections to type systems, linear logic, and performance optimization

This challenge, while specific to circuits, illuminates a broader question: **How do we maintain logic-agnosticism while supporting computational patterns that have inherent coordination requirements?** The answer likely lies not in choosing between "language does everything" and "user does everything," but in providing **minimal, composable primitives** that users can wield to encode their semantics—exactly Stellogen's core philosophy.

---

## References

- Stellogen repository: https://github.com/engboris/stellogen
- `examples/circuits.sg`: Boolean circuit encoding (broken)
- `src/lsc_ast.ml:96-97`: Ray matching implementation
- `src/unification.ml`: First-order unification algorithm
- `src/lsc_eval.ml`: Interaction and fusion semantics

**For further reading:**
- Girard's Transcendental Syntax
- Linear Logic and its applications
- Concurrent constraint programming
- Kahn process networks (dataflow with blocking reads)
