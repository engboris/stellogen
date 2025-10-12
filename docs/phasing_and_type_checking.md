# Phasing and Compile-Time Evaluation in Stellogen

> **Disclaimer**: This document was written with the assistance of Claude Code and represents exploratory research and analysis. The content may contain inaccuracies or misinterpretations and should not be taken as definitive statements about the Stellogen language implementation.

**Status:** Research Document
**Date:** 2025-10-12
**Purpose:** Analyze the problem of compile-time vs runtime evaluation in Stellogen, with applications to type checking, static analysis, and user-defined compile-time computations. Explore phasing systems in other languages and propose solutions that align with Stellogen's philosophy

---

## Table of Contents

1. [Introduction](#introduction)
2. [The Current State](#the-current-state)
3. [The Problem](#the-problem)
4. [Phasing in Other Languages](#phasing-in-other-languages)
5. [Dependency Challenges](#dependency-challenges)
6. [Proposed Solutions](#proposed-solutions)
7. [Recommendation](#recommendation)
8. [Implementation Outline](#implementation-outline)
9. [Conclusion](#conclusion)

---

## Introduction

### The Issue

In Stellogen, many operations that users expect to run at **compile-time** currently execute at **runtime**:

**Example 1: Type checking:**

```stellogen
(new-declaration (:: Tested Test)
  (== @(interact @#Tested #Test) ok))

(:= zero (+nat 0))
(:: zero nat)  ' Checked at runtime
```

**Example 2: Static analysis:**

```stellogen
' Check that all branches return
(new-declaration (check-exhaustive Cases)
  (== @(verify-coverage #Cases) ok))

(check-exhaustive my-function)  ' Verified at runtime
```

**Example 3: Compile-time constants:**

```stellogen
(:= table-size (interact #compute-optimal-size ...))
(show (generate-table #table-size))  ' Computed at runtime
```

**Problem:** Users typically want these computations to occur **before execution** in a separate phase:
- **Type checking**: Catch type errors early, before running the program
- **Static analysis**: Verify properties without executing code
- **Compile-time computation**: Pre-compute constants, generate code
- **User-defined checks**: Custom validations (exhaustiveness, termination, resource usage, etc.)

**Challenge:** These compile-time computations may depend on results from other compile-time computations, creating complex dependencies between phases.

### Broader Motivation

Beyond type checking, users might want to perform various **compile-time computations**:

1. **Static analysis**:
   - Exhaustiveness checking (all cases covered)
   - Termination checking (proofs that recursion terminates)
   - Resource usage analysis (memory, time bounds)
   - Linearity checking (each resource used exactly once)

2. **Code generation**:
   - Generate optimized versions of functions
   - Specialize generic code with constants
   - Compute lookup tables

3. **Validation**:
   - Check invariants
   - Verify contracts
   - Test generation

4. **Optimization**:
   - Constant folding
   - Dead code elimination
   - Fusion of constellations

5. **Metaprogramming**:
   - Reflection (inspect structure)
   - Code transformation
   - Custom linting

All of these share a common pattern: **run some computation before main execution, use the results to inform or validate the program**.

### Goal

Design a **general phasing system** for Stellogen that:
1. Separates compile-time evaluation from runtime execution
2. Supports arbitrary compile-time computations (not just type checking)
3. Handles dependencies between compile-time computations
4. Allows users to define their own compile-time analyses
5. Aligns with Stellogen's philosophy of explicit control and minimalism
6. Enables both static and dynamic checking

---

## The Current State

### Current Execution Pipeline

```
Source Code
    ↓
[Lexing & Parsing]
    ↓
AST (sgen_expr list)
    ↓
[Preprocessing]
    - Syntactic expansion (desugar)
    - Macro expansion (unfold_decl_def)
    ↓
Preprocessed AST
    ↓
[Conversion to Declarations]
    ↓
Program (declaration list)
    ↓
[Evaluation]
    - Build environment
    - Execute declarations
    - Perform interactions
    ↓
Final Environment + Results
```

**Key observation:** Type checking happens in the **Evaluation** phase, not before.

### How `::` Currently Works

**Definition** (`examples/nat.sg:1-3`):

```stellogen
(new-declaration (:: Tested Test)
  (== @(interact @#Tested #Test) ok))
```

**Usage:**

```stellogen
(:= zero (+nat 0))
(:: zero nat)
```

**Expansion** (during preprocessing):

```stellogen
(:= zero (+nat 0))
(== @(interact @#zero #nat) ok)
```

**Evaluation** (during runtime):

```
1. Define zero: env["zero"] = (+nat 0)
2. Execute: (== @(interact @#zero #nat) ok)
   a. Retrieve zero: @#zero → (+nat 0)
   b. Retrieve nat: #nat → { [(-nat 0) ok] [(-nat (s N)) (+nat N)] }
   c. Interact: (+nat 0) with [(-nat 0) ok] → ok
   d. Check equality: ok == ok → success
3. If check fails: error or continue (depends on ==)
```

### Current Limitations

1. **No early error detection**: Type errors only discovered when code runs
2. **No separation of concerns**: Type checking mixed with execution
3. **Performance overhead**: Every type check requires full interaction at runtime
4. **No static guarantees**: Can't verify program correctness before execution
5. **Hard to optimize**: Type information not available to compiler

---

## The Problem

### Problem 1: Users Want Compile-Time Type Checking

**Expectation** (from most typed languages):

```stellogen
(:= zero (+nat 0))
(:: zero nat)              ' Check at compile-time

(:= add-numbers ...)
(show (interact #add-numbers ...))  ' Run at execution-time
```

**Desired behavior:**
- Type checks (`::`) should run **before** main execution
- Errors should be caught **early**
- Main execution shouldn't waste time on type checking

### Problem 2: Some Type Checks Depend on Runtime Values

**Simple case** (can check statically):

```stellogen
(:= zero (+nat 0))
(:: zero nat)              ' Can check without running anything
```

**Complex case** (needs runtime values):

```stellogen
(:= compute-number (interact #some-computation ...))
(:: compute-number nat)    ' Depends on result of computation!
```

How can we check the type of `compute-number` before running `some-computation`?

### Problem 3: Dependencies Between Checks

**Example:**

```stellogen
(:= base (+nat 0))
(:: base nat)                           ' Check 1

(:= incremented (interact #add1 @#base))
(:: incremented nat)                    ' Check 2 (depends on Check 1)

(:= doubled (interact #double @#incremented))
(:: doubled nat)                        ' Check 3 (depends on Check 2)
```

Checks form a **dependency graph**. What order should they execute in?

### Problem 4: Mutual Dependencies

**Example:**

```stellogen
(:= even {
  [(-even 0) ok]
  [(-even (s N)) (+odd N)]})

(:= odd {
  [(-odd (s N)) (+even N)]})

(:: even-checker even)     ' Depends on odd
(:: odd-checker odd)       ' Depends on even
```

Type definitions are mutually recursive. How do we handle this?

### Problem 5: User-Defined Phases

Users might want **multiple phases** beyond just "type check" and "execute":

```stellogen
@compile-time
(:= type-level-computation ...)

@type-check-time
(:: value type)

@link-time
(:= connect-modules ...)

@run-time
(show (interact ...))
```

How general should the phasing system be?

---

## Phasing in Other Languages

To understand solutions, let's examine how other languages handle compile-time vs runtime separation.

### Racket's Phase System

**Racket** has the most sophisticated phase system, with **phase levels**:

- **Phase 0**: Runtime (normal execution)
- **Phase 1**: Compile-time (macro expansion)
- **Phase 2**: Compile-compile-time (macros for macros)
- etc.

**Syntax:**

```racket
#lang racket

; Define a compile-time helper
(begin-for-syntax
  (define (helper x) (+ x 1)))

; Use it in a macro
(define-syntax (my-macro stx)
  (syntax-case stx ()
    [(my-macro n)
     #`(+ #,(helper (syntax->datum #'n)) 10)]))

(my-macro 5)  ; Expands to (+ 6 10) → 16
```

**Key features:**

1. **Explicit phase imports**:
   ```racket
   (require (for-syntax racket/base))    ; Import for phase 1
   (require (for-meta 2 racket/base))    ; Import for phase 2
   ```

2. **Automatic phasing**: Racket automatically runs phase 1 code before phase 0

3. **Phase separation**: Variables at different phases are distinct

**How it works:**

```
Compile-time (Phase 1):
- Load modules required for-syntax
- Expand macros
- Run compile-time computations

Runtime (Phase 0):
- Load modules required normally
- Execute expanded code
```

**Relevance to Stellogen:** Could have separate "type-checking phase" and "execution phase"

### Lisp's `eval-when`

**Common Lisp** has `eval-when` to control **when** code executes:

```lisp
(eval-when (:compile-toplevel :load-toplevel :execute)
  (defun compile-time-helper (x) (+ x 1)))

; Available during compilation, loading, and execution
```

**Three contexts:**
- `:compile-toplevel` - When file is compiled
- `:load-toplevel` - When compiled file is loaded
- `:execute` - During normal execution

**Relevance to Stellogen:** Could have annotations like `@compile-time`, `@type-check-time`, `@run-time`

### MetaML and Staging

**MetaML** provides **multi-stage programming** with explicit staging annotations:

```ocaml
(* Stage 0: Generate code *)
let power n =
  <fun x -> ~(power_body n <x>)>

(* Stage 1: Use generated code *)
let pow3 = .< ~(power 3) >.
```

**Brackets and escapes:**
- `<...>` - Code bracket (next stage)
- `~...` - Escape (previous stage)
- `.< ... >.` - Run code now

**Relevance to Stellogen:** Could have explicit staging for type checking vs execution

### Dependent Type Systems (Coq, Agda, Idris)

**Dependent types** blur the line between types and values—types can depend on runtime values.

**Coq example:**

```coq
(* Type depends on value n *)
Definition vector (A : Type) (n : nat) : Type :=
  { l : list A | length l = n }.

(* Type checking requires computing n *)
Definition three_elements : vector nat 3 :=
  exist _ [1; 2; 3] eq_refl.
```

**Key insight:** Type checking may require **evaluation** of terms to normal form.

**Phases in dependent types:**

```
Type Checking Phase:
1. Normalize terms to compute types
2. Check type equality (may require more normalization)
3. Verify constraints

Execution Phase:
1. Erase types (type information no longer needed)
2. Execute code
```

**Relevance to Stellogen:** Type checking may require running some constellations to compute types

### Haskell's Template Haskell

**Template Haskell** provides **compile-time metaprogramming**:

```haskell
-- Compile-time function
generateTuple :: Int -> Q Exp
generateTuple n = ...

-- Splice: run at compile-time
myTuple = $(generateTuple 5)
```

**Splicing with `$(...)`:**
- Marks expression to run at compile-time
- Result is spliced into the code

**Relevance to Stellogen:** Could have "run at type-check time" annotations

### TypeScript's Structural Type System

**TypeScript** performs type checking entirely **before execution**:

```typescript
interface Point { x: number; y: number; }

const p: Point = { x: 10, y: 20 };  // Checked at compile-time
console.log(p.x);                    // Types erased at runtime
```

**Two-phase approach:**

```
Type Checking Phase:
- Parse TypeScript code
- Build type information
- Check types
- Report errors

Execution Phase:
- Erase types
- Generate JavaScript
- Run JavaScript (no types)
```

**Relevance to Stellogen:** Could separate type checking into a separate phase before evaluation

### Comparison Summary

| Language | Phase Separation | Type Checking | Runtime Dependency |
|----------|------------------|---------------|-------------------|
| **Racket** | Multi-level phases | N/A (dynamically typed) | No |
| **Common Lisp** | eval-when contexts | N/A (dynamically typed) | No |
| **MetaML** | Explicit staging | Separate | No |
| **Coq/Agda** | Type checking phase + execution | Separate but requires evaluation | Yes |
| **Template Haskell** | Compile-time splicing | Separate | Partially |
| **TypeScript** | Type checking + execution | Separate | No |

**Key insight:** Most systems either:
1. Separate phases completely (TypeScript, MetaML) - **no runtime dependency**
2. Allow type checking to evaluate terms (Coq, Agda) - **runtime dependency handled**

---

## Dependency Challenges

### Challenge 1: Type Checks That Need Runtime Values

**Example:**

```stellogen
(:= computed (interact #complex-computation ...))
(:: computed nat)
```

**Question:** How can we check `computed : nat` before running `complex-computation`?

**Options:**

1. **Infer the type** of `complex-computation` without running it
   - Requires type inference system
   - May be undecidable for Stellogen's model

2. **Run computation in type-checking phase**
   - Blurs phases
   - But allows checking

3. **Require explicit annotation**
   ```stellogen
   (:= computed @type:(nat) (interact #complex-computation ...))
   ```
   - Type is promised, checked at runtime if needed

4. **Separate static and dynamic checks**
   ```stellogen
   (:: computed nat @dynamic)  ; Checked at runtime
   ```

### Challenge 2: Dependency Ordering

**Example:**

```stellogen
(:= a (+nat 0))
(:= b (interact #add1 @#a))
(:= c (interact #double @#b))

(:: a nat)
(:: b nat)
(:: c nat)
```

**Dependency graph:**

```
a
  ↓
  b
  ↓
  c
```

**Topological sort:**
1. Check `a : nat`
2. Check `b : nat` (requires `a`)
3. Check `c : nat` (requires `b`)

**Implementation:** Build dependency graph, sort topologically, check in order.

### Challenge 3: Mutual Dependencies

**Example:**

```stellogen
(:= even {
  [(-even 0) ok]
  [(-even (s N)) (+odd N)]})

(:= odd {
  [(-odd (s N)) (+even N)]})

(:: even-checker even)
(:: odd-checker odd)
```

**Dependency graph:**

```
even ←→ odd
```

**Cycle!** Can't sort topologically.

**Solutions:**

1. **Check simultaneously** (fixed-point approach)
2. **Require explicit order** (user breaks cycle)
3. **Allow forward references** (assume types, verify later)

### Challenge 4: Non-Terminating Type Checks

**Example:**

```stellogen
(:= infinite-loop {
  [(-loop X) (+loop X)]})

(:: infinite-loop ???)
```

If type checking requires evaluation, and evaluation doesn't terminate, type checking hangs.

**Solutions:**

1. **Timeout** on type checks
2. **Detect loops** (cycle detection)
3. **Require termination proofs** (very formal)
4. **Accept the risk** (user's responsibility)

---

## Proposed Solutions

### Solution 1: Two-Phase Execution (Simple)

**Idea:** Add a "compile-time phase" before "execution phase", with minimal changes.

**Implementation:**

```ocaml
(* New pipeline *)
Source Code
    ↓
[Parsing & Preprocessing]
    ↓
Program
    ↓
[Phase 1: Compile-Time]
    - Execute declarations marked @compile-time
    - Execute type checks, static analysis, etc.
    - Build compile-time environment
    ↓
Compile-Time Environment + Results
    ↓
[Phase 2: Runtime]
    - Execute remaining declarations
    - Use compile-time results (optional)
    ↓
Final Results
```

**Syntax:**

```stellogen
' Definitions (phase 0)
(:= nat { ... })

' Compile-time computations (phase 1)
@compile-time
(:= zero (+nat 0))
(:: zero nat)

' Static analysis
@compile-time
(check-exhaustive my-function)

' Execution (phase 2)
@runtime
(show (interact #zero ...))
```

**Pros:**
- Simple to understand
- Clear separation
- Easy to implement
- Generalizes to any compile-time computation

**Cons:**
- Requires explicit annotations
- Doesn't handle dependencies automatically
- What if compile-time code needs to run a computation?

**Alignment with philosophy:** ✓ Good (explicit control, minimal)

### Solution 2: Automatic Dependency Tracking

**Idea:** Automatically determine execution order based on dependencies.

**Algorithm:**

```
1. Parse all declarations
2. Build dependency graph:
   - Each :: declaration depends on the values it references
3. Topological sort
4. Execute in sorted order
```

**Example:**

```stellogen
(:= zero (+nat 0))
(:: zero nat)              ' Depends on zero

(:= one (interact #add1 @#zero))
(:: one nat)               ' Depends on one, add1, zero

(show (interact #one ...))  ' Depends on one
```

**Dependency analysis:**

```
Nodes:
- zero (definition)
- nat (definition)
- zero-check (:: zero nat)
- add1 (definition)
- one (definition)
- one-check (:: one nat)
- show-form (execution)

Edges:
- zero-check → zero, nat
- one → add1, zero
- one-check → one, nat
- show-form → one

Topological order:
1. zero, nat, add1
2. zero-check
3. one
4. one-check
5. show-form
```

**Pros:**
- Automatic (no annotations needed)
- Handles dependencies correctly
- Executes type checks as early as possible

**Cons:**
- Complex to implement
- Requires sophisticated dependency analysis
- What about cycles?

**Alignment with philosophy:** ⚠️ Moderate (implicit ordering, but automatic)

### Solution 3: Explicit Phase Annotations

**Idea:** Let users explicitly mark which phase each declaration belongs to.

**Syntax:**

```stellogen
@phase(0)  ' Definitions phase
(:= nat { ... })

@phase(1)  ' Compile-time phase
(:= zero (+nat 0))
(:: zero nat)
(check-linearity my-function)

@phase(2)  ' Execution phase
(show (interact #zero ...))
```

Or with named phases:

```stellogen
@define
(:= nat { ... })

@compile-time
(:= zero (+nat 0))
(:: zero nat)
(analyze-coverage my-cases)

@runtime
(show (interact #zero ...))
```

Or user-defined phases:

```stellogen
@phase:definitions
(:= nat { ... })

@phase:type-check
(:: zero nat)

@phase:static-analysis
(check-termination factorial)
(verify-resource-bounds server)

@phase:optimize
(inline small-functions)
(fuse-constellations)

@phase:execute
(show (interact ...))
```

**Semantics:**

```
Execute all @phase(0) declarations first
Then execute all @phase(1) declarations
Then execute all @phase(2) declarations
...

Or with named phases:
Execute @phase:definitions
Then execute @phase:type-check
Then execute @phase:static-analysis
etc.
```

**Pros:**
- Explicit user control
- Flexible (arbitrary phases)
- Aligns with Stellogen's explicit philosophy
- Users can define custom phases for custom analyses

**Cons:**
- Verbose (annotations everywhere)
- User must manage dependencies manually
- Easy to get wrong

**Alignment with philosophy:** ✓ Excellent (explicit, user-controlled)

### Solution 4: Type Checking as a Separate Interaction Mode

**Idea:** Treat type checking as a special kind of interaction that runs in its own environment.

**Syntax:**

```stellogen
' Normal definition
(:= zero (+nat 0))

' Type check in separate environment
(typecheck
  (:: zero nat)
  (:: one nat)
  ...)

' Main execution
(show (interact #zero ...))
```

**Semantics:**

```
1. Execute definitions → env
2. Execute (typecheck ...) block:
   - Create separate type-checking environment
   - Run all :: forms
   - Collect results (pass/fail)
   - Don't modify main environment
3. If all type checks pass:
   - Continue to main execution
4. If any type check fails:
   - Report error, halt
```

**Pros:**
- Clear boundary between phases
- Doesn't modify main environment
- Can run all type checks together

**Cons:**
- Still doesn't handle dependencies within type checks
- Requires explicit block

**Alignment with philosophy:** ✓ Good (explicit, block-structured)

### Solution 5: Lazy Type Checking with Memoization

**Idea:** Type checks are evaluated lazily when needed, with results memoized.

**Syntax:**

```stellogen
(:= zero (+nat 0))
(:: zero nat @lazy)        ' Checked when zero is first used

(:= one (interact #add1 @#zero))  ' Triggers check of zero
(:: one nat @lazy)

(show @#one)               ' Triggers check of one (and transitively zero)
```

**Semantics:**

```
1. Parse all declarations
2. Mark type checks as "pending"
3. When a value is used (via @):
   a. Check if it has a pending type check
   b. If yes, run the type check now
   c. Memoize result
   d. Proceed with usage
4. At end of program:
   - Run all remaining pending checks
```

**Pros:**
- Automatic dependency handling
- Type checks run at the right time
- No explicit ordering needed

**Cons:**
- Non-obvious when checks happen
- Debugging is harder
- Doesn't catch errors early (lazy)

**Alignment with philosophy:** ⚠️ Moderate (implicit, but lazy fits evaluation model)

### Solution 6: Multi-Pass with Declarations

**Idea:** Users declare dependencies explicitly, and the system makes multiple passes.

**Syntax:**

```stellogen
(declare-phase type-checking)
(declare-phase execution)

' Definitions (always run first)
(:= nat { ... })
(:= zero (+nat 0))

' Type checking phase
(in-phase type-checking
  (:: zero nat)
  (:: one nat))

' Execution phase
(in-phase execution
  (show (interact ...)))
```

**Semantics:**

```
Pass 1: Execute all top-level definitions
Pass 2: Execute (in-phase type-checking ...) blocks
Pass 3: Execute (in-phase execution ...) blocks
```

**Pros:**
- Explicit phases
- Clear structure
- User controls what runs when

**Cons:**
- Verbose
- Doesn't handle cross-phase dependencies

**Alignment with philosophy:** ✓ Good (explicit, user-controlled)

### Solution 7: Gradual Phasing with `@stage` Annotations

**Idea:** Inspired by MetaML, use `@stage(n)` annotations to mark evaluation stage.

**Syntax:**

```stellogen
' Stage 0: Definitions (always run first)
(:= nat { ... })

' Stage 1: Type checking
@stage(1) (:= zero (+nat 0))
@stage(1) (:: zero nat)

' Stage 2: Main execution
@stage(2) (show (interact #zero ...))

' Or more explicit:
(:= zero @stage(1) (+nat 0))
(:: zero nat @stage(1))
```

**Semantics:**

```
1. Collect all declarations by stage
2. Execute stage 0 (or unmarked)
3. Execute stage 1
4. Execute stage 2
...
```

**Pros:**
- Flexible (arbitrary stages)
- Explicit
- Familiar from staging literature

**Cons:**
- Annotations clutter code
- Need to manually manage stages

**Alignment with philosophy:** ✓ Good (explicit staging)

### Solution 8: User-Defined Phases (Maximum Flexibility)

**Idea:** Let users define their own phases with custom semantics.

**Syntax:**

```stellogen
' Declare custom phases
(declare-phase analyze
  :after definitions
  :before runtime
  :dependencies-within auto)

(declare-phase optimize
  :after analyze
  :before runtime
  :dependencies-within manual)

' Use custom phases
@phase:definitions
(:= nat { ... })
(:= factorial { ... })

@phase:analyze
(check-termination #factorial)
(verify-totality #factorial)

@phase:optimize
(inline-small-functions)
(specialize-with-constants)

@phase:runtime
(show (factorial 10))
```

**Semantics:**

- Phases execute in declared order
- Within each phase, dependency handling is configurable (auto vs manual)
- Phases can access results from previous phases

**Advanced: Phase-local environments:**

```stellogen
' Definitions available to all phases
@phase:definitions
(:= nat { ... })

' Analysis results available to optimization
@phase:analyze
(:= termination-proof (prove-termination #factorial))

' Optimization can use analysis results
@phase:optimize
(if #termination-proof
  (aggressive-inline #factorial)
  (conservative-inline #factorial))
```

**Pros:**
- Maximum flexibility
- Users define their own compile-time passes
- Supports arbitrary static analyses
- Can build complex compilation pipelines

**Cons:**
- Most complex to implement
- Users must understand phase system deeply
- Easy to create confusing phase interactions

**Alignment with philosophy:** ✓ Excellent (ultimate user control, extensible)

---

## Generalizing Beyond Type Checking

While the primary motivation is type checking, the phasing system should support **any compile-time computation**. This section explores various use cases.

### Use Case 1: Static Analysis

**Exhaustiveness checking:**

```stellogen
' Check that pattern matching covers all cases
(new-declaration (check-exhaustive Fn Cases)
  (== @(verify-all-cases-covered #Fn #Cases) ok))

@compile-time
(check-exhaustive classify {
  case-neg
  case-zero
  case-pos})
```

**Termination checking:**

```stellogen
' Prove that recursion terminates
(new-declaration (check-terminates Fn)
  (== @(find-termination-measure #Fn) ok))

@compile-time
(check-terminates factorial)
(check-terminates ackermann @allow-fail)  ' Known non-primitive recursive
```

**Linearity checking:**

```stellogen
' Verify that each resource is used exactly once
(new-declaration (check-linear Fn)
  (== @(verify-linear-usage #Fn) ok))

@compile-time
(check-linear file-operations)
(check-linear socket-handler)
```

### Use Case 2: Compile-Time Computation

**Constant folding:**

```stellogen
' Compute constants at compile-time
@compile-time
(:= table-size (interact #compute-optimal-size #input-parameters))

' Use computed constant at runtime
@runtime
(:= lookup-table (generate-table #table-size))
```

**Code specialization:**

```stellogen
' Specialize generic function with known arguments
@compile-time
(:= power-of-3 (specialize #power 3))

' Use specialized version at runtime
@runtime
(show (interact #power-of-3 27))  ' Much faster than general power
```

**Lookup table generation:**

```stellogen
' Generate lookup table at compile-time
@compile-time
(:= sin-table (generate-lookup-table
  #sin
  :range [0 (/ pi 2)]
  :precision 0.001))

' Use table at runtime
@runtime
(:= fast-sin [(-sin X) (+lookup-table-get #sin-table X)])
```

### Use Case 3: Metaprogramming

**Reflection and inspection:**

```stellogen
' Inspect structure of constellations at compile-time
@compile-time
(:= nat-structure (reflect-on #nat))
(show "Nat has" (count-stars #nat-structure) "stars")
```

**Code generation:**

```stellogen
' Generate boilerplate from specification
@compile-time
(:= person-record (generate-record
  [name string]
  [age nat]
  [email string]))

' Use generated code at runtime
@runtime
(:= john (make-person "John" 30 "john@example.com"))
```

**Derive functionality:**

```stellogen
' Automatically derive functionality (like Haskell's deriving)
@compile-time
(derive-for nat [show eq ord])

' Use derived instances at runtime
@runtime
(show #zero)                    ' Uses derived show
(:: (eq #zero #one) bool)       ' Uses derived eq
(:: (compare #one #zero) ordering)  ' Uses derived ord
```

### Use Case 4: User-Defined Linting

**Custom lint rules:**

```stellogen
' Define custom lint rules
@compile-time
(lint-rule unused-definitions
  :check (find-unused-defs)
  :level warning)

(lint-rule large-constellations
  :check (find-constellations-with-many-stars :threshold 50)
  :level info)

(lint-rule naming-conventions
  :check (verify-naming-conventions)
  :level warning)

' Run lints
(run-all-lints)
```

**Code metrics:**

```stellogen
@compile-time
(compute-metrics my-module
  :metrics [complexity depth fan-out])

(enforce-metric-bounds
  :max-complexity 10
  :max-depth 5
  :max-fan-out 20)
```

### Use Case 5: Testing and Verification

**Property testing:**

```stellogen
' Define properties at compile-time
@compile-time
(define-property add-commutative
  (forall [X Y]
    (== (add X Y) (add Y X))))

(define-property add-associative
  (forall [X Y Z]
    (== (add X (add Y Z)) (add (add X Y) Z))))

' Check properties (via QuickCheck-style testing)
(check-properties #add [add-commutative add-associative]
  :num-tests 1000)
```

**Proof verification:**

```stellogen
' Verify proofs at compile-time
@compile-time
(verify-proof add-commutative-proof
  :statement (forall [X Y] (== (add X Y) (add Y X)))
  :method induction-on X)
```

### Use Case 6: Resource Analysis

**Memory usage analysis:**

```stellogen
@compile-time
(analyze-memory-usage server-handler
  :max-heap 1GB
  :max-stack 10MB)

(analyze-allocation-rate compute-intensive
  :max-rate 100MB/s)
```

**Time complexity analysis:**

```stellogen
@compile-time
(analyze-complexity factorial
  :expected O(n)
  :method static-analysis)

(analyze-complexity merge-sort
  :expected O(n*log(n)))
```

### Use Case 7: Optimization Passes

**Inline small functions:**

```stellogen
@compile-time
(optimize-inline
  :max-size 10
  :targets [add1 is-zero small-helper])
```

**Fusion of constellations:**

```stellogen
@compile-time
(fuse-constellations
  :pipeline [#step1 #step2 #step3]
  :result merged-pipeline)
```

**Dead code elimination:**

```stellogen
@compile-time
(eliminate-dead-code
  :entry-points [main server-start]
  :report unused-definitions)
```

### Common Pattern: Compile-Time Computation → Runtime Usage

All these use cases follow a pattern:

```
@compile-time
1. Analyze/compute something
2. Generate results/code/proofs
3. Store in environment

@runtime
4. Use compile-time results
5. Benefit from pre-computation/verification
```

**Example:**

```stellogen
' Compile-time: Verify termination
@compile-time
(:= fib-terminates (prove-termination #fibonacci))

' Compile-time: Optimize based on proof
@compile-time
(if #fib-terminates
  (:= fib-optimized (aggressive-optimize #fibonacci))
  (:= fib-optimized #fibonacci))

' Runtime: Use optimized version
@runtime
(show (interact #fib-optimized 40))
```

### Enabling User-Defined Analyses

The phasing system should allow users to define **their own compile-time analyses**:

**Framework for user-defined analysis:**

```stellogen
' Define a new analysis
(new-declaration (my-analysis Subject)
  @compile-time
  (:= result (run-my-analysis-logic #Subject))
  (report-results #result))

' Use the analysis
@compile-time
(my-analysis my-function)
```

**Example: Custom exhaustiveness checker:**

```stellogen
' Define exhaustiveness checker
(new-declaration (check-cases Fn AllCases)
  @compile-time
  (let
    ([defined-cases (extract-cases #Fn)]
     [missing-cases (set-difference #AllCases #defined-cases)])
    (if (empty? #missing-cases)
      ok
      (error "Missing cases:" #missing-cases))))

' Use it
@compile-time
(check-cases classify [negative zero positive])
```

**Example: Custom resource analyzer:**

```stellogen
' Define resource analyzer
(new-declaration (analyze-resources Fn MaxHeap MaxStack)
  @compile-time
  (let
    ([heap-usage (estimate-heap-usage #Fn)]
     [stack-usage (estimate-stack-usage #Fn)])
    (and
      (assert (<= #heap-usage #MaxHeap) "Heap overflow")
      (assert (<= #stack-usage #MaxStack) "Stack overflow"))))

' Use it
@compile-time
(analyze-resources server-handler 1GB 10MB)
```

### Compile-Time Constellation Library

Users could build a **standard library of compile-time tools**:

```stellogen
' lib/compile-time.sg

''' Type checking '''
(new-declaration (:: Tested Test) ...)

''' Static analysis '''
(new-declaration (check-exhaustive Fn Cases) ...)
(new-declaration (check-terminates Fn) ...)
(new-declaration (check-linear Fn) ...)

''' Optimization '''
(new-declaration (inline Fn) ...)
(new-declaration (specialize Fn Args) ...)
(new-declaration (fuse Pipeline) ...)

''' Code generation '''
(new-declaration (generate-record Fields) ...)
(new-declaration (derive-for Type Traits) ...)

''' Linting '''
(new-declaration (lint-rule Name Check) ...)
(new-declaration (run-all-lints) ...)
```

Usage:

```stellogen
(import-macros "lib/compile-time.sg")

@compile-time
(:: zero nat)
(check-terminates factorial)
(inline small-helper)
(derive-for person [show eq])
(run-all-lints)

@runtime
(show ...)
```

---

## Recommendation

### Recommended Approach: Hybrid Multi-Phase System with User-Defined Phases

Combine the best aspects of several solutions:

1. **Default behavior**: Everything runs in one phase (backward compatible)
2. **Explicit phase blocks**: Users can opt into multi-phase execution
3. **Automatic dependency tracking**: Within a phase, dependencies are handled automatically
4. **Pre-defined phases**: Common phases with clear semantics (compile-time, runtime)
5. **User-defined phases**: Users can define custom phases for custom analyses

### Concrete Design

#### Phase Definitions

**Pre-defined phases:**

```
Phase 0: Definitions (implicit)
- All top-level (:= ...) declarations
- All (spec ...) type definitions
- All macro definitions
- No annotations needed
- Always runs first

Phase 1: Compile-Time (explicit)
- Type checking: (:: ...) forms
- Static analysis: (check-...) forms
- Optimization: (inline ...), (specialize ...) forms
- Code generation: (generate-...) forms
- Any user-defined compile-time computation
- Declarations in @compile-time blocks
- Automatically includes dependencies from Phase 0

Phase 2: Runtime (explicit or implicit)
- Main program execution
- Declarations in @runtime blocks
- Everything not in other phases
- Can reference results from compile-time phase
```

**User-defined phases (optional):**

```stellogen
' Users can define custom phases between compile-time and runtime
(declare-phase type-check :after definitions :before runtime)
(declare-phase static-analysis :after type-check :before runtime)
(declare-phase optimize :after static-analysis :before runtime)

' Or use pre-defined compile-time phase with ordering
@compile-time:type-check { ... }
@compile-time:analyze { ... }
@compile-time:optimize { ... }
```

#### Syntax Options

**Option 1: Simple two-phase (recommended for most users):**

```stellogen
' Phase 0 (implicit): Definitions
(:= nat {
  [(-nat 0) ok]
  [(-nat (s N)) (+nat N)]})

(:= add1 [(-nat X) (+nat (s X))])

' Phase 1: Compile-time
@compile-time {
  (:= zero (+nat 0))
  (:: zero nat)

  (:= one (+nat (s 0)))
  (:: one nat)

  (check-terminates factorial)
  (inline small-helper)
}

' Phase 2: Runtime (implicit)
(show (interact #add1 @#zero))
(show (interact #add1 @#one))
```

**Option 2: Multi-phase (for advanced users):**

```stellogen
' Phase 0: Definitions
(:= nat { ... })
(:= factorial { ... })

' Phase 1a: Type checking
@phase:type-check {
  (:: zero nat)
  (:: factorial (fn nat nat))
}

' Phase 1b: Static analysis
@phase:analyze {
  (check-terminates factorial)
  (verify-totality factorial)
}

' Phase 1c: Optimization
@phase:optimize {
  (inline-small-functions)
  (specialize factorial 10)
}

' Phase 2: Runtime
@runtime {
  (show (factorial 10))
}
```

**Option 3: Inline annotations (concise):**

```stellogen
' Definitions
(:= nat { ... })

' Compile-time declarations
(:= zero @compile-time (+nat 0))
(:: zero nat @compile-time)

' Runtime
(show @runtime (interact #add1 @#zero))
```

#### Semantics

**Basic two-phase model:**

```
1. Collect all declarations
2. Group by phase:
   - Phase 0: All top-level definitions not in other phases
   - Phase 1: Contents of @compile-time blocks
   - Phase 2: Contents of @runtime blocks, or unmarked
3. Execute Phase 0 (definitions)
   - No dependency analysis needed (just definitions)
   - Build definition environment
4. Execute Phase 1 (compile-time)
   - Within phase, analyze dependencies
   - Topologically sort
   - Execute in order
   - Store results in compile-time environment
5. Execute Phase 2 (runtime)
   - Same dependency handling
   - Can access both definition and compile-time environments
   - Produce final results
```

**Advanced multi-phase model:**

```
1. Collect all declarations
2. Identify all phases:
   - Phase 0: Definitions (implicit)
   - Phase 1.1: @phase:type-check
   - Phase 1.2: @phase:analyze
   - Phase 1.3: @phase:optimize
   - Phase 2: Runtime (implicit)
3. For each phase in order:
   a. Collect declarations for this phase
   b. Analyze dependencies within phase
   c. Topologically sort
   d. Execute in order
   e. Make results available to subsequent phases
4. Between phases:
   - Phase can access results from previous phases
   - Phase cannot modify previous phases' results
   - Phase can produce new bindings for future phases
```

**Environment propagation:**

```
Phase 0 produces: definition_env
Phase 1 produces: compile_time_env
Phase 2 produces: runtime_env

Available to each phase:
- Phase 0: {} (empty)
- Phase 1: definition_env
- Phase 2: definition_env ∪ compile_time_env

Example:
Phase 0:
  (:= nat { ... })
  → definition_env = {nat: ...}

Phase 1:
  (:: zero nat)
  → compile_time_env = {zero_type_check: ok}

  (check-terminates factorial)
  → compile_time_env = {..., factorial_terminates: proof}

  (inline small-helper)
  → compile_time_env = {..., inlined_code: ...}

Phase 2:
  (show ...)
  → Can access nat, zero_type_check, factorial_terminates, inlined_code
```

#### Handling Dependencies Across Phases

**Example 1: Type checking:**

```stellogen
' Phase 0
(:= nat { ... })

' Phase 1: Compile-time
@compile-time {
  (:= zero (+nat 0))
  (:: zero nat)              ' Depends on nat (Phase 0) and zero (Phase 1)

  (:= one (+nat (s 0)))
  (:: one nat @depends-on(zero))  ' Explicit dependency on zero's type check
}
```

**Dependency analysis:**

```
Within Phase 1:
- (:= zero ...) → depends on nothing (nat is Phase 0)
- (:: zero nat) → depends on (:= zero ...) and nat
- (:= one ...) → depends on nothing
- (:: one nat @depends-on(zero)) → depends on (:= one ...), nat, (:: zero nat)

Execution order:
1. (:= zero ...)
2. (:: zero nat)
3. (:= one ...)
4. (:: one nat)
```

**Example 2: Mixed compile-time computations:**

```stellogen
' Phase 0
(:= factorial { ... })
(:= power { ... })

' Phase 1: Compile-time
@compile-time {
  ' Type checking
  (:: factorial (fn nat nat))

  ' Static analysis (depends on type check)
  (check-terminates factorial)

  ' Optimization (depends on analysis)
  (:= factorial-optimized
    (optimize-with-proof #factorial #factorial_terminates))

  ' Code generation (depends on optimization)
  (:= power-of-3 (specialize #power 3))
}

' Phase 2: Runtime
@runtime {
  (show (interact #factorial-optimized 10))
  (show (interact #power-of-3 27))
}
```

**Dependency graph:**

```
Phase 1:
  (:: factorial ...) → depends on factorial
  (check-terminates factorial) → depends on (:: factorial ...)
  (:= factorial-optimized ...) → depends on (check-terminates factorial)
  (:= power-of-3 ...) → depends on power

Order: type-check → analysis → optimization → code-gen
```

#### Handling Cycles

**Example:**

```stellogen
@typecheck {
  (:= even { [(-even 0) ok] [(-even (s N)) (+odd N)] })
  (:= odd { [(-odd (s N)) (+even N)] })

  (:: even-checker even)
  (:: odd-checker odd)
}
```

**Cycle:** `even-checker` needs `odd`, `odd-checker` needs `even`.

**Solution:** Group mutually-dependent declarations:

```stellogen
@typecheck {
  ' Mutual group
  @mutual {
    (:= even { [(-even 0) ok] [(-even (s N)) (+odd N)] })
    (:= odd { [(-odd (s N)) (+even N)] })
  }

  ' Then check both
  (:: even-checker even)
  (:: odd-checker odd)
}
```

Or automatically detect cycles and check simultaneously:

```
Algorithm:
1. Build dependency graph
2. Find strongly connected components (SCCs)
3. Each SCC is a mutual dependency group
4. Execute groups in topological order
```

---

## Implementation Outline

### Phase 1: Core Infrastructure

**Add phase tracking to AST:**

```ocaml
(* src/sgen_ast.ml *)
type phase =
  | Definition    (* Phase 0 *)
  | TypeCheck     (* Phase 1 *)
  | Execute       (* Phase 2 *)

type declaration =
  | Def of ident * sgen_expr * phase
  | TypeCheck of sgen_expr
  | Show of sgen_expr * phase
  | (* existing variants *)
```

**Parse phase annotations:**

```ocaml
(* src/sgen_parsing.ml *)
(* Parse @typecheck { ... } *)
| List [Symbol "type-check"; body] ->
    parse_phase_block TypeCheck body

(* Parse (type-check ...) *)
| List (Symbol "type-check" :: decls) ->
    parse_phase_decls TypeCheck decls
```

**Group declarations by phase:**

```ocaml
(* src/sgen_eval.ml *)
let group_by_phase program : (phase * declaration list) list =
  let groups = Hashtbl.create 3 in
  List.iter program ~f:(fun decl ->
    let p = get_phase decl in
    Hashtbl.add_multi groups p decl);
  Hashtbl.to_alist groups
```

### Phase 2: Dependency Analysis

**Build dependency graph:**

```ocaml
(* src/dependency.ml *)
type dep_node = {
  id: string;
  decl: declaration;
  deps: string list;  (* identifiers this depends on *)
}

let collect_dependencies (decl : declaration) : string list =
  (* Walk AST, collect all #ident references *)
  ...

let build_dep_graph (decls : declaration list) : dep_node list =
  List.map decls ~f:(fun decl ->
    { id = get_id decl;
      decl = decl;
      deps = collect_dependencies decl })
```

**Topological sort:**

```ocaml
let topological_sort (nodes : dep_node list) : dep_node list =
  (* Standard Kahn's algorithm or DFS-based *)
  ...

let detect_cycles (nodes : dep_node list) : dep_node list list =
  (* Find strongly connected components (Tarjan's algorithm) *)
  ...
```

### Phase 3: Multi-Phase Evaluator

**Execute phases in order:**

```ocaml
(* src/sgen_eval.ml *)
let eval_program_phased (program : program) : (env, error) result =
  let phases = group_by_phase program in

  (* Phase 0: Definitions *)
  let* env0 = eval_phase Definition (get_phase phases Definition) initial_env in

  (* Phase 1: Type checking *)
  let* env1 = eval_phase TypeCheck (get_phase phases TypeCheck) env0 in

  (* Phase 2: Execution *)
  let* env2 = eval_phase Execute (get_phase phases Execute) env1 in

  Ok env2

let eval_phase (phase : phase) (decls : declaration list) (env : env) =
  (* Within phase, sort by dependencies *)
  let sorted = topological_sort (build_dep_graph decls) in

  (* Execute in order *)
  List.fold_left sorted ~init:(Ok env) ~f:(fun acc node ->
    let* env' = acc in
    eval_decl node.decl env')
```

### Phase 4: Error Handling

**Type check errors:**

```ocaml
(* If type check fails, report and halt *)
let eval_type_check test env =
  match eval_sgen_expr test env with
  | Ok (env', result) when is_ok result ->
      Ok env'  (* Type check passed *)
  | Ok (env', result) ->
      Error (TypeCheckFailed (test, result))  (* Type check failed *)
  | Error e ->
      Error (TypeCheckError (test, e))  (* Evaluation error *)
```

**Cycle detection:**

```ocaml
let detect_and_report_cycles graph =
  let cycles = detect_cycles graph in
  match cycles with
  | [] -> Ok graph  (* No cycles *)
  | cs -> Error (CircularDependency cs)
```

### Phase 5: CLI Integration

**Add flag for phased execution:**

```ocaml
(* bin/sgen.ml *)
let phased_flag =
  Arg.(value & flag & info ["phased"]
       ~doc:"Enable multi-phase execution with type checking phase")

let run_phased = function
  | true -> eval_program_phased program
  | false -> eval_program program  (* Old behavior *)
```

---

## Conclusion

### Summary

**The Problem:**
- Many computations that users expect at compile-time currently happen at runtime in Stellogen
- Type checking, static analysis, optimization, code generation all run during execution
- Users want these in a separate phase before execution
- Compile-time computations may depend on other compile-time computations, creating complex dependencies

**The Solution:**
- General multi-phase execution system with phases: Definitions → Compile-Time → Runtime
- Compile-time phase supports arbitrary computations (not just type checking)
- Users can define custom phases for custom analyses
- Automatic dependency analysis within phases
- Explicit phase annotations for user control
- Backward compatible (single-phase execution still works)

**Key Design Decisions:**

1. **Phases are explicit**: Users opt into multi-phase execution via `@compile-time` blocks
2. **General compile-time phase**: Not limited to type checking—supports any compile-time computation
3. **User-defined analyses**: Users can create custom compile-time analyses and optimizations
4. **Dependencies are automatic**: Within a phase, execution order is determined by dependency analysis
5. **Cycles are handled**: Detect strongly connected components, execute simultaneously
6. **Extensible**: Users can define additional phases for complex pipelines
7. **Backward compatible**: Existing single-phase code still works

### Alignment with Stellogen's Philosophy

| Principle | Alignment |
|-----------|-----------|
| **Minimalism** | ✓ Core concept is simple: `@compile-time` vs `@runtime` |
| **Explicit control** | ✓ Users choose when to use phases and what computations run when |
| **Logic-agnostic** | ✓ Phases are an execution mechanism, not tied to any logic |
| **Local behavior** | ✓ Phases are explicit blocks with local structure |
| **User-driven** | ✓ System provides mechanism, users define analyses and policies |
| **Extensible** | ✓ Users can define custom compile-time analyses |

### Benefits

1. **Early error detection**: Type checks and analyses run before main execution
2. **Performance**:
   - Compile-time computations separated from runtime hot paths
   - Pre-computation of constants and tables
   - Code specialization and optimization
3. **Clarity**: Clear separation between definitions, compile-time work, and runtime execution
4. **Flexibility**: Users can add custom analyses and optimizations
5. **Compatibility**: Existing code continues to work
6. **Expressiveness**: Enables metaprogramming, reflection, code generation
7. **Safety**: Static analysis catches errors that runtime testing might miss

### Use Cases Enabled

The generalized phasing system enables many new use cases:

1. **Type Checking**: Original motivation, now one use case among many
2. **Static Analysis**: Exhaustiveness, termination, linearity, resource bounds
3. **Optimization**: Inlining, specialization, fusion, constant folding
4. **Code Generation**: Deriving functionality, generating boilerplate
5. **Metaprogramming**: Reflection, code transformation, macros
6. **Linting**: Custom rules, style checking, complexity metrics
7. **Testing**: Property checking, proof verification
8. **Documentation**: Generate docs from code structure

### Next Steps

1. **Implement Phase 1**: Core infrastructure (phase tracking in AST)
2. **Implement Phase 2**: Dependency analysis
3. **Test with examples**: Verify behavior on existing code with type checking
4. **Extend to general compile-time**: Support arbitrary compile-time computations
5. **Build compile-time library**: Standard library of compile-time tools
6. **Document patterns**: Show users how to use phases and define custom analyses
7. **Gather feedback**: Adjust based on real-world usage

### Open Questions

1. **How many phases?** Currently two main phases (Compile-Time, Runtime)—is this enough, or do users need more granularity?
2. **Phase granularity?** Should we allow user-defined sub-phases within compile-time?
3. **Cross-phase references?** Can Runtime access compile-time results? How are they stored?
4. **Performance?** Does dependency analysis add significant overhead?
5. **Termination?** Should we timeout compile-time computations that don't terminate?
6. **Compilation model?** Should compile-time results be cached between runs?
7. **Separate compilation?** How do phases interact across file boundaries?

These questions will be answered through experimentation and user feedback.

---

## Appendices

### Appendix A: Example Phased Programs

**Example 1: Type checking (original motivation):**

```stellogen
' Phase 0: Definitions
(:= nat { [(-nat 0) ok] [(-nat (s N)) (+nat N)] })

' Phase 1: Compile-time (type checking)
@compile-time {
  (:= zero (+nat 0))
  (:: zero nat)

  (:= one (+nat (s 0)))
  (:: one nat)
}

' Phase 2: Runtime
(show (interact #add1 @#zero))
```

**Example 2: Mixed compile-time computations:**

```stellogen
' Definitions
(:= factorial { ... })
(:= compute-optimal-size { ... })

' Compile-time: multiple analyses
@compile-time {
  ' Type checking
  (:: factorial (fn nat nat))

  ' Static analysis
  (check-terminates factorial)
  (check-exhaustive classify [neg zero pos])

  ' Optimization
  (inline small-functions)
  (:= factorial-opt (specialize #factorial))

  ' Pre-computation
  (:= table-size (interact #compute-optimal-size ...))
  (:= lookup-table (generate-table #table-size))
}

' Runtime: use pre-computed and optimized code
@runtime {
  (show (interact #factorial-opt 20))
  (show (lookup #lookup-table key))
}
```

**Example 3: User-defined static analysis:**

```stellogen
' Define custom analysis at compile-time
@compile-time {
  ' Analyze resource usage
  (new-declaration (check-resources Fn MaxMem)
    (let ([usage (estimate-memory #Fn)])
      (assert (<= #usage #MaxMem) "Memory bound exceeded")))

  ' Apply analysis
  (check-resources server-handler 1GB)
  (check-resources compute-intensive 512MB)
}

@runtime {
  (start-server #server-handler)
}
```

**Example 4: Code generation:**

```stellogen
@compile-time {
  ' Generate record type
  (:= person-record (generate-record
    [name string]
    [age nat]
    [email string]))

  ' Derive functionality
  (derive-for person-record [show eq serialize])
}

@runtime {
  (:= john (make-person "John" 30 "john@example.com"))
  (show #john)  ' Uses derived show
}
```

**Example 5: Complex dependency chain:**

```stellogen
@compile-time {
  ' 1. Type checking
  (:= factorial { ... })
  (:: factorial (fn nat nat))

  ' 2. Termination analysis (depends on type check)
  (:= termination-proof (prove-termination #factorial))

  ' 3. Optimization (depends on proof)
  (:= factorial-opt
    (if #termination-proof
      (aggressive-optimize #factorial)
      (conservative-optimize #factorial)))

  ' 4. Code generation (depends on optimized version)
  (:= factorial-specialized (specialize #factorial-opt 10))
}

' Execution order automatically determined:
' type-check → termination → optimize → specialize
```

**Example 6: Multi-phase pipeline:**

```stellogen
' Phase 0: Definitions
(:= my-function { ... })

' Phase 1a: Type checking
@phase:type-check {
  (:: my-function correct-type)
}

' Phase 1b: Static analysis
@phase:analyze {
  (check-terminates my-function)
  (verify-bounds my-function)
}

' Phase 1c: Optimization
@phase:optimize {
  (:= my-function-opt (optimize #my-function))
}

' Phase 2: Runtime
@runtime {
  (show (interact #my-function-opt ...))
}
```

**Example 7: Mutual recursion:**

```stellogen
@compile-time {
  @mutual {
    (:= even { [(-even 0) ok] [(-even (s N)) (+odd N)] })
    (:= odd { [(-odd (s N)) (+even N)] })
  }

  (:: test-even even)
  (:: test-odd odd)
  (check-terminates even)
  (check-terminates odd)
}
```

### Appendix B: Comparison with Other Languages

| Feature | Racket | TypeScript | Coq | Stellogen (Proposed) |
|---------|--------|------------|-----|----------------------|
| **Phases** | Multi-level | Two-phase | Two-phase | Multi-phase |
| **Explicit** | Implicit | Implicit | Implicit | Explicit |
| **Dependencies** | Automatic | Automatic | Automatic | Automatic (within phase) |
| **User control** | Limited | None | None | High |
| **Type erasure** | N/A | Yes | Yes | Optional |

### Appendix C: Alternative Syntax Ideas

**Idea 1: Inline phase annotations:**

```stellogen
(:= zero @phase:typecheck (+nat 0))
(:: zero nat @phase:typecheck)
```

**Idea 2: Implicit type checking phase:**

```stellogen
' Any (:: ...) automatically goes to type checking phase
(:= zero (+nat 0))
(:: zero nat)  ' Implicitly in type checking phase
```

**Idea 3: Named phases:**

```stellogen
(phase definitions
  (:= nat { ... }))

(phase type-checking
  (:= zero (+nat 0))
  (:: zero nat))

(phase execution
  (show ...))
```

### Appendix D: Building a Compile-Time Analysis Library

Users can build libraries of compile-time analyses and tools.

**Example: `lib/compile-time/core.sg`**

```stellogen
''' Core compile-time utilities '''

' Type checking
(new-declaration (:: Tested Test)
  @compile-time
  (== @(interact @#Tested #Test) ok))

' Type declaration (alias for spec)
(new-declaration (type Name Spec)
  (:= Name Spec))

' Function type
(new-declaration (fn ArgType RetType)
  {:= fn-type {
    [(-fn Arg Ret) (-fn-arg Arg #ArgType) (-fn-ret Ret #RetType)]}})

' Exhaustiveness checking
(new-declaration (check-exhaustive Fn Cases)
  @compile-time
  (let ([defined (extract-cases #Fn)]
        [expected #Cases])
    (== #defined #expected)))

' Termination checking
(new-declaration (check-terminates Fn)
  @compile-time
  (find-termination-measure #Fn))

' Linearity checking
(new-declaration (check-linear Fn)
  @compile-time
  (verify-each-resource-used-once #Fn))
```

**Example: `lib/compile-time/optimize.sg`**

```stellogen
''' Optimization utilities '''

' Inline small functions
(new-declaration (inline Fn)
  @compile-time
  (if (<= (size-of #Fn) 10)
    (mark-for-inlining #Fn)
    (warn "Function too large to inline:" #Fn)))

' Specialize function with constants
(new-declaration (specialize Fn Args)
  @compile-time
  (generate-specialized-version #Fn #Args))

' Fuse constellation pipeline
(new-declaration (fuse Pipeline)
  @compile-time
  (merge-constellations #Pipeline))

' Constant folding
(new-declaration (fold-constants Expr)
  @compile-time
  (evaluate-constant-expressions #Expr))
```

**Example: `lib/compile-time/codegen.sg`**

```stellogen
''' Code generation utilities '''

' Generate record type
(new-declaration (generate-record Fields)
  @compile-time
  (create-record-constellation #Fields))

' Derive functionality
(new-declaration (derive-for Type Traits)
  @compile-time
  (for-each #Traits (fn [Trait]
    (generate-trait-impl #Type #Trait))))

' Generate test cases
(new-declaration (generate-tests Fn Properties)
  @compile-time
  (create-property-tests #Fn #Properties))
```

**Example: `lib/compile-time/analysis.sg`**

```stellogen
''' Static analysis utilities '''

' Resource analysis
(new-declaration (analyze-resources Fn Bounds)
  @compile-time
  (verify-resource-bounds #Fn #Bounds))

' Complexity analysis
(new-declaration (analyze-complexity Fn Expected)
  @compile-time
  (estimate-complexity #Fn #Expected))

' Security analysis
(new-declaration (check-no-injection Fn)
  @compile-time
  (verify-input-sanitization #Fn))

' Concurrency analysis
(new-declaration (check-race-free Fn)
  @compile-time
  (analyze-data-races #Fn))
```

**Usage: Complete example**

```stellogen
(import-macros "lib/compile-time/core.sg")
(import-macros "lib/compile-time/optimize.sg")
(import-macros "lib/compile-time/codegen.sg")
(import-macros "lib/compile-time/analysis.sg")

' Definitions
(type nat {
  [(-nat 0) ok]
  [(-nat (s N)) (+nat N)]})

(type list {
  [(-list []) ok]
  [(-list [_|T]) (+list T)]})

(:= factorial {
  [(+factorial 0 1)]
  [(-factorial (s N) R)
   (-factorial N R1)
   (+mult (s N) R1 R)]})

' Compile-time phase
@compile-time {
  ' Type checking
  (:: factorial (fn nat nat))

  ' Static analysis
  (check-terminates factorial)
  (check-exhaustive factorial [base-case recursive-case])
  (analyze-complexity factorial O(n))

  ' Optimization
  (inline helper-functions)
  (:= factorial-opt (specialize factorial))

  ' Code generation
  (generate-record person [name age email])
  (derive-for person [show eq])
}

' Runtime
@runtime {
  (show (factorial 10))
  (:= john (make-person "John" 30 "john@example.com"))
  (show #john)
}
```

This demonstrates how users can build a rich ecosystem of compile-time tools that work together in Stellogen's phasing system.

---

**Document Version:** 2.0
**Last Updated:** 2025-10-12
**Author:** Analysis of phasing and compile-time evaluation in Stellogen (generalized beyond type checking)
