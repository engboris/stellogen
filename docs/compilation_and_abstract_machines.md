# Compilation Strategies and Abstract Machines for Stellogen

> **Disclaimer**: This document was written with the assistance of Claude Code and represents exploratory research and analysis. The content may contain inaccuracies or misinterpretations and should not be taken as definitive statements about the Stellogen language implementation.

**Status:** Research Document
**Date:** 2025-10-12
**Purpose:** Explore compilation strategies for Stellogen, focusing on abstract machines based on term unification, including the Warren Abstract Machine (WAM), a proposed Basic Interaction Machine (BIM), and WebAssembly (Wasm) compilation

---

## Table of Contents

1. [Introduction](#introduction)
2. [Stellogen's Computational Model](#stellogens-computational-model)
3. [The Warren Abstract Machine (WAM)](#the-warren-abstract-machine-wam)
4. [Other Abstract Machines](#other-abstract-machines)
5. [The Basic Interaction Machine (BIM)](#the-basic-interaction-machine-bim)
6. [Compilation to WebAssembly](#compilation-to-webassembly)
7. [Debugging Stellogen Programs](#debugging-stellogen-programs)
8. [Comparison and Trade-Offs](#comparison-and-trade-offs)
9. [Recommendation](#recommendation)
10. [Conclusion](#conclusion)

---

## Introduction

### The Core Insight

Stellogen's execution is fundamentally about **scheduling and organizing basic term unification**. While the current OCaml implementation handles:
- Parsing and AST construction
- Environment management
- Pattern matching
- Interaction resolution
- Polarity checking

The core computational work boils down to **term unification with polarity**.

### Compilation Goals

A compiled Stellogen implementation should:

1. **Reduce to primitives**: Break down high-level operations into basic term unification steps
2. **Optimize scheduling**: Efficiently determine which terms can interact
3. **Minimize overhead**: Remove interpretation overhead
4. **Enable portability**: Run on multiple platforms
5. **Preserve semantics**: Maintain Stellogen's interaction-based model

### Three Approaches

This document explores three compilation strategies:

1. **Basic Interaction Machine (BIM)**: A custom abstract machine for Stellogen's polarity-based interaction model
2. **Warren Abstract Machine (WAM)**: Adapt Prolog's proven abstract machine
3. **WebAssembly (Wasm)**: Compile to a standardized portable format

---

## Stellogen's Computational Model

### Core Operations

Before designing a compilation strategy, we must understand what Stellogen actually does.

**Fundamental operations:**

1. **Term construction**: Build terms from constructors and variables
   ```stellogen
   (s (s 0))        ' Constructor application
   X                ' Variable
   (f X Y)          ' Function term
   ```

2. **Term unification**: Find substitutions that make two terms equal
   ```
   unify((s X), (s 0)) = {X ↦ 0}
   unify((f X Y), (f 1 2)) = {X ↦ 1, Y ↦ 2}
   ```

3. **Polarity checking**: Determine if two terms have complementary polarity
   ```stellogen
   (+add X Y Z)     ' Positive polarity
   (-add A B C)     ' Negative polarity
   ' Can interact if polarities are complementary
   ```

4. **Constellation lookup**: Find stars in a constellation that match a query
   ```stellogen
   constellation = {
     [(+add 0 Y Y)]
     [(+add (s X) Y (s Z)) (-add X Y Z)]
   }
   query = (-add (s 0) (s 0) R)
   ' Find matching star: second one
   ```

5. **Interaction**: Execute fusion of complementary terms
   ```
   Positive: (+add (s X) Y (s Z))
   Negative: (-add (s 0) (s 0) R)
   Unify: X=0, Y=(s 0), R=(s Z)
   Continue: (-add 0 (s 0) Z)
   ```

6. **Environment management**: Track bindings and definitions
   ```
   env = {
     nat: constellation,
     add: constellation,
     zero: (+nat 0)
   }
   ```

### Current Execution Pipeline

```
Source Code
    ↓
[Parsing & Preprocessing]
    ↓
AST (sgen_expr list)
    ↓
[Conversion to LSC]
    - Lower to constellation representation
    ↓
LSC (Low-level constellation)
    ↓
[Evaluation/Interpretation]
    - Build environment
    - Resolve interactions
    - Execute unification
    ↓
Results
```

**Bottlenecks:**
- Interpretation overhead at every step
- Dynamic lookups in environments
- Pattern matching on AST nodes
- Allocating intermediate structures

### What's Really Happening

At the lowest level, Stellogen execution is:

```
LOOP:
  1. Find complementary terms (positive/negative)
  2. Attempt unification
  3. If unify succeeds:
     a. Apply substitution
     b. Generate new terms from interaction
     c. Add new terms to constellation
  4. Repeat until no more interactions
```

This is **much simpler** than the high-level implementation suggests. Most of the complexity is in:
- Parsing and desugaring
- Managing named definitions
- Tracking environments
- Handling focus (@) and references (#)

**Key insight:** We can compile away most of this complexity, leaving only the core unification loop.

---

## The Warren Abstract Machine (WAM)

### Overview

The **Warren Abstract Machine** is the standard compilation target for Prolog. Designed by David H. D. Warren in 1983, it's been the foundation for nearly all efficient Prolog implementations.

**Key features:**
- Stack-based execution
- Specialized instructions for unification
- Structure sharing via heap
- Efficient backtracking
- Register allocation

### WAM Architecture

**Components:**

1. **Registers**:
   - Argument registers: `A1, A2, ..., An` (pass arguments)
   - Temporary registers: `X1, X2, ..., Xm` (local variables)

2. **Memory areas**:
   - **Heap**: Store terms (structures, lists, variables)
   - **Stack**: Store choice points and environments
   - **Trail**: Track variable bindings for backtracking
   - **PDL** (Push-Down List): For structure copying

3. **Pointers**:
   - `H` (Heap pointer): Next free heap cell
   - `S` (Structure pointer): Current position in structure
   - `P` (Program pointer): Current instruction
   - `CP` (Continuation pointer): Return address
   - `E` (Environment pointer): Current environment
   - `B` (Choice point pointer): Last choice point

### WAM Instructions

**Core instruction set:**

```
' Argument registers
put_variable Xn, Ai     ' Create new variable in Xn, copy to Ai
put_value Xn, Ai        ' Copy Xn to Ai
put_structure f/n, Ai   ' Create structure f/n, put in Ai
put_constant c, Ai      ' Put constant c in Ai

get_variable Xn, Ai     ' Copy Ai to Xn
get_value Xn, Ai        ' Unify Xn with Ai
get_structure f/n, Ai   ' Unify Ai with structure f/n
get_constant c, Ai      ' Unify Ai with constant c

' Structure building
set_variable Xn         ' Create variable in Xn and push to heap
set_value Xn            ' Push Xn to heap
set_constant c          ' Push constant c to heap

' Structure reading
unify_variable Xn       ' Pop from heap/structure to Xn
unify_value Xn          ' Pop from heap/structure, unify with Xn
unify_constant c        ' Pop from heap/structure, unify with c

' Control flow
call p/n                ' Call predicate p with n arguments
proceed                 ' Return from predicate
allocate N              ' Allocate environment frame
deallocate              ' Deallocate environment frame

' Backtracking (Stellogen doesn't need these)
try_me_else L           ' Create choice point
retry_me_else L         ' Retry from choice point
trust_me                ' Last alternative
```

### Example: WAM Compilation

**Prolog code:**

```prolog
append([], L, L).
append([H|T1], L, [H|T2]) :- append(T1, L, T2).
```

**WAM code:**

```
' Clause 1: append([], L, L)
append/3_0:
    get_constant [], A1      ' Match first arg with []
    get_value A2, A3         ' Unify second and third args
    proceed

' Clause 2: append([H|T1], L, [H|T2]) :- append(T1, L, T2)
append/3_1:
    allocate 0
    get_structure [|]/2, A1  ' Match first arg with [H|T1]
    unify_variable X1        ' Extract H
    unify_variable X2        ' Extract T1
    get_structure [|]/2, A3  ' Build [H|T2] in third arg
    unify_value X1           ' Use H
    unify_variable X3        ' New variable T2
    put_value X2, A1         ' T1 becomes first arg of recursive call
    put_value A2, A2         ' L stays as second arg
    put_value X3, A3         ' T2 becomes third arg
    call append/3
    deallocate
    proceed
```

### WAM and Stellogen: Compatibility Analysis

**Similarities:**

| WAM Feature | Stellogen Equivalent |
|-------------|---------------------|
| Term unification | Same (core operation) |
| Heap allocation | Terms stored in heap |
| Structure building | Constructor application |
| Registers | Could use for arguments |

**Incompatibilities:**

| WAM Feature | Stellogen Issue |
|-------------|-----------------|
| **Backtracking** | Stellogen has no backtracking |
| **Sequential clauses** | Stellogen has unordered constellations |
| **Choice points** | Not needed (no search) |
| **Trail** | No backtracking = no need to undo bindings |
| **Continuation passing** | Different control flow (interaction-based) |

**Key difference:** WAM is designed for **depth-first search with backtracking**. Stellogen uses **polarity-based interaction without backtracking**.

### Could We Adapt the WAM?

**Potential approach:**

1. **Keep**: Heap, registers, unification instructions
2. **Remove**: Choice points, trail, backtracking instructions
3. **Add**: Polarity checking, constellation management, interaction scheduling

**Result:** A "WAM without backtracking" + polarity extensions.

**Pros:**
- Proven instruction set for unification
- Well-understood compilation techniques
- Extensive optimization literature

**Cons:**
- WAM optimized for different execution model
- Would need significant modifications
- May not be the best fit for Stellogen's semantics

---

## Other Abstract Machines

Before designing a custom machine, let's survey other abstract machines to understand the design space.

### ZINC Machine (OCaml)

**Purpose:** Bytecode VM for functional languages (originally Caml)

**Architecture:**
- Stack-based
- Instructions: `push`, `apply`, `return`, `match`
- Closure representation
- No unification (functional, not logic)

**Relevance to Stellogen:**
- Stack-based execution is efficient
- Pattern matching compilation techniques
- Not suitable: no unification support

### SECD Machine (Lisp)

**Purpose:** Abstract machine for lambda calculus

**Components:**
- **S**tack: Arguments and intermediate values
- **E**nvironment: Variable bindings
- **C**ode: Current expression
- **D**ump: Saved states (for function calls)

**Instructions:**
- `LD` (load variable)
- `AP` (apply function)
- `RTN` (return)
- `SEL` (select/branch)

**Relevance to Stellogen:**
- Good model for environment management
- Stack-based evaluation
- Not suitable: functional, not unification-based

### G-Machine (Haskell)

**Purpose:** Graph reduction machine for lazy functional languages

**Key idea:** Represent programs as graphs, reduce by rewriting

**Relevance to Stellogen:**
- Graph rewriting is similar to term interaction
- Could inspire constellation representation
- Not suitable: lazy evaluation, no unification

### Categorical Abstract Machine (CAM)

**Purpose:** Abstract machine based on category theory

**Key idea:** Combinators represent computation

**Relevance to Stellogen:**
- Combinator-based approach is elegant
- Could represent interactions as combinators
- Not suitable: too abstract, no unification

### Interaction Nets Abstract Machine

**Purpose:** Execute interaction nets (graph rewriting with ports)

**Key idea:**
- Nodes with ports
- Interaction rules (active pairs)
- Parallel reduction

**Relevance to Stellogen:**
- **Highly relevant!** Stellogen is inspired by interaction nets
- Polarity = principal ports
- Interaction = active pair reduction
- Could adapt for term-based representation

**Example interaction net rule:**

```
   γ           α           α'
    \         /             |
     \       /              |
      \     /               |
       \   /                |
        \ /      ===>       |
         δ                  |
        / \                 |
       /   \                |
      /     \               |
     /       \              |
    β         ε            β'
                            |
                           ε'
```

In Stellogen terms:

```stellogen
' Active pair (complementary polarities)
(+f X Y) ~ (-f A B)

' Reduces to
(unify X A) ∧ (unify Y B)
```

### Summary: Lessons from Other Machines

| Machine | Key Takeaway |
|---------|-------------|
| **WAM** | Efficient unification instructions, register allocation |
| **ZINC** | Stack-based execution, pattern matching |
| **SECD** | Environment management |
| **G-Machine** | Graph reduction, structure sharing |
| **Interaction Nets** | **Polarity-driven reduction** |

**Best fit:** Interaction nets abstract machine + WAM's unification techniques.

---

## The Basic Interaction Machine (BIM)

### Design Philosophy

The **Basic Interaction Machine** is a custom abstract machine designed specifically for Stellogen's polarity-based interaction model.

**Core principles:**

1. **Unification-centric**: Optimized for term unification
2. **Polarity-aware**: First-class support for positive/negative/neutral terms
3. **Set-based**: Constellations are sets, not sequences
4. **No backtracking**: Simplified compared to WAM
5. **Explicit scheduling**: Interaction is scheduled, not searched

### Architecture

#### Memory Layout

```
┌─────────────────────────────────────────────────────┐
│                     HEAP                              │
│  - Terms (structures, atoms, variables)               │
│  - Constellations (sets of stars)                     │
│  - Substitutions (variable bindings)                  │
└─────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│                     STACK                             │
│  - Argument frames                                    │
│  - Continuation frames                                │
│  - Environment frames                                 │
└─────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│                 INTERACTION QUEUE                     │
│  - Pairs of terms ready to interact                   │
│  - Pending interactions                               │
└─────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│                CONSTELLATION TABLE                    │
│  - Named constellations                               │
│  - Indexed by identifier                              │
└─────────────────────────────────────────────────────┘
```

#### Registers

```
' Term registers
T1, T2, ..., Tn        ' Temporary terms

' Polarity registers
POL                    ' Current term polarity (+, -, neutral)

' Pointers
H                      ' Heap pointer (next free cell)
SP                     ' Stack pointer
IP                     ' Instruction pointer
IQ                     ' Interaction queue pointer

' Mode flag
MODE                   ' Current mode: read/write
```

### Instruction Set

#### Term Construction

```
' Build a term on the heap
build_term f/n → T        ' Build structure f with n arguments
build_var X → T           ' Create fresh variable
build_atom c → T          ' Build constant atom
build_list H|T → T        ' Build list [H|T]

' Set polarity
set_polarity +/-/0 T      ' Set term's polarity

' Register operations
load_term T Ri            ' Load term into register
store_term Ri T           ' Store register to term
```

#### Unification

```
' Unify two terms
unify T1 T2 → subst       ' Returns substitution or fail

' Apply substitution
apply_subst subst T → T'  ' Apply substitution to term

' Check unifiability
can_unify T1 T2 → bool    ' Test if terms can unify
```

#### Constellation Operations

```
' Load constellation
load_const id → const     ' Load constellation by name

' Find matching stars
find_stars const T → list ' Find stars matching term T

' Add star to constellation
add_star const star       ' Add new star to constellation

' Remove star (for fire)
remove_star const star    ' Linear consumption
```

#### Polarity Operations

```
' Check polarity
get_polarity T → pol      ' Get term's polarity

' Check complementarity
are_complementary pol1 pol2 → bool
    ' + and - are complementary
    ' neutral complements with anything

' Check compatibility (for interact)
can_interact T1 T2 → bool
    ' Checks both polarity and symbol
```

#### Interaction

```
' Schedule interaction
schedule T1 T2            ' Add to interaction queue

' Process interaction
interact T1 T2 → terms    ' Execute one interaction step
    ' 1. Check polarities
    ' 2. Unify
    ' 3. Generate continuations
    ' 4. Return new terms

' Interaction modes
set_mode linear           ' Fire mode (consume stars)
set_mode nonlinear        ' Interact mode (reuse stars)
```

#### Control Flow

```
' Function call
call label                ' Jump to label

' Return
return                    ' Pop stack, jump to continuation

' Conditional
branch_if_fail label      ' Jump if previous operation failed

' Loop
repeat label              ' Jump back to label
halt                      ' Stop execution
```

### Execution Model

#### Interaction Loop

```
MAIN_LOOP:
    ' Get next term from queue
    pop_interaction_queue → (T1, T2)

    ' If queue empty, halt
    branch_if_empty HALT

    ' Check if terms can interact
    can_interact T1 T2 → result
    branch_if_fail SKIP

    ' Perform unification
    unify T1 T2 → subst
    branch_if_fail SKIP

    ' Apply substitution to continuations
    apply_subst subst T1_cont → T1'
    apply_subst subst T2_cont → T2'

    ' Schedule new interactions
    schedule T1' T2'

SKIP:
    jump MAIN_LOOP

HALT:
    return
```

#### Compilation Strategy

**High-level Stellogen:**

```stellogen
(:= add {
  [(+add 0 Y Y)]
  [(-add X Y Z) (+add (s X) Y (s Z))]})

(:= query [(-add <s s 0> <s s 0> R) R])
(exec #add @#query)
```

**Step 1: Compile constellation definitions**

```
' Define constellation 'add'
DEFINE_CONST add:
    ' Star 1: (+add 0 Y Y)
    build_atom 0 → T1
    build_var Y → T2
    build_var Y → T3
    build_term add/3 T1 T2 T3 → star1
    set_polarity + star1
    add_star add star1

    ' Star 2: [(-add X Y Z) (+add (s X) Y (s Z))]
    build_var X → T1
    build_var Y → T2
    build_var Z → T3
    build_term add/3 T1 T2 T3 → star2_neg
    set_polarity - star2_neg

    build_term s/1 T1 → T4
    build_term s/1 T3 → T5
    build_term add/3 T4 T2 T5 → star2_pos
    set_polarity + star2_pos

    build_conjunction star2_neg star2_pos → star2
    add_star add star2

    return
```

**Step 2: Compile query**

```
COMPILE_QUERY:
    ' Build query term: (-add (s (s 0)) (s (s 0)) R)
    build_atom 0 → T1
    build_term s/1 T1 → T2
    build_term s/1 T2 → T3
    build_term s/1 T1 → T4
    build_term s/1 T4 → T5
    build_var R → T6
    build_term add/3 T3 T5 T6 → query
    set_polarity - query

    return query
```

**Step 3: Compile interaction**

```
EXECUTE_INTERACT:
    ' Load constellation
    load_const add → const

    ' Load query
    call COMPILE_QUERY
    store_term T1 query

    ' Find matching stars
    find_stars const query → stars_list

    ' Schedule interactions
SCHEDULE_LOOP:
    pop stars_list → star
    branch_if_empty INTERACTION_LOOP
    schedule query star
    jump SCHEDULE_LOOP

    ' Execute interactions
INTERACTION_LOOP:
    call MAIN_LOOP

    return
```

### Example: Full Compilation

**Stellogen program:**

```stellogen
(:= nat {
  [(-nat 0) ok]
  [(-nat (s N)) (+nat N)]})

(:= zero (+nat 0))
(:: zero nat)
```

**BIM bytecode:**

```
' Define nat constellation
DEFINE_NAT:
    ' Star 1: [(-nat 0) ok]
    build_atom 0 → T1
    build_term nat/1 T1 → star1_req
    set_polarity - star1_req
    build_atom ok → star1_res
    build_conjunction star1_req star1_res → star1
    add_star nat star1

    ' Star 2: [(-nat (s N)) (+nat N)]
    build_var N → T1
    build_term s/1 T1 → T2
    build_term nat/1 T2 → star2_req
    set_polarity - star2_req
    build_term nat/1 T1 → star2_prov
    set_polarity + star2_prov
    build_conjunction star2_req star2_prov → star2
    add_star nat star2

    return

' Define zero
DEFINE_ZERO:
    build_atom 0 → T1
    build_term nat/1 T1 → zero_term
    set_polarity + zero_term
    store_global zero zero_term
    return

' Type check zero : nat
TYPE_CHECK:
    ' Load zero
    load_global zero → T1

    ' Load nat
    load_const nat → T2

    ' Interact
    schedule T1 T2
    call MAIN_LOOP

    ' Check result
    pop_result → result
    compare result ok → bool
    branch_if_fail TYPE_ERROR

    return

TYPE_ERROR:
    error "Type check failed"
    halt

' Main entry point
MAIN:
    call DEFINE_NAT
    call DEFINE_ZERO
    call TYPE_CHECK
    halt
```

### Optimizations

#### Register Allocation

**Liveness analysis:** Determine which variables are live at each point.

**Register assignment:** Assign frequently-used variables to registers.

**Spilling:** Move less-used variables to stack.

**Example:**

```stellogen
[(-add X Y Z) (+mult X X W) (+add W Y Z)]
```

**Liveness:**
```
Point 1: {X, Y, Z}  ' All live at start
Point 2: {W, Y, Z}  ' X dead after mult
Point 3: {}         ' All dead after add
```

**Register assignment:**
```
X → R1
Y → R2
Z → R3
W → R4 (or reuse R1)
```

#### Structure Sharing

**Heap structures can be shared:**

```stellogen
(:= list [1, 2, 3, 4, 5])
(:= head (first #list))
(:= tail (rest #list))
```

Both `head` and `tail` operations share the same heap structure for `list`.

#### Inline Expansion

**Small constellations can be inlined:**

```stellogen
(:= id [(+id X) X])
```

**Instead of:**
```
call id
unify result X
```

**Inline:**
```
' Just bind X directly
```

#### Constant Folding

**Evaluate interactions at compile-time when possible:**

```stellogen
(:= constant (exec #add @#two @#three))
```

If `add`, `two`, and `three` are all known at compile-time, evaluate now and store the result.

#### Dead Code Elimination

**Remove unused definitions:**

```stellogen
(:= unused-function { ... })
(:= main ...)
```

If `unused-function` is never referenced, don't compile it.

---

## Compilation to WebAssembly

### Overview

**WebAssembly (Wasm)** is a low-level bytecode format designed for:
- Near-native performance
- Portability (runs in browsers and standalone runtimes)
- Security (sandboxed execution)
- Standardization (W3C standard)

**Key features:**
- Stack-based VM
- Typed instructions (i32, i64, f32, f64)
- Linear memory
- Function calls
- No garbage collection (yet - GC proposal in progress)

### Wasm Architecture

**Module structure:**

```wasm
(module
  ;; Memory (heap)
  (memory 1)  ;; 1 page = 64KB

  ;; Function table (for indirect calls)
  (table 10 funcref)

  ;; Imports
  (import "env" "print" (func $print (param i32)))

  ;; Functions
  (func $add (param $x i32) (param $y i32) (result i32)
    local.get $x
    local.get $y
    i32.add)

  ;; Exports
  (export "add" (func $add))
)
```

**Instruction types:**

```
' Numeric operations
i32.add, i32.sub, i32.mul, i32.div_s
i64.add, i64.sub, ...
f32.add, f32.sub, ...

' Memory operations
i32.load, i32.store
i32.load8_s, i32.store8
i64.load, i64.store

' Control flow
call, call_indirect
if, else, end
block, loop, br, br_if
return

' Variables
local.get, local.set
global.get, global.set
```

### Compiling Stellogen to Wasm

#### Strategy 1: Direct Compilation

**Idea:** Compile Stellogen directly to Wasm instructions.

**Challenges:**

1. **No direct unification support**: Must implement unification in Wasm
2. **Memory management**: Must manually manage heap for terms
3. **Complex data structures**: Constellations, terms, substitutions
4. **No pattern matching**: Must encode pattern matching as branches

**Approach:**

```wasm
(module
  (memory 1)

  ;; Heap layout:
  ;; [0-3]: Heap pointer (next free address)
  ;; [4+]: Terms

  ;; Term representation:
  ;; Word 0: Tag (0=var, 1=atom, 2=struct)
  ;; Word 1+: Data

  ;; Allocate term
  (func $alloc_term (param $size i32) (result i32)
    (local $ptr i32)
    ;; Get heap pointer
    (local.set $ptr (i32.load (i32.const 0)))
    ;; Increment heap pointer
    (i32.store (i32.const 0)
      (i32.add (local.get $ptr) (local.get $size)))
    ;; Return old pointer
    (local.get $ptr))

  ;; Build atom
  (func $build_atom (param $value i32) (result i32)
    (local $ptr i32)
    (local.set $ptr (call $alloc_term (i32.const 8)))
    (i32.store (local.get $ptr) (i32.const 1))  ;; Tag: atom
    (i32.store (i32.add (local.get $ptr) (i32.const 4))
               (local.get $value))
    (local.get $ptr))

  ;; Unify two terms
  (func $unify (param $t1 i32) (param $t2 i32) (result i32)
    (local $tag1 i32)
    (local $tag2 i32)
    ;; Get tags
    (local.set $tag1 (i32.load (local.get $t1)))
    (local.set $tag2 (i32.load (local.get $t2)))
    ;; Check if both are atoms
    (if (i32.and (i32.eq (local.get $tag1) (i32.const 1))
                 (i32.eq (local.get $tag2) (i32.const 1)))
      (then
        ;; Compare values
        (i32.eq (i32.load (i32.add (local.get $t1) (i32.const 4)))
                (i32.load (i32.add (local.get $t2) (i32.const 4)))))
      (else
        ;; TODO: Handle other cases (variables, structures)
        (i32.const 0))))

  ;; Export
  (export "unify" (func $unify))
)
```

**Pros:**
- Full control over implementation
- Can optimize for Wasm
- Portable (runs anywhere Wasm runs)

**Cons:**
- Complex to implement correctly
- Must reimplement all unification logic
- Manual memory management
- Large code size
- Debugging is difficult

#### Strategy 2: Compile BIM to Wasm

**Idea:** First compile Stellogen to BIM bytecode, then compile BIM to Wasm.

**Approach:**

```
Stellogen → BIM bytecode → Wasm
```

**BIM bytecode interpreter in Wasm:**

```wasm
(module
  (memory 1)

  ;; BIM state
  (global $heap_ptr (mut i32) (i32.const 1024))
  (global $ip (mut i32) (i32.const 0))

  ;; BIM registers (simulated)
  (global $T1 (mut i32) (i32.const 0))
  (global $T2 (mut i32) (i32.const 0))

  ;; Bytecode memory starts at address 0

  ;; Interpret one instruction
  (func $step
    (local $opcode i32)
    (local $arg1 i32)
    (local $arg2 i32)

    ;; Fetch opcode
    (local.set $opcode (i32.load8_u (global.get $ip)))
    (global.set $ip (i32.add (global.get $ip) (i32.const 1)))

    ;; Dispatch
    (block $dispatch
      (br_table $dispatch
        (local.get $opcode)
        0 1 2 3 4 5 ...)  ;; Jump table

      ;; Opcode 0: build_atom
      (local.set $arg1 (i32.load (global.get $ip)))
      (global.set $ip (i32.add (global.get $ip) (i32.const 4)))
      (global.set $T1 (call $build_atom (local.get $arg1)))
      (br $dispatch)

      ;; Opcode 1: unify
      ;; ... etc ...
    )
  )

  ;; Main interpreter loop
  (func $run
    (loop $loop
      (call $step)
      (br_if $loop (i32.ne (global.get $ip) (i32.const -1))))
  )

  (export "run" (func $run))
)
```

**Pros:**
- Simpler than direct compilation
- Can reuse BIM implementation
- BIM bytecode is easier to generate and debug

**Cons:**
- Interpretation overhead
- Indirect dispatch (slower)
- Still need to implement BIM in Wasm

#### Strategy 3: Runtime in Native + Wasm Interop

**Idea:** Keep the Stellogen runtime in native code (OCaml, Rust, C), compile user code to Wasm, interop between them.

**Architecture:**

```
┌─────────────────────────────────┐
│   User Stellogen Code           │
│   (compiled to Wasm)            │
└────────────┬────────────────────┘
             │ Wasm imports
             ↓
┌─────────────────────────────────┐
│   Stellogen Runtime             │
│   (Native: OCaml/Rust/C)        │
│   - Unification engine          │
│   - Constellation management    │
│   - Garbage collection          │
└─────────────────────────────────┘
```

**Example:**

```wasm
;; User code (Wasm)
(module
  ;; Import unification from runtime
  (import "stellogen" "unify"
    (func $unify (param i32 i32) (result i32)))

  ;; Import constellation lookup
  (import "stellogen" "find_stars"
    (func $find_stars (param i32 i32) (result i32)))

  ;; User-defined function
  (func $my_computation (param $x i32) (result i32)
    ;; Build term
    (call $unify (local.get $x) (i32.const 42))
    ;; ... etc ...
  )

  (export "my_computation" (func $my_computation))
)
```

**Pros:**
- Reuse existing OCaml implementation
- Only compile user logic to Wasm
- Complex operations stay in native code (fast)
- Easier debugging

**Cons:**
- Requires Wasm runtime with good interop
- Crossing Wasm boundary has overhead
- Not fully portable (depends on native runtime)

### Wasm Limitations for Stellogen

1. **No garbage collection** (yet): Manual memory management required
2. **No exceptions** (yet): Must use error codes
3. **No direct threading**: Limited parallelism
4. **Linear memory model**: Heap must be manually managed
5. **No RTTI**: Type information must be encoded in data
6. **Limited debugging**: Debugging Wasm is harder than native code

### GC Proposal

**Wasm GC proposal** adds:
- Garbage-collected heap
- Structured types (structs, arrays)
- Reference types
- Type imports/exports

**Status:** In progress, not yet standardized.

**If GC lands:** Wasm becomes much more suitable for Stellogen.

---

## Debugging Stellogen Programs

### The Debugging Challenge

Debugging is essential for practical programming languages. However, **compiled code is harder to debug than interpreted code** because:

1. **Source information is lost**: Compiled code operates on low-level representations
2. **Optimizations obscure logic**: Inlining, constant folding, etc. change structure
3. **Mapping is complex**: Hard to relate machine state back to source code
4. **Performance vs debuggability**: Debug builds are slower

For Stellogen specifically, debugging has unique requirements:

- **Visualizing interactions**: Show which terms are interacting
- **Polarity tracking**: Display term polarities
- **Constellation state**: Visualize active stars
- **Unification steps**: Show detailed unification process
- **Interaction history**: Track sequence of interactions

### Debugging Requirements for Stellogen

#### Core Features

A Stellogen debugger should support:

1. **Breakpoints**:
   - Break on constellation entry
   - Break on interaction
   - Break on unification failure
   - Conditional breakpoints (e.g., "break when X unifies with 0")

2. **Stepping**:
   - Step into constellation
   - Step over interaction
   - Step out of recursive interaction
   - Continue until next interaction

3. **Inspection**:
   - View term structure
   - Show variable bindings
   - Display constellation contents
   - Examine interaction queue

4. **Visualization**:
   - Constellation graph (stars and their connections)
   - Interaction timeline
   - Term structure tree
   - Polarity indicators

5. **Evaluation**:
   - Evaluate expressions in current context
   - Test unification interactively
   - Query constellation state

#### Stellogen-Specific Features

**1. Interaction Visualization**

```
Current Interaction:
  Positive: (+add (s 0) (s 0) R)
  Negative: (-add X Y Z)

Unification:
  X = (s 0)
  Y = (s 0)
  Z = R

Continuation:
  (+add 0 (s 0) R')  where Z = (s R')
```

**2. Constellation Browser**

```
Constellation: add
  Stars:
    [✓] [(+add 0 Y Y)]
        Status: Active
        Polarity: Positive

    [✓] [(-add X Y Z) (+add (s X) Y (s Z))]
        Status: Active
        Polarity: Negative → Positive
        Continuation: yes
```

**3. Interaction History**

```
Step 1: (-add (s (s 0)) (s (s 0)) R) ← User query
Step 2:   Matched with: [(-add X Y Z) (+add (s X) Y (s Z))]
Step 3:   Unified: X=(s (s 0)), Y=(s (s 0)), Z=R
Step 4:   Continue: (+add (s 0) (s (s 0)) (s R))
Step 5:   Matched with: [(-add X Y Z) (+add (s X) Y (s Z))]
Step 6:   Unified: X=(s 0), Y=(s (s 0)), Z=(s R)
Step 7:   Continue: (+add 0 (s (s 0)) (s (s R)))
Step 8:   Matched with: [(+add 0 Y Y)]
Step 9:   Unified: Y=(s (s 0)), Result=(s (s 0))
Step 10:  Done: R = (s (s (s (s 0))))
```

**4. Watch Expressions**

```
Watch: R
  Step 1: R = _unbound_
  Step 5: R = (s R')
  Step 7: R = (s (s R''))
  Step 10: R = (s (s (s (s 0))))
```

**5. Polarity Highlighting**

```
Query: [(-add X Y Z) (+mult X X W) (-add W Y Z)]
       ↑ negative   ↑ positive    ↑ negative

Available stars:
  [(+add 0 Y Y)]                    ← Can match first -add
  [(+mult (s X) Y (s Z)) ...]       ← Can match +mult
```

### Debug Information Requirements

To enable debugging, we need to maintain **debug information** that maps compiled code back to source.

#### Source Mapping

**Components:**

1. **Source locations**: Line/column for each expression
   ```
   Expression: (+add X Y Z)
   Location: file.sg:5:10-18
   ```

2. **Variable names**: Preserve original variable names
   ```
   Compiled register: R3
   Source variable: X
   Original location: file.sg:5:11
   ```

3. **Constellation names**: Map addresses to names
   ```
   Address: 0x1000
   Name: add
   Source: file.sg:3:5
   ```

4. **Instruction mapping**: Map bytecode/native instructions to source
   ```
   BIM instruction: UNIFY T1 T2
   Source: Line 5, unification of X and Y
   ```

#### Debug Symbols

**Format (similar to DWARF):**

```
.debug_info:
  Constellation: add
    Location: file.sg:3:5-7:1
    Stars:
      Star 0:
        Location: file.sg:4:3-4:18
        Pattern: (+add 0 Y Y)
        Variables:
          Y: location=file.sg:4:13
      Star 1:
        Location: file.sg:5:3-5:42
        Pattern: [(-add X Y Z) (+add (s X) Y (s Z))]
        Variables:
          X: location=file.sg:5:10
          Y: location=file.sg:5:12
          Z: location=file.sg:5:14

.debug_line:
  0x0000 → file.sg:3:5    ' DEFINE_CONST add
  0x0004 → file.sg:4:3    ' BUILD_ATOM 0
  0x0008 → file.sg:4:11   ' BUILD_VAR Y
  ...

.debug_var:
  Variable: X
    Type: term
    Register: T1
    Scope: Star 1
    Location: file.sg:5:10
```

### Debugging Different Compilation Targets

#### 1. Debugging Interpreted Code (Current OCaml)

**Advantages:**
- Full source information available
- Easy to inspect state
- No compilation overhead
- Can modify code at runtime (REPL)

**Implementation:**

```ocaml
(* Debug state *)
type debug_state = {
  breakpoints: (location * condition option) list;
  watch_vars: string list;
  step_mode: step_mode;
  interaction_history: interaction list;
}

(* Debugger hooks *)
let eval_with_debug debug_state env expr =
  (* Before evaluation *)
  check_breakpoints debug_state expr;

  (* Evaluate *)
  let result = eval_sgen_expr env expr in

  (* After evaluation *)
  update_watches debug_state result;
  record_interaction debug_state expr result;

  result
```

**Debugging experience:** ⭐⭐⭐⭐⭐ Excellent

#### 2. Debugging BIM Bytecode

**Advantages:**
- Can single-step instructions
- Clear instruction boundaries
- Easy to map to source (with debug info)
- Interpreter can be instrumented

**Debug-Aware BIM Interpreter:**

```ocaml
type bim_debugger = {
  breakpoints: (pc * condition option) list;
  watch_addresses: address list;
  step_mode: step_mode;
  source_map: (pc * source_location) list;
}

let execute_instruction_debug debugger state instr =
  (* Check breakpoint *)
  if has_breakpoint debugger state.pc then
    enter_debug_mode debugger state;

  (* Execute instruction *)
  let state' = execute_instruction state instr in

  (* Update watches *)
  if step_mode debugger = StepByStep then
    display_state debugger state';

  state'
```

**Debug Information in Bytecode:**

```
; file.sg:3:5 - Define add
DEFINE_CONST add

; file.sg:4:3 - Star 1: (+add 0 Y Y)
; file.sg:4:11 - Variable Y
BUILD_ATOM 0          ; .loc file.sg:4:8
BUILD_VAR Y           ; .loc file.sg:4:11
BUILD_STRUCT add/3    ; .loc file.sg:4:4

; Source variable mapping
; .var Y R2 file.sg:4:11
```

**Stepping through bytecode:**

```
[Step 1] BUILD_ATOM 0
  Source: file.sg:4:8 (+add 0 Y Y)
  Result: T1 = 0

[Step 2] BUILD_VAR Y
  Source: file.sg:4:11
  Result: T2 = Y (unbound)

[Step 3] BUILD_STRUCT add/3
  Source: file.sg:4:4
  Arguments: T1=0, T2=Y, T3=Y
  Result: T4 = (+add 0 Y Y)
```

**Debugging experience:** ⭐⭐⭐⭐ Very Good

#### 3. Debugging Native Code (JIT/AOT)

**Challenges:**
- Instructions optimized away
- Variables in registers or optimized out
- Inlining obscures control flow
- Stack frames reorganized

**Solutions:**

**A. Debug vs Release Builds**

```
Debug build:
  - No optimizations
  - Preserve all variables
  - Clear stack frames
  - Source line annotations

Release build:
  - Full optimizations
  - Limited debugging
  - Performance focus
```

**B. Debug Information (DWARF format)**

```dwarf
DW_TAG_subprogram
  DW_AT_name: "interact_add"
  DW_AT_low_pc: 0x1000
  DW_AT_high_pc: 0x1200
  DW_AT_file: "file.sg"
  DW_AT_line: 3

  DW_TAG_variable
    DW_AT_name: "X"
    DW_AT_type: term
    DW_AT_location: register(rax)

  DW_TAG_variable
    DW_AT_name: "Y"
    DW_AT_type: term
    DW_AT_location: stack_offset(-16)
```

**C. Deoptimization (for JIT)**

When hitting a breakpoint in optimized code:

```
1. Pause execution
2. Reconstruct interpreter state from native state
3. Enter interpreter mode (with debug info)
4. Step/inspect in interpreter
5. Optionally recompile and continue in native code
```

**Example (LLVM-style):**

```llvm
; Optimized code
define i64 @interact_add_opt(i64 %x, i64 %y) {
  ; Inlined, optimized
  %result = add i64 %x, %y
  ret i64 %result
}

; Debug info
!dbg !1 = !DILocation(line: 5, column: 10, scope: !2)
!2 = !DISubprogram(name: "interact_add", file: !3, line: 5)
```

**Debugging experience:** ⭐⭐⭐ Good (debug builds), ⭐⭐ Fair (release builds)

#### 4. Debugging WebAssembly

**Challenges:**
- Limited debugging support (improving)
- Source maps required
- Limited introspection
- Browser devtools vary

**Solutions:**

**A. Source Maps**

```json
{
  "version": 3,
  "sources": ["add.sg"],
  "mappings": "AAAA;AACA;AACA...",
  "names": ["add", "X", "Y", "Z"]
}
```

**B. DWARF in Wasm**

Wasm supports DWARF debug information in custom sections:

```wasm
(module
  ;; Code
  (func $interact_add ...)

  ;; Debug info
  (custom ".debug_info" (data ...))
  (custom ".debug_line" (data ...))
  (custom ".debug_abbrev" (data ...))
)
```

**C. Browser DevTools**

Modern browsers support Wasm debugging:

```
Chrome DevTools:
  - Set breakpoints in Wasm
  - Inspect linear memory
  - View call stack
  - Step through instructions

With source maps:
  - Debug at Stellogen source level
  - See original variable names
  - Step through source lines
```

**D. Custom Debug Runtime**

```javascript
// Wasm module with debug hooks
const wasmModule = await WebAssembly.instantiate(wasmBytes, {
  debug: {
    breakpoint: (location) => {
      console.log(`Breakpoint at ${location}`);
      debugger; // Enter browser debugger
    },
    trace: (msg) => {
      console.log(`[Trace] ${msg}`);
    }
  }
});
```

**Debugging experience:** ⭐⭐⭐ Good (with source maps), ⭐⭐ Fair (raw Wasm)

### Debugger Architecture

#### Components

```
┌─────────────────────────────────────────────────┐
│           Stellogen Debugger Frontend           │
│  - UI (TUI or GUI)                              │
│  - Breakpoint management                        │
│  - Variable inspection                          │
│  - Constellation visualization                  │
└──────────────────┬──────────────────────────────┘
                   │ Debug Protocol (JSON-RPC)
┌──────────────────┴──────────────────────────────┐
│           Debug Adapter / Server                │
│  - Protocol handling                            │
│  - State management                             │
│  - Event dispatching                            │
└──────────────────┬──────────────────────────────┘
                   │ VM Control
┌──────────────────┴──────────────────────────────┐
│        Stellogen Runtime with Debug Hooks       │
│  - Interpreter OR                               │
│  - BIM VM OR                                    │
│  - Native code with debug info                  │
└─────────────────────────────────────────────────┘
```

#### Debug Adapter Protocol (DAP)

Use Microsoft's Debug Adapter Protocol for editor integration:

```json
{
  "seq": 1,
  "type": "request",
  "command": "setBreakpoints",
  "arguments": {
    "source": { "path": "add.sg" },
    "breakpoints": [
      { "line": 5, "condition": "X == 0" }
    ]
  }
}

{
  "seq": 2,
  "type": "event",
  "event": "stopped",
  "body": {
    "reason": "breakpoint",
    "threadId": 1,
    "text": "Breakpoint in constellation 'add'"
  }
}
```

**Benefits:**
- Works with VS Code, vim, emacs, etc.
- Standardized protocol
- Rich debugging features
- Cross-platform

#### Debug Server Implementation

```ocaml
(* Debug server *)
type debug_server = {
  runtime: stellogen_runtime;
  breakpoints: breakpoint list ref;
  state: debug_state ref;
  client: connection;
}

let handle_request server request =
  match request with
  | SetBreakpoints { source; breakpoints } ->
      server.breakpoints := breakpoints;
      Response { verified: true }

  | Continue ->
      run_until_breakpoint server.runtime;
      Response { allThreadsContinued: true }

  | StepIn ->
      step_into server.runtime;
      Event (Stopped { reason: "step"; threadId: 1 })

  | Evaluate { expression; context } ->
      let result = eval_in_context server.runtime expression context in
      Response { result: format_result result; variablesReference: 0 }

  | Scopes { frameId } ->
      let frame = get_frame server.runtime frameId in
      Response {
        scopes: [
          { name: "Constellation"; variablesReference: frame.const_id };
          { name: "Variables"; variablesReference: frame.vars_id };
          { name: "Queue"; variablesReference: frame.queue_id }
        ]
      }
```

### Visual Debugging Tools

#### 1. Terminal UI (TUI) Debugger

```
╔════════════════════════════════════════════════════════════════════╗
║ Stellogen Debugger - add.sg                                        ║
╠════════════════════════════════════════════════════════════════════╣
║ Source                          │ Constellation State              ║
║                                 │                                  ║
║ 3  (:= add {                    │ add {                           ║
║ 4    [(+add 0 Y Y)]             │   ✓ [(+add 0 Y Y)]              ║
║►5    [(-add X Y Z)              │   ► [(-add X Y Z)               ║
║ 6     (+add (s X) Y (s Z))]})   │      (+add (s X) Y (s Z))]     ║
║                                 │ }                                ║
║                                 │                                  ║
║ Breakpoint at line 5            │ Interaction Queue:               ║
║                                 │   1. (-add (s 0) (s 0) R)       ║
╠════════════════════════════════════════════════════════════════════╣
║ Variables                       │ Interaction                      ║
║                                 │                                  ║
║ X = (s 0)                       │ Positive: (+add (s X) Y (s Z))  ║
║ Y = (s 0)                       │ Negative: (-add (s 0) (s 0) R)  ║
║ Z = R                           │                                  ║
║                                 │ Unification:                     ║
║ Substitution:                   │   X = (s 0) ✓                   ║
║   {X ↦ (s 0), Y ↦ (s 0), Z ↦ R}│   Y = (s 0) ✓                   ║
║                                 │   Z = R     ✓                   ║
╠════════════════════════════════════════════════════════════════════╣
║ [C]ontinue [S]tep [N]ext [O]ut [Q]uit                             ║
╚════════════════════════════════════════════════════════════════════╝
```

#### 2. Graphical Debugger

**Constellation Graph View:**

```
        ┌─────────────────┐
        │  (-add X Y Z)   │
        │   [ACTIVE]      │
        └────────┬────────┘
                 │ interacts with
                 ↓
        ┌─────────────────┐
        │  (+add 0 Y Y)   │
        │   [MATCHED]     │
        └─────────────────┘

        ┌─────────────────┐
        │ (+add (s X) Y   │
        │      (s Z))     │ ← continuation
        │   [PENDING]     │
        └─────────────────┘
```

**Interaction Timeline:**

```
Time ──────────────────────────────────────────────────────→

Step 1: Query entered
        │
        ▼
Step 2: Match found
        │
        ▼
Step 3: Unification
        │     X = (s 0)
        │     Y = (s 0)
        │     Z = R
        ▼
Step 4: Generate continuation
        │
        ▼
Step 5: New interaction
        ...
```

**Term Inspector:**

```
Term: (+add (s 0) (s 0) R)
├─ Functor: add
├─ Polarity: +
└─ Arguments:
   ├─ [0]: (s 0)
   │   ├─ Functor: s
   │   └─ Arguments:
   │      └─ [0]: 0 (atom)
   ├─ [1]: (s 0)
   │   ├─ Functor: s
   │   └─ Arguments:
   │      └─ [0]: 0 (atom)
   └─ [2]: R (unbound variable)
```

#### 3. Web-Based Debugger

**Interactive playground with debugging:**

```html
<div id="stellogen-debugger">
  <div class="editor">
    <textarea id="code">
(:= add {
  [(+add 0 Y Y)]
  [(-add X Y Z) (+add (s X) Y (s Z))]})
    </textarea>
  </div>

  <div class="visualization">
    <canvas id="constellation-graph"></canvas>
  </div>

  <div class="controls">
    <button id="step">Step</button>
    <button id="continue">Continue</button>
    <button id="reset">Reset</button>
  </div>

  <div class="state">
    <h3>Current State</h3>
    <div id="variables"></div>
    <div id="queue"></div>
  </div>
</div>
```

**Features:**
- Live code editing
- Interactive constellation visualization
- Step through interactions
- Inspect variables and terms
- Export interaction trace

### Debugging Examples

#### Example 1: Debugging Type Check Failure

**Code:**

```stellogen
(spec nat {
  [(-nat 0) ok]
  [(-nat (s N)) (+nat N)]})

(:= bad (+nat []))  ' Bug: [] is not a nat
(:: bad nat)
```

**Debug session:**

```
[Debugger] Starting type check for 'bad'
[Step 1] Evaluating: (:: bad nat)
[Step 2] Expanding macro: (== @(exec @#bad #nat) ok)
[Step 3] Focusing @#bad → (+nat [])
[Step 4] Loading #nat → { [(-nat 0) ok], [(-nat (s N)) (+nat N)] }
[Step 5] Scheduling interaction: (+nat []) with #nat

[Breakpoint] Interaction about to occur
  Positive: (+nat [])
  Available stars in nat:
    [(-nat 0) ok]          ← Does not match (0 ≠ [])
    [(-nat (s N)) ...]     ← Does not match (s N ≠ [])

[Error] No matching star found for (+nat [])
  Expected: (+nat 0) or (+nat (s N))
  Got: (+nat [])

  Suggestion: [] is a list, not a natural number.
  Did you mean: (+nat 0) ?
```

#### Example 2: Debugging Infinite Interaction

**Code:**

```stellogen
(:= loop {
  [(-loop X) (+loop X)]})  ' Bug: infinite loop

(exec #loop @#start)
```

**Debug session:**

```
[Debugger] Interaction started
[Step 1] (-loop start) interacts with [(+loop X)]
[Step 2] Unify: X = start
[Step 3] Continue: (+loop start)
[Step 4] (+loop start) interacts with [(-loop X)]
[Step 5] Unify: X = start
[Step 6] Continue: (-loop start)
[Step 7] (-loop start) interacts with [(+loop X)]
...

[Warning] Detected potential infinite loop
  Pattern: (-loop start) → (+loop start) → (-loop start) → ...
  Iterations: 1000

  [D]ebug [A]bort [C]ontinue

> d

[Debugger] Entering debug mode
  Interaction history:
    1. (-loop start) ← initial
    2. (+loop start) ← from star [(+loop X)]
    3. (-loop start) ← from star [(-loop X)]
    4. (+loop start) ← from star [(+loop X)]
    ... (cycle detected)

  Problem: Star [(-loop X) (+loop X)] creates cycle
  Solution: Change polarity or add termination condition
```

#### Example 3: Debugging Complex Interaction

**Code:**

```stellogen
(:= add {
  [(+add 0 Y Y)]
  [(-add X Y Z) (+add (s X) Y (s Z))]})

(:= query [(-add <s s 0> <s s 0> R) R])
(show (exec #add @#query))
```

**Debug session with visualization:**

```
[Debugger] Interaction started
[Breakpoint] Constellation 'add' entry

Constellation State:
  add {
    ✓ [(+add 0 Y Y)]
    ✓ [(-add X Y Z) (+add (s X) Y (s Z))]
  }

Query: [(-add (s (s 0)) (s (s 0)) R) R]

[Step Into] First interaction

  Match: [(-add X Y Z) (+add (s X) Y (s Z))]

  Unification:
    Pattern: (-add X Y Z)
    Query:   (-add (s (s 0)) (s (s 0)) R)
    Result:
      X = (s (s 0))
      Y = (s (s 0))
      Z = R

  Continuation:
    (+add (s (s (s 0))) (s (s 0)) (s R))

  [Watch] R
    Before: _unbound_
    After: _unbound_ (but Z = R)
    Note: R will be bound when Z is bound

[Step] Next interaction

  Match: [(-add X Y Z) (+add (s X) Y (s Z))]

  ... (continue debugging)
```

### Debugging Performance

**Impact on execution speed:**

| Mode | Relative Speed | Use Case |
|------|---------------|----------|
| **Production** | 100% (baseline) | Deployed code |
| **Debug symbols** | 95-98% | Release with symbols |
| **No optimization** | 50-70% | Debug build |
| **Step-by-step** | 1-10% | Active debugging |
| **Full trace** | 0.1-1% | Maximum introspection |

**Trade-off:** Debug builds are slower, but essential for development.

### Debugging Best Practices

1. **Always compile with debug info** in development
2. **Use watch expressions** to track variable evolution
3. **Visualize constellation state** to understand interactions
4. **Enable interaction tracing** for complex bugs
5. **Set conditional breakpoints** to catch specific cases
6. **Use assertion checks** in constellations
7. **Test with debugger attached** to catch errors early

### Integration with Development Tools

#### VS Code Extension

```json
{
  "name": "stellogen-debug",
  "contributes": {
    "debuggers": [{
      "type": "stellogen",
      "label": "Stellogen Debugger",
      "program": "./out/debugAdapter.js",
      "configurationAttributes": {
        "launch": {
          "required": ["program"],
          "properties": {
            "program": {
              "type": "string",
              "description": "Path to Stellogen file"
            }
          }
        }
      }
    }],
    "breakpoints": [
      { "language": "stellogen" }
    ]
  }
}
```

#### Command-Line Debugger

```bash
# Start debugger
sgen debug program.sg

# With breakpoint
sgen debug --break add:5 program.sg

# With watch
sgen debug --watch X,Y,Z program.sg

# Trace mode
sgen debug --trace program.sg
```

#### REPL with Debugging

```stellogen
stellogen> :debug on
[Debugger enabled]

stellogen> (exec #add @#query)
[Breakpoint] Entering constellation 'add'

(debug) :step
[Step 1] Matching (-add (s (s 0)) (s (s 0)) R)

(debug) :inspect R
R = _unbound_

(debug) :continue
Result: (s (s (s (s 0))))

(debug) :history
1. (-add (s (s 0)) (s (s 0)) R)
2. (+add (s 0) (s (s 0)) (s R))
3. (+add 0 (s (s 0)) (s (s R)))
4. Result: R = (s (s (s (s 0))))
```

---

## Comparison and Trade-Offs

### Compilation Targets

| Target | Pros | Cons | Suitability | Debuggability |
|--------|------|------|-------------|---------------|
| **BIM (Custom VM)** | Optimized for Stellogen, full control, efficient | Must implement VM, limited portability | ⭐⭐⭐⭐⭐ Best fit | ⭐⭐⭐⭐⭐ Excellent |
| **WAM (Adapted)** | Proven design, optimization techniques | Designed for backtracking, needs heavy modification | ⭐⭐⭐ Possible but awkward | ⭐⭐⭐⭐ Good |
| **Wasm (Direct)** | Portable, fast, standardized | Complex to implement, manual memory management | ⭐⭐ Possible but difficult | ⭐⭐⭐ Good with source maps |
| **Wasm (BIM interp)** | Portable, simpler than direct | Interpretation overhead | ⭐⭐⭐ Reasonable compromise | ⭐⭐⭐⭐ Very good |
| **Wasm (Native runtime)** | Reuses existing code, easier | Not fully portable, boundary overhead | ⭐⭐⭐⭐ Good for hybrid approach | ⭐⭐⭐⭐ Very good |

### Debugging Capabilities

| Approach | Source Mapping | Step Debugging | Inspection | Visualization | Integration |
|----------|---------------|----------------|------------|---------------|-------------|
| **Interpreter** | Native | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| **BIM Bytecode** | Via debug info | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **Native (JIT)** | DWARF/symbols | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ |
| **Wasm** | Source maps | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ |

### Implementation Complexity

```
Direct Interpretation (current) ────────┐
                                        │ Lowest complexity
Compile to BIM bytecode ────────────────┤
                                        │
BIM interpreter ────────────────────────┤
                                        │
Adapt WAM ──────────────────────────────┤
                                        │
Compile BIM to Wasm ────────────────────┤
                                        │
Direct Wasm compilation ────────────────┘ Highest complexity
```

### Performance Expectations

**Rough estimates** (relative to current OCaml implementation):

| Approach | Expected Speedup | Notes |
|----------|-----------------|-------|
| **Optimized interpreter** | 1-2x | Better data structures, less allocation |
| **BIM bytecode + interpreter** | 2-5x | Eliminate OCaml overhead, better dispatch |
| **BIM JIT compilation** | 5-10x | Native code generation |
| **Wasm (interpreted BIM)** | 1-3x | Wasm JIT helps, but interpretation overhead |
| **Wasm (direct)** | 3-10x | If implemented well, near-native |

### Portability

| Approach | Portability | Notes |
|----------|-------------|-------|
| **OCaml native** | Medium | Must compile for each platform |
| **OCaml bytecode** | High | Runs on any platform with OCaml runtime |
| **BIM bytecode** | High | Need BIM VM for each platform |
| **BIM + JIT** | Medium | JIT backends for each architecture |
| **Wasm** | Very High | Runs in browsers, Node.js, standalone runtimes |

---

## Recommendation

### Phased Approach

Rather than choosing one target, implement multiple stages:

#### Phase 1: Optimize Current Implementation (Short-term)

**Goal:** 2x speedup with minimal changes

**Actions:**
1. Profile current OCaml implementation
2. Optimize hot paths (unification, lookups)
3. Better data structures (hash tables, arrays)
4. Reduce allocations
5. Add simple constant folding

**Effort:** 1-2 weeks
**Benefit:** Quick wins, better baseline

#### Phase 2: BIM Bytecode (Medium-term)

**Goal:** Design and implement Basic Interaction Machine

**Actions:**
1. Design BIM instruction set (based on this document)
2. Implement BIM assembler (Stellogen → BIM bytecode)
3. Implement BIM interpreter (in OCaml or Rust)
4. Add optimizations (register allocation, constant folding)
5. Benchmark against current implementation

**Effort:** 2-3 months
**Benefit:** 3-5x speedup, better compilation infrastructure

#### Phase 3: Native Code Generation (Long-term)

**Goal:** JIT or AOT compilation to native code

**Options:**

**Option A: JIT via LLVM**
- Compile BIM bytecode to LLVM IR
- Use LLVM JIT to generate native code
- Benefit: Maximum performance (10x+)
- Drawback: Complex, large dependency

**Option B: JIT via Cranelift**
- Compile BIM bytecode to Cranelift IR
- Use Cranelift JIT to generate native code
- Benefit: Fast compilation, good performance
- Drawback: Newer, less proven than LLVM

**Option C: Ahead-of-time compilation**
- Compile Stellogen → BIM → native code
- Bundle with small runtime
- Benefit: No JIT overhead, distributable binaries
- Drawback: No dynamic code loading

**Effort:** 4-6 months
**Benefit:** 5-10x speedup, production-ready performance

#### Phase 4: WebAssembly Target (Optional)

**Goal:** Run Stellogen in web browsers

**Actions:**
1. Implement BIM interpreter in Wasm (or compile it to Wasm via Rust)
2. Or: Compile BIM bytecode directly to Wasm
3. Add JavaScript bindings for browser API
4. Create web-based playground

**Effort:** 2-3 months
**Benefit:** Web deployment, sandboxed execution, broad compatibility

### Recommended Stack (with Debugging)

```
┌──────────────────────────────────────┐
│      Stellogen Source Code           │
└──────────────┬───────────────────────┘
               │
               ↓
┌──────────────────────────────────────┐
│    Parser & Preprocessor (OCaml)     │
│    + Source Location Tracking        │
└──────────────┬───────────────────────┘
               │
               ↓
┌──────────────────────────────────────┐
│      AST & Type Checking             │
│      + Debug Annotations             │
└──────────────┬───────────────────────┘
               │
               ↓
┌──────────────────────────────────────┐
│   BIM Bytecode Compiler (OCaml)      │
│   - Constellation lowering           │
│   - Register allocation              │
│   - Optimization passes              │
│   + Debug Info Generation            │
└──────────────┬───────────────────────┘
               │
               ↓
┌──────────────────────────────────────┐
│   BIM Bytecode (.bim) + Debug Info   │
│   (.bim.debug or embedded)           │
└──────────────┬───────────────────────┘
               │
        ┌──────┴──────┬──────────────┬────────────┐
        │             │              │            │
        ↓             ↓              ↓            ↓
   ┌────────┐   ┌─────────┐   ┌─────────┐  ┌──────────┐
   │  BIM   │   │ LLVM    │   │Cranelift│  │   Wasm   │
   │Interp. │   │ JIT     │   │ JIT     │  │  Module  │
   │+Debug  │   │+DWARF   │   │+Debug   │  │+SourceMap│
   │(OCaml) │   │(Native) │   │(Native) │  │ (Browser)│
   └────┬───┘   └────┬────┘   └────┬────┘  └─────┬────┘
        │            │             │             │
        └────────────┴─────────────┴─────────────┘
                     │
                     ↓
        ┌─────────────────────────────┐
        │    Debug Adapter/Server     │
        │    (DAP Protocol)           │
        └──────────────┬──────────────┘
                       │
                       ↓
        ┌─────────────────────────────┐
        │  Debugger Frontend          │
        │  - VS Code Extension        │
        │  - CLI Debugger             │
        │  - Web Debugger             │
        │  - REPL with Debug          │
        └─────────────────────────────┘
```

### Why This Approach?

1. **Incremental:** Each phase builds on previous work
2. **Testable:** Can validate each stage independently
3. **Flexible:** Multiple backends for different use cases
4. **Pragmatic:** Quick wins early, sophisticated optimizations later
5. **Research-friendly:** BIM bytecode is intermediate representation for experiments
6. **Debuggable:** Debug info maintained through all compilation stages
7. **Developer-friendly:** Good debugging experience from day one

---

## Conclusion

### Summary

**The Core Insight:** Stellogen is fundamentally about scheduling term unification with polarity.

**Three Compilation Strategies:**

1. **Basic Interaction Machine (BIM)**: Custom abstract machine optimized for Stellogen
   - Best fit for Stellogen's semantics
   - Complete control over design
   - Can be optimized specifically for polarity-based interaction

2. **Warren Abstract Machine (WAM)**: Adapt Prolog's proven design
   - Excellent unification techniques
   - But: designed for backtracking, not polarity interaction
   - Would require significant modifications

3. **WebAssembly (Wasm)**: Compile to portable bytecode
   - Maximum portability (browsers, servers, edge)
   - Standardized, well-supported
   - But: complex to implement directly, requires manual memory management

### Recommended Path

**Phased implementation:**

1. **Phase 1**: Optimize current OCaml implementation (quick wins)
2. **Phase 2**: Design and implement BIM (core compilation infrastructure)
3. **Phase 3**: Add native code generation via JIT (performance)
4. **Phase 4**: Target WebAssembly (portability)

### The Basic Interaction Machine

The BIM should be the primary compilation target because:

- **Tailored to Stellogen**: Designed for polarity-based interaction
- **Simple**: Fewer instructions than WAM (no backtracking)
- **Efficient**: Optimized for set-based constellations
- **Extensible**: Easy to add new instructions
- **Intermediate**: Good target for further compilation (to native or Wasm)

### Key Design Decisions

1. **Unification-first**: Core instruction set for term unification
2. **Polarity-aware**: First-class support for positive/negative terms
3. **Set-based execution**: Constellations are sets, not sequences
4. **Explicit scheduling**: Interaction queue manages pending work
5. **No backtracking**: Simpler than WAM, matches Stellogen semantics

### Next Steps

1. **Prototype BIM**: Implement core instruction set and interpreter
2. **Add debug hooks**: Instrument interpreter for debugging
3. **Implement debug info**: Source location tracking, variable mapping
4. **Build simple debugger**: CLI or TUI for basic debugging
5. **Compile simple examples**: Test with basic Stellogen programs
6. **Measure performance**: Compare against current implementation
7. **Iterate on design**: Refine instruction set based on experience
8. **Add optimizations**: Register allocation, constant folding, inlining (with debug info preservation)
9. **Build DAP adapter**: Enable VS Code integration
10. **Consider JIT**: Evaluate LLVM or Cranelift for native code generation (with debug support)
11. **Explore Wasm**: Port BIM interpreter to Wasm for web deployment (with source maps)

### Final Thoughts

**On Compilation:**

The key insight is that Stellogen's execution model—**polarity-based term interaction**—is different enough from Prolog (backtracking search) and functional languages (lambda calculus) that it deserves its own abstract machine.

The Basic Interaction Machine captures the essence of Stellogen's computational model in a simple, efficient instruction set that can serve as a foundation for optimization, JIT compilation, and exploration of Stellogen's unique execution semantics.

**On Debugging:**

A compiler without debugging support is only half-useful. Debugging is not an afterthought—it should be designed in from the start:

1. **Track source locations** from the very beginning
2. **Generate debug info** at every compilation stage
3. **Preserve variable names** even in optimized code
4. **Provide visualization tools** for Stellogen's unique features (polarity, constellations, interactions)
5. **Support multiple debugging interfaces** (CLI, GUI, web, editor integration)

The BIM bytecode format, combined with rich debug information, enables excellent debugging experiences while still allowing aggressive optimization when needed (debug vs release builds).

**The Complete Picture:**

```
Good Performance + Good Debugging = Practical Language

Stellogen should be:
  - Fast enough for real programs (via compilation)
  - Easy enough to debug (via debug info & tools)
  - Flexible enough for experiments (via bytecode IR)
  - Portable enough for deployment (via Wasm)
```

---

## Appendices

### Appendix A: BIM Instruction Reference

Complete instruction set for the Basic Interaction Machine.

#### Term Construction

| Instruction | Encoding | Description |
|-------------|----------|-------------|
| `BUILD_ATOM c → T` | `0x01 c` | Build atom with value c |
| `BUILD_VAR X → T` | `0x02` | Create fresh variable |
| `BUILD_STRUCT f/n T1...Tn → T` | `0x03 f n` | Build structure f(T1,...,Tn) |
| `BUILD_LIST H T → L` | `0x04` | Build list [H\|T] |
| `BUILD_NIL → L` | `0x05` | Build empty list [] |

#### Unification

| Instruction | Encoding | Description |
|-------------|----------|-------------|
| `UNIFY T1 T2 → subst` | `0x10` | Unify two terms |
| `APPLY_SUBST subst T → T'` | `0x11` | Apply substitution |
| `CAN_UNIFY T1 T2 → bool` | `0x12` | Test unifiability |

#### Polarity

| Instruction | Encoding | Description |
|-------------|----------|-------------|
| `SET_POL + T` | `0x20 0` | Set positive polarity |
| `SET_POL - T` | `0x20 1` | Set negative polarity |
| `SET_POL 0 T` | `0x20 2` | Set neutral polarity |
| `GET_POL T → pol` | `0x21` | Get polarity |
| `ARE_COMPL pol1 pol2 → bool` | `0x22` | Check complementarity |

#### Constellation

| Instruction | Encoding | Description |
|-------------|----------|-------------|
| `LOAD_CONST id → const` | `0x30 id` | Load constellation by name |
| `FIND_STARS const T → list` | `0x31` | Find matching stars |
| `ADD_STAR const star` | `0x32` | Add star to constellation |
| `REMOVE_STAR const star` | `0x33` | Remove star (linear) |

#### Interaction

| Instruction | Encoding | Description |
|-------------|----------|-------------|
| `SCHEDULE T1 T2` | `0x40` | Add to interaction queue |
| `INTERACT T1 T2 → terms` | `0x41` | Execute interaction |
| `SET_MODE linear` | `0x42 0` | Fire mode |
| `SET_MODE nonlinear` | `0x42 1` | Interact mode |

#### Control

| Instruction | Encoding | Description |
|-------------|----------|-------------|
| `CALL label` | `0x50 addr` | Function call |
| `RETURN` | `0x51` | Return from function |
| `BRANCH_IF_FAIL label` | `0x52 addr` | Conditional branch |
| `JUMP label` | `0x53 addr` | Unconditional jump |
| `HALT` | `0xFF` | Stop execution |

### Appendix B: WAM vs BIM Comparison

| Feature | WAM | BIM |
|---------|-----|-----|
| **Target language** | Prolog | Stellogen |
| **Execution model** | Backtracking search | Polarity interaction |
| **Control flow** | Depth-first + backtracking | Interaction queue |
| **Choice points** | Yes (stack of alternatives) | No (no backtracking) |
| **Trail** | Yes (undo bindings) | No (bindings permanent) |
| **Polarity** | No | Yes (core feature) |
| **Constellations** | Ordered clauses | Unordered sets |
| **Unification** | Yes | Yes (same) |
| **Registers** | Many (A1-An, X1-Xm) | Fewer (T1-Tn) |
| **Instruction count** | ~50 | ~30 |
| **Complexity** | High | Medium |

### Appendix C: Example BIM Programs

**Example 1: Simple type checking**

```
' Define nat type
DEFINE_NAT:
    BUILD_ATOM 0 → T1
    BUILD_STRUCT nat/1 T1 → S1
    SET_POL - S1
    BUILD_ATOM ok → T2
    BUILD_CONJ S1 T2 → STAR1
    ADD_STAR nat STAR1
    RETURN

' Check zero : nat
CHECK_ZERO:
    BUILD_ATOM 0 → T1
    BUILD_STRUCT nat/1 T1 → T2
    SET_POL + T2
    LOAD_CONST nat → C1
    SCHEDULE T2 C1
    CALL MAIN_LOOP
    RETURN
```

**Example 2: List append**

```
' Define append
DEFINE_APPEND:
    ' append([], L, L)
    BUILD_NIL → T1
    BUILD_VAR L → T2
    BUILD_VAR L → T3
    BUILD_STRUCT append/3 T1 T2 T3 → S1
    SET_POL + S1
    ADD_STAR append S1

    ' append([H|T1], L, [H|T2]) :- append(T1, L, T2)
    BUILD_VAR H → T1
    BUILD_VAR T1 → T2
    BUILD_LIST T1 T2 → L1
    BUILD_VAR L → T3
    BUILD_VAR T2 → T4
    BUILD_LIST T1 T4 → L2
    BUILD_STRUCT append/3 L1 T3 L2 → S2
    SET_POL - S2
    BUILD_STRUCT append/3 T2 T3 T4 → S3
    SET_POL + S3
    BUILD_CONJ S2 S3 → STAR2
    ADD_STAR append STAR2
    RETURN
```

### Appendix D: Further Reading

**Warren Abstract Machine:**
- Warren, D. H. D. (1983). "An Abstract Prolog Instruction Set"
- Ait-Kaci, H. (1991). "Warren's Abstract Machine: A Tutorial Reconstruction"
- Tarau, P. (2017). "The BinProlog Experience: Architecture and Implementation Choices for Continuation Passing Prolog and First-Class Logic Engines"

**Interaction Nets:**
- Lafont, Y. (1990). "Interaction Nets"
- Mackie, I. (2011). "Interaction Nets: Semantics and Concurrent Extensions"
- Fernández, M., & Mackie, I. (1999). "A Calculus for Interaction Nets"

**Abstract Machines:**
- Diehl, S., et al. (2000). "Abstract Machines for Programming Language Implementation"
- Leroy, X. (1990). "The ZINC Experiment"
- Landin, P. J. (1964). "The Mechanical Evaluation of Expressions" (SECD machine)

**WebAssembly:**
- WebAssembly Specification: https://webassembly.github.io/spec/
- WebAssembly GC Proposal: https://github.com/WebAssembly/gc
- Haas, A., et al. (2017). "Bringing the Web up to Speed with WebAssembly"

**Compilation Techniques:**
- Appel, A. W. (2004). "Modern Compiler Implementation in ML"
- Muchnick, S. S. (1997). "Advanced Compiler Design and Implementation"
- Aho, A. V., et al. (2006). "Compilers: Principles, Techniques, and Tools" (Dragon Book)

---

---

## Appendix E: Debug Information Format

### BIM Debug Info Format (.bim.debug)

```
Header:
  magic: 0x42494D44 ("BIMD")
  version: 1
  source_file_count: N

Source Files Section:
  file[0]:
    path: "add.sg"
    hash: SHA256(...)
  file[1]:
    path: "nat.sg"
    hash: SHA256(...)
  ...

Location Map Section:
  entry[0]:
    bytecode_offset: 0x0000
    source_file: 0
    line: 3
    column: 5
  entry[1]:
    bytecode_offset: 0x0004
    source_file: 0
    line: 4
    column: 3
  ...

Variable Map Section:
  entry[0]:
    name: "X"
    scope: constellation(add, star(1))
    location:
      type: register
      register: T1
    source_location:
      file: 0
      line: 5
      column: 10
  entry[1]:
    name: "Y"
    scope: constellation(add, star(1))
    location:
      type: register
      register: T2
    source_location:
      file: 0
      line: 5
      column: 12
  ...

Constellation Map Section:
  entry[0]:
    name: "add"
    bytecode_range: [0x0000, 0x0100]
    source_location:
      file: 0
      line: 3
      column: 5
    stars:
      star[0]:
        bytecode_range: [0x0004, 0x0020]
        source_location:
          file: 0
          line: 4
          column: 3
      star[1]:
        bytecode_range: [0x0024, 0x0080]
        source_location:
          file: 0
          line: 5
          column: 3
  ...

Type Information Section:
  type[0]:
    name: "term"
    size: 8
    alignment: 8
  type[1]:
    name: "polarity"
    values: [positive, negative, neutral]
  ...
```

### Debug API

```ocaml
(* Debug information API *)
module DebugInfo : sig
  type t

  (* Load debug info from file *)
  val load : string -> t option

  (* Query functions *)
  val get_source_location : t -> pc:int -> source_location option
  val get_variable_name : t -> register:int -> scope:scope -> string option
  val get_constellation_name : t -> pc:int -> string option
  val get_variables_in_scope : t -> pc:int -> (string * location) list

  (* Reverse lookups *)
  val find_bytecode_offset : t -> source_location -> int option
  val find_constellation : t -> name:string -> constellation_info option
end
```

---

**Document Version:** 2.0
**Last Updated:** 2025-10-12
**Author:** Analysis of compilation strategies, abstract machines, and debugging for Stellogen
