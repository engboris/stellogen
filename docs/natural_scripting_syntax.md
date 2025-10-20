# Natural Scripting Syntax in Stellogen: Beyond `#(...)`

> **Disclaimer**: This document represents exploratory research and design proposals. The content may contain speculative ideas that require further validation through prototyping and community feedback.

**Status:** Research Document / Design Proposal
**Date:** 2025-10-14
**Purpose:** Explore mechanisms for more natural scripting syntax in Stellogen, eliminating the need for `#(...)` notation by leveraging system declarations (similar to Racket's `#lang`)

**Related:**
- [System Locking and Internal DSLs](./system_locking_and_internal_dsls.md)
- [examples/automata.sg](../examples/automata.sg)
- [GitHub Issue #20](https://github.com/engboris/stellogen/issues/20)

---

## Table of Contents

1. [Introduction](#introduction)
2. [The Current Pattern: Parametric Variables with `#(...)`](#the-current-pattern-parametric-variables-with-)
3. [The Vision: Natural Scripting](#the-vision-natural-scripting)
4. [Design Approaches](#design-approaches)
5. [System Declarations: The `#lang`-Style Approach](#system-declarations-the-lang-style-approach)
6. [Implementation Strategies](#implementation-strategies)
7. [Examples Across Domains](#examples-across-domains)
8. [Trade-offs and Considerations](#trade-offs-and-considerations)
9. [Roadmap](#roadmap)
10. [Conclusion](#conclusion)

---

## Introduction

### The Problem

In current Stellogen, when building domain-specific patterns using parametric variables, we must use the `#(...)` syntax to reference them. Consider the automata example from `examples/automata.sg`:

```stellogen
' Define parametric variables
(:= (initial Q) [(-i W) (+a W Q)])
(:= (accept Q) [(-a [] Q) accept])
(:= (if read C1 on Q1 then Q2) [(-a [C1|W] Q1) (+a W Q2)])

' Use them with #(...) notation
(:= a1 {
  #(initial q0)
  #(accept q2)
  #(if read 0 on q0 then q0)
  #(if read 0 on q0 then q1)
  #(if read 1 on q0 then q0)
  #(if read 0 on q1 then q2)})
```

**Issues with this approach:**

1. **Visual noise**: The `#(...)` wrapper adds syntactic overhead
2. **Cognitive friction**: Breaks the natural reading flow
3. **DSL feel broken**: Doesn't feel like a dedicated language
4. **Mixed metaphors**: Switches between "defining pattern" and "using pattern" modes explicitly

**What we'd prefer:**

```stellogen
' Imagine this instead
automaton a1 {
  initial q0
  accept q2
  if read 0 on q0 then q0
  if read 0 on q0 then q1
  if read 1 on q0 then q0
  if read 0 on q1 then q2
}
```

Or even more radically:

```stellogen
#system automaton

initial q0
accept q2
if read 0 on q0 then q0
if read 0 on q0 then q1
if read 1 on q0 then q0
if read 0 on q1 then q2
```

### The Opportunity

Stellogen's philosophy of **user-driven semantics** and **logic-agnostic foundations** makes it uniquely positioned to support **multiple scripting surfaces** over the same underlying machinery. Combined with the **system locking** proposal, we can create:

1. **Natural DSL syntax** for specific domains
2. **Automatic transformation** of DSL code into underlying Stellogen
3. **System-specific semantics** without breaking the core language
4. **Gradual migration** between script-style and explicit-style code

---

## The Current Pattern: Parametric Variables with `#(...)`

### How It Works Today

**Step 1: Define parametric "macros" with `:=`**

```stellogen
(:= (initial Q) [(-i W) (+a W Q)])
```

This creates a parametric definition where `Q` is a parameter. When called as `(initial q0)`, it produces `[(-i W) (+a W q0)]`.

**Step 2: Reference them with `#(...)` inside constellations**

```stellogen
(:= a1 {
  #(initial q0)
  #(accept q2)
  #(if read 0 on q0 then q0)
})
```

The `#(...)` syntax:
- Indicates a reference to a defined term
- Triggers evaluation/substitution of the parametric definition
- Returns the expanded result to be included in the constellation

### Why `#(...)` is Currently Necessary

The `#` prefix serves several purposes:

1. **Disambiguation**: Distinguishes between literal terms and references
   ```stellogen
   {
     (initial q0)      ' Literal term: the pattern itself
     #(initial q0)     ' Reference: evaluate and substitute
   }
   ```

2. **Evaluation control**: Signals when to perform substitution
   ```stellogen
   ' Without #: just a pattern
   (initial q0)

   ' With #: expand the definition
   #(initial q0)  ; → [(-i W) (+a W q0)]
   ```

3. **Scope clarity**: Makes clear what's in the "definition language" vs "use language"

### The Cognitive Overhead

For domain-specific code (like automata, state machines, business rules), the `#(...)` syntax:

- **Breaks immersion**: Constantly reminds you of the metaprogramming layer
- **Reduces readability**: Harder to scan and understand at a glance
- **Creates verbosity**: Adds 2 characters per reference
- **Obscures intent**: Focus on mechanism rather than meaning

**Example comparison:**

```stellogen
' Current (with #)
(:= traffic-light {
  #(state red on timer-expire goto green)
  #(state green on timer-expire goto yellow)
  #(state yellow on timer-expire goto red)
})

' Desired (without #)
(within-system state-machine
  state red on timer-expire goto green
  state green on timer-expire goto yellow
  state yellow on timer-expire goto red
)
```

---

## The Vision: Natural Scripting

### What "Natural" Means

A **natural scripting syntax** for Stellogen would:

1. **Read like the domain**: Use domain vocabulary directly
2. **Minimize metacircular noise**: Avoid explicit reference markers
3. **Feel declarative**: State what you want, not how to construct it
4. **Compose naturally**: Work with other Stellogen code seamlessly
5. **Preserve power**: Don't sacrifice the underlying flexibility

### Design Goals

1. **Transparency**: DSL code transforms cleanly to core Stellogen
2. **Debuggability**: Can see/inspect the transformed code
3. **Opt-in**: Don't break existing code; provide migration path
4. **Flexibility**: Support multiple DSLs/systems simultaneously
5. **Performance**: Transformations happen at compile-time

### Inspiration: Racket's `#lang`

Racket pioneered **language-oriented programming** with `#lang`:

```racket
#lang datalog

parent(tom, bob).
parent(bob, ann).

grandparent(X, Z) :- parent(X, Y), parent(Y, Z).
```

**Key features:**
- File starts with `#lang <language-name>`
- Custom reader transforms syntax
- Different semantics per language
- Still compiles to Racket core

**Stellogen equivalent vision:**

```stellogen
#system automaton

initial q0
accept q2
if read 0 on q0 then q0
```

Or with scoped systems:

```stellogen
(within-system automaton
  initial q0
  accept q2
  if read 0 on q0 then q0
)
```

---

## Design Approaches

### Approach 1: System-Scoped Implicit References

**Idea:** Within a system scope, all forms matching system vocabulary are automatically treated as references.

**Syntax:**

```stellogen
' Define the system's vocabulary
(defsystem automaton
  :vocabulary [initial accept if read on then]
  :expansions {
    [(initial Q) → [(-i W) (+a W Q)]]
    [(accept Q) → [(-a [] Q) accept]]
    [(if read C on Q1 then Q2) → [(-a [C|W] Q1) (+a W Q2)]]
  }

  ' Body uses vocabulary without #
  (within-system automaton
    (automaton a1 {
      (initial q0)
      (accept q2)
      (if read 0 on q0 then q0)
      (if read 0 on q0 then q1)
    })
  ))
```

**How it works:**
1. Parser sees `within-system automaton`
2. Activates automaton system's vocabulary
3. Any form starting with system keywords → automatic expansion
4. `(initial q0)` → treated as `#(initial q0)` implicitly

**Pros:**
- Clean syntax
- Clear system boundaries
- Gradual adoption (can mix with regular code)

**Cons:**
- Requires tracking system context during parsing
- Potential ambiguity with local definitions

### Approach 2: File-Level System Declaration

**Idea:** Declare system at file start, entire file uses that system's rules.

**Syntax:**

```stellogen
#system automaton

' Define automaton vocabulary
initial q0
accept q2
if read 0 on q0 then q0
if read 0 on q0 then q1

' Automatically transformed to:
'   {:= a1 {
'     #(initial q0)
'     #(accept q2)
'     ...
'   }}
```

**How it works:**
1. Parser reads `#system automaton` at file start
2. Loads automaton system definition (from library or file)
3. Entire file parsed according to system's grammar
4. Transformed to core Stellogen before evaluation

**Pros:**
- Maximum clarity: entire file is one DSL
- Simplest mental model
- Best for pure domain code

**Cons:**
- Less flexible (one system per file)
- Harder to mix different systems
- Requires system definition elsewhere

### Approach 3: Block-Level System Activation

**Idea:** Activate system for a specific block/constellation.

**Syntax:**

```stellogen
' Define vocabulary elsewhere
(use "automaton-dsl.sg")

' Use it in a block
(constellation a1 @ automaton {
  initial q0
  accept q2
  if read 0 on q0 then q0
})

' Or with special syntax
[automaton:
  initial q0
  accept q2
  if read 0 on q0 then q0
]
```

**How it works:**
1. `@ automaton` marks block as using automaton system
2. Parser applies system's transformations to block contents
3. Result is a normal constellation

**Pros:**
- Fine-grained control
- Multiple systems in one file
- Explicit boundaries

**Cons:**
- Still has some syntax overhead
- Need new syntax for activation

### Approach 4: Syntactic Macros with Context

**Idea:** Extend macro system to support context-aware expansion.

**Syntax:**

```stellogen
' Define context-aware macros
(new-declaration/in-context automaton-block
  (initial Q)
  #(initial Q))

(new-declaration/in-context automaton-block
  (accept Q)
  #(accept Q))

' Use in constellation
(automaton-block {
  (initial q0)
  (accept q2)
})

' Macros automatically add # during expansion
```

**How it works:**
1. Macros declared with context scope
2. Inside `automaton-block`, matching forms auto-expand
3. No explicit # needed by user

**Pros:**
- Uses existing macro system
- Minimal new syntax
- Explicit context control

**Cons:**
- Verbose macro definitions
- Less elegant than system declaration

---

## System Declarations: The `#lang`-Style Approach

Let's explore the most promising approach: **file-level or block-level system declarations**.

### File-Level System Declaration

**File: `my-automaton.sg`**

```stellogen
#system automaton
' or: #lang automaton

' Pure DSL code follows
initial q0
accept q2

if read 0 on q0 then q0
if read 0 on q0 then q1
if read 1 on q0 then q0
if read 0 on q1 then q2

' Could also allow inline test/usage
test with [0 0]  ; accepts
test with [0 1]  ; rejects
```

**System definition file: `stdlib/systems/automaton.sg`**

```stellogen
' Define the automaton system
(defsystem automaton
  :version 1.0
  :description "Finite state automaton DSL"

  ' Vocabulary: what constructs are available?
  :vocabulary [initial accept if read on then test with]

  ' Transformations: DSL → Core Stellogen
  :transforms {
    ' Pattern: (initial Q)
    ' Expands to: [(-i W) (+a W Q)]
    [(initial $Q) → [(-i W) (+a W $Q)]]

    ' Pattern: (accept Q)
    [(accept $Q) → [(-a [] $Q) accept]]

    ' Pattern: (if read C on Q1 then Q2)
    [(if read $C on $Q1 then $Q2) →
     [(-a [$C|W] $Q1) (+a W $Q2)]]
  }

  ' File-level structure: how to organize top-level forms?
  :file-structure {
    ' Collect all top-level forms into a constellation
    (collect-forms $forms →
      {:= automaton {
        #(transform-each $forms)
      }})
  }

  ' Optional: runtime hooks
  :init (use "binary-spec.sg")
  :prelude [(new-declaration (spec X Y) (:= X Y))
            (new-declaration (:: Tested Test) ...)]
)
```

**Loading and transformation:**

```stellogen
' User writes:
#system automaton
initial q0
accept q2
if read 0 on q0 then q0

' Compiler transforms to:
(use "stdlib/systems/automaton.sg")  ; Load system definition
(:= automaton {
  #(initial q0)
  #(accept q2)
  #(if read 0 on q0 then q0)
})
```

### Block-Level System Declaration

For more flexibility, allow system scoping within a file:

```stellogen
' Regular Stellogen code
(:= x 42)
(show x)

' Activate automaton system for this block
(within-system automaton
  initial q0
  accept q2
  if read 0 on q0 then q0
)

' Back to regular Stellogen
(show (exec @#e #automaton))

' Another system in the same file
(within-system state-machine
  state idle
    on start → running

  state running
    on pause → paused
    on stop → idle
)
```

**Advantages:**
- Mix multiple systems in one file
- Clearer boundaries
- Gradual adoption path

### Hybrid: System Declaration + Explicit Reference

Allow both styles to coexist:

```stellogen
#system automaton

' DSL style (implicit)
initial q0
accept q2

' Can still use explicit style when needed
#(if read 0 on q0 then q0)

' Or escape to raw Stellogen
(escape
  (:= debug-flag true)
  (show "Compiling automaton")
)

' Back to DSL style
if read 1 on q0 then q0
```

---

## Implementation Strategies

### Strategy 1: Parser-Level Transformation

**Phase:** Parsing (before AST construction)

```ocaml
(* Parse file *)
let parse_file filename =
  match detect_system_declaration filename with
  | Some system_name ->
      (* Load system definition *)
      let system = load_system system_name in
      (* Parse file with system's grammar *)
      parse_with_system system filename
  | None ->
      (* Standard Stellogen parsing *)
      parse_standard filename

(* System-specific parsing *)
let parse_with_system system filename =
  let forms = parse_forms filename in
  (* Transform each form according to system *)
  let transformed = List.map (transform_form system) forms in
  (* Apply system's file-structure template *)
  system.file_structure transformed
```

**Pros:**
- Clean separation of concerns
- System definitions isolated
- Easy to debug (can inspect transformed AST)

**Cons:**
- Need custom parser per system (potentially)
- More complex build pipeline

### Strategy 2: Macro-Level Transformation

**Phase:** Macro expansion

```stellogen
' System declaration expands to macro definitions
#system automaton

; Expands to:
(begin
  (use "stdlib/systems/automaton.sg")
  (activate-system-macros automaton)

  ' Now system's macros are active
  ' They automatically wrap forms in #(...)
)

' User's DSL code
initial q0

; Macro expansion:
initial q0
  → (initial-macro q0)
  → #(initial q0)
  → [(-i W) (+a W q0)]
```

**Implementation:**

```stellogen
' In automaton system file
(new-declaration/system automaton
  (initial Q)
  #(initial Q))

' When system activated, declarations become active
(activate-system automaton)
' Now (initial q0) → #(initial q0) automatically
```

**Pros:**
- Reuses existing macro system
- No parser changes
- Simpler implementation

**Cons:**
- Macro hygiene challenges
- Harder to control scoping
- May be confusing for debugging

### Strategy 3: AST-Level Transformation

**Phase:** Post-parsing, pre-evaluation

```ocaml
(* Parse to AST *)
let ast = parse_file filename in

(* Detect system annotations *)
match ast with
| Program (SystemDecl system_name :: forms) ->
    (* Load system *)
    let system = load_system system_name in
    (* Transform AST *)
    let transformed_ast = transform_ast system forms in
    (* Evaluate transformed AST *)
    eval transformed_ast

(* Transform AST according to system *)
let transform_ast system forms =
  List.map (fun form ->
    match match_pattern system.transforms form with
    | Some template -> expand_template template form
    | None -> form
  ) forms
```

**Pros:**
- Clean transformation pipeline
- Easy to inspect intermediate results
- System definitions are data

**Cons:**
- Requires AST manipulation infrastructure
- Potential performance overhead

### Strategy 4: Syntactic Extension via Reader

**Phase:** Before lexing (character stream → custom tokens)

```ocaml
(* Custom reader for system *)
let read_with_system system input =
  match system.reader with
  | Some custom_reader ->
      (* System provides custom reader *)
      custom_reader input
  | None ->
      (* Use default reader with system transformations *)
      let tokens = lex input in
      transform_tokens system tokens

(* Main entry point *)
let read_file filename =
  let system = detect_system filename in
  let input = read_file_contents filename in
  read_with_system system input
```

**Pros:**
- Maximum flexibility (can change syntax dramatically)
- True DSL support (not just macro-level)

**Cons:**
- Complex implementation
- Hard to maintain
- Error messages challenging

---

## Examples Across Domains

Let's see how this would work across different domains.

### Domain 1: Finite State Automata

**File: `even-zeros.sg`**

```stellogen
#system automaton

' Accept binary strings with even number of zeros

initial q0
accept q0

' From even state
if read 1 on q0 then q0
if read 0 on q0 then q1

' From odd state
if read 1 on q1 then q1
if read 0 on q1 then q0

' Test cases
test [1 1 1]   expect accept
test [0]       expect reject
test [0 0]     expect accept
test [1 0 1 0] expect accept
```

**Transforms to:**

```stellogen
(use "stdlib/systems/automaton.sg")
(:= even-zeros {
  #(initial q0)
  #(accept q0)
  #(if read 1 on q0 then q0)
  #(if read 0 on q0 then q1)
  #(if read 1 on q1 then q1)
  #(if read 0 on q1 then q0)
})

(:= test-cases [
  {:= t1 (test [1 1 1] #even-zeros)}
  (:: t1 accept)
  ' ... more tests
])
```

### Domain 2: State Machines

**File: `traffic-light.sg`**

```stellogen
#system state-machine

' Traffic light controller
machine traffic-light
  initial red

  state red
    on timer(30s) → green
    emit signal(stop)

  state yellow
    on timer(5s) → red
    emit signal(caution)

  state green
    on timer(25s) → yellow
    on emergency → red
    emit signal(go)
```

**Transforms to:**

```stellogen
(:= traffic-light {
  #(initial-state red)

  #(state red
    [(on (timer 30s) (goto green))]
    [(emit (signal stop))])

  #(state yellow
    [(on (timer 5s) (goto red))]
    [(emit (signal caution))])

  #(state green
    [(on (timer 25s) (goto yellow))]
    [(on emergency (goto red))]
    [(emit (signal go))])
})
```

### Domain 3: Logic Programming (Prolog-style)

**File: `family.sg`**

```stellogen
#system logic

' Family relationships

fact parent(tom, bob)
fact parent(bob, ann)
fact parent(bob, joe)

rule grandparent(X, Z) :-
  parent(X, Y),
  parent(Y, Z)

rule sibling(X, Y) :-
  parent(P, X),
  parent(P, Y),
  X != Y

query grandparent(tom, Z)
query sibling(ann, Who)
```

**Transforms to:**

```stellogen
(:= family-kb {
  #(fact (parent tom bob))
  #(fact (parent bob ann))
  #(fact (parent bob joe))

  #(rule (grandparent X Z)
    [(parent X Y) (parent Y Z)])

  #(rule (sibling X Y)
    [(parent P X) (parent P Y) (!= X Y)])
})

(show (query #family-kb (grandparent tom Z)))
(show (query #family-kb (sibling ann Who)))
```

### Domain 4: Type System DSL

**File: `types.sg`**

```stellogen
#system type-definition

' Define algebraic data types naturally

type nat =
  | zero
  | succ of nat

type list α =
  | nil
  | cons of α * list α

type option α =
  | none
  | some of α

type tree α =
  | leaf
  | node of α * tree α * tree α

' Function type signatures
function add : nat → nat → nat
function map : (α → β) → list α → list β
function fold : (α → β → β) → β → list α → β
```

**Transforms to:**

```stellogen
(spec nat {
  [(-nat zero) ok]
  [(-nat (succ N)) (+nat N)]
})

(spec (list A) {
  [(-list-A nil) ok]
  [(-list-A (cons X Xs)) (+check A X) (+list-A Xs)]
})

' ... etc
```

### Domain 5: Parser Combinators

**File: `json-parser.sg`**

```stellogen
#system parser-combinator

' JSON parser

rule value =
  | object
  | array
  | string
  | number
  | true
  | false
  | null

rule object =
  token lbrace *>
  sep-by pair (token comma) <*
  token rbrace
  where pair = string <* token colon <*> value

rule array =
  token lbracket *>
  sep-by value (token comma) <*
  token rbracket

rule string =
  token quote *>
  many char-except-quote <*
  token quote

rule number =
  optional (token minus) <>
  some digit <>
  optional (token dot <> some digit)
```

**Transforms to:**

```stellogen
(:= json-parser {
  #(parser value
    [(alt object) (alt array) (alt string) ...])

  #(parser object
    [(seq (token lbrace)
          (sep-by pair (token comma))
          (token rbrace))])

  ' ... etc
})
```

### Domain 6: Business Rules

**File: `loan-approval.sg`**

```stellogen
#system business-rules

' Loan approval rules

rule approve-loan
  when
    credit-score > 700
    income > 50000
    debt-to-income < 0.3
  then
    status = approved
    interest-rate = base-rate

rule approve-with-conditions
  when
    credit-score > 650
    credit-score <= 700
    income > 40000
  then
    status = approved
    interest-rate = base-rate + 2%
    require co-signer

rule reject-loan
  when
    credit-score < 650
  then
    status = rejected
    reason = "Credit score too low"
```

**Transforms to:**

```stellogen
(:= loan-rules {
  #(rule approve-loan
    [(condition (> credit-score 700))
     (condition (> income 50000))
     (condition (< debt-to-income 0.3))]
    [(action (set status approved))
     (action (set interest-rate base-rate))])

  ' ... etc
})
```

---

## Trade-offs and Considerations

### Pros of Natural Scripting Syntax

1. **Improved Readability**
   - Code reads like domain language
   - Less syntactic noise
   - Easier for domain experts to understand

2. **Better Developer Experience**
   - Less typing (`initial q0` vs `#(initial q0)`)
   - Faster to write
   - More intuitive for beginners

3. **True DSL Feel**
   - Each domain gets its own "language"
   - Feels like working directly in the domain
   - Can attract domain-specific users

4. **Composition with Systems**
   - Natural fit with system locking proposal
   - Systems define both constraints AND syntax
   - Unified approach to DSL design

5. **Migration Path**
   - Can gradually adopt
   - Existing code still works
   - Can mix styles if needed

### Cons and Challenges

1. **Implementation Complexity**
   - Parser needs system-aware modes
   - Macro system must be extended
   - AST transformations more complex
   - Debugging harder (multiple transformation layers)

2. **Error Messages**
   - Errors may refer to transformed code
   - Need source mapping (DSL → Core)
   - Multiple error reporting strategies needed

3. **Learning Curve**
   - Users need to understand system declarations
   - System definitions themselves are complex
   - May obscure what's actually happening

4. **Performance**
   - Transformation overhead at compile time
   - System loading/activation cost
   - Potential for slower builds

5. **Fragmentation Risk**
   - Too many systems = harder to share code
   - Need standard library of systems
   - Versioning and compatibility issues

6. **Tooling Complexity**
   - Syntax highlighting needs system awareness
   - LSP/IDE support more complex
   - Need system-specific tooling

7. **Debugging Challenges**
   - Which code to show? DSL or transformed?
   - Stepping through transformations
   - Error locations may be ambiguous

### When to Use System Declarations

**Good use cases:**

- **Domain-specific scripts**: Automata, state machines, parsers
- **Configuration files**: Rules, policies, specifications
- **Embedded languages**: SQL-like queries, regex-like patterns
- **High-level modeling**: Business logic, workflows

**Bad use cases:**

- **General programming**: Better to use core Stellogen
- **One-off code**: Overhead not worth it
- **Performance-critical**: Transformation overhead matters
- **Simple tasks**: `#(...)` is fine

### Gradual Adoption Strategy

**Phase 1: Explicit references (current)**
```stellogen
(:= a1 {
  #(initial q0)
  #(accept q2)
})
```

**Phase 2: System-scoped implicit**
```stellogen
(within-system automaton
  (automaton a1 {
    (initial q0)
    (accept q2)
  }))
```

**Phase 3: File-level declaration**
```stellogen
#system automaton

initial q0
accept q2
```

**Phase 4: System ecosystem**
```stellogen
' Standard library of systems
#system automaton      ' stdlib/systems/automaton.sg
#system state-machine  ' stdlib/systems/state-machine.sg
#system logic          ' stdlib/systems/logic.sg

' Community systems
#system my-dsl         ' ./my-dsl-system.sg
```

---

## Roadmap

### Short-term (Prototype)

1. **Design system definition format**
   - Syntax for declaring systems
   - Transformation rules
   - File structure templates

2. **Implement basic system loader**
   - Parse system definitions
   - Load on-demand
   - Cache for performance

3. **Prototype one system**
   - Start with automaton (simplest)
   - Implement `#system automaton`
   - Test with examples/automata.sg

4. **Proof of concept: block-scoped**
   - Implement `(within-system ...)`
   - Test mixing systems in one file
   - Evaluate readability improvements

### Mid-term (Core Feature)

1. **Extend parser**
   - System-aware parsing modes
   - Source mapping (DSL → Core)
   - Error message transformation

2. **Standard library of systems**
   - automaton
   - state-machine
   - logic (Prolog-like)
   - type-definition
   - parser-combinator

3. **System composition**
   - Nested systems
   - System inheritance
   - System conflicts/resolution

4. **Tooling basics**
   - System definition validator
   - Transformation debugger
   - Documentation generator

### Long-term (Ecosystem)

1. **Advanced features**
   - Custom readers (true syntax changes)
   - System versioning
   - System package manager
   - Cross-system references

2. **IDE integration**
   - Syntax highlighting per system
   - Autocomplete for system vocabulary
   - Inline transformation preview
   - System-aware debugging

3. **Community systems**
   - System registry
   - Community contributions
   - System quality standards
   - Migration tools

4. **Performance optimization**
   - Incremental compilation
   - System caching
   - Lazy loading
   - Parallel transformations

---

## Conclusion

### Summary

The vision of **natural scripting syntax** in Stellogen:

1. **Eliminates `#(...)` noise** through system declarations
2. **Provides true DSL feel** for domain-specific code
3. **Composes with system locking** for constrained + ergonomic code
4. **Maintains Stellogen's philosophy** of user-driven semantics
5. **Enables gradual adoption** from explicit to natural syntax

**Key insight:** Stellogen's logic-agnostic core + system locking + natural syntax = **multi-surface language** where the same underlying machinery supports multiple scripting styles.

### Recommended Approach

**Start with block-level system activation:**

```stellogen
(within-system automaton
  initial q0
  accept q2
  if read 0 on q0 then q0
)
```

**Evolve to file-level declarations:**

```stellogen
#system automaton

initial q0
accept q2
if read 0 on q0 then q0
```

**Implementation strategy:**
1. AST-level transformation (cleanest)
2. System definitions as data files
3. Standard library of common systems
4. Gradual tooling improvements

### Philosophical Alignment

This proposal aligns with Stellogen's core values:

1. **Freedom preserved**: Systems are optional, escapable
2. **User-driven**: Users define systems and transformations
3. **Logic-agnostic**: No imposed semantics, just transformation rules
4. **Minimal core**: Systems built on same primitives (macros, constellations)
5. **Metaprogramming-first**: Code transforming code is first-class

It also addresses the **regularity vs freedom** tension from Girard:

- **Freedom**: Core Stellogen remains open
- **Regularity**: Systems impose structure
- **Balance**: Choose your level per file/block

### Next Steps

1. **Discuss design**
   - Community feedback on approaches
   - Refine system definition syntax
   - Identify must-have vs nice-to-have features

2. **Prototype**
   - Implement basic system loader
   - Transform examples/automata.sg to new syntax
   - Measure readability improvement

3. **Document**
   - System definition guide
   - Transformation semantics
   - Migration guide from `#(...)` to natural syntax

4. **Expand**
   - Create more systems (state-machine, logic, etc.)
   - Build standard library
   - Gather community systems

### Vision: Stellogen as Multi-Surface Language

**Core insight:** Stellogen can be **many languages** at once:

```stellogen
' File 1: Automaton DSL
#system automaton
initial q0
if read 0 on q0 then q1

' File 2: State Machine DSL
#system state-machine
state idle on start → running

' File 3: Logic Programming DSL
#system logic
fact parent(tom, bob)
rule grandparent(X, Z) :- parent(X, Y), parent(Y, Z)

' File 4: Type System DSL
#system type-definition
type nat = zero | succ of nat

' File 5: Core Stellogen (no system)
(:= x 42)
(show (exec @#a @#b))
```

**All files** compile to the same core Stellogen, interact seamlessly, but each has the **natural syntax** for its domain.

This is Stellogen's unique contribution: **A workshop that can reshape itself** into specialized workstations, then back to an open workshop—**on demand, per file, per block**.

As Girard teaches: **Regularity enables reasoning.**
As Stellogen teaches: **Freedom enables creativity.**
And now: **Systems enable both—when and where you choose.**

---

## References

### Stellogen Resources

- [CLAUDE.md](../CLAUDE.md) - Project guide
- [System Locking and Internal DSLs](./system_locking_and_internal_dsls.md)
- [examples/automata.sg](../examples/automata.sg)
- [GitHub Issue #20](https://github.com/engboris/stellogen/issues/20)

### Language Design

- **Racket**: Flatt, M. (2012). "Creating Languages in Racket"
  - `#lang` mechanism
  - Language-oriented programming
  - Reader customization

- **Scala**: Odersky, M. (2008). "The Scala Language Specification"
  - Internal DSLs via implicits
  - Flexible syntax

- **Haskell**: Hudak, P. (1998). "Modular Domain Specific Languages and Tools"
  - Embedded DSLs
  - Parser combinators

- **Lisp/Scheme**: McCarthy, J., Steele, G.
  - Reader macros
  - Homoiconicity
  - Code as data

### Metaprogramming

- **Template Haskell**: Sheard, T. (2002). "Template Meta-Programming for Haskell"
- **Rust Macros**: Matsakis, N. (2016). "Procedural Macros in Rust"
- **Elixir Macros**: Thomas, D. (2014). "Metaprogramming Elixir"

### DSL Theory

- Fowler, M. (2010). "Domain-Specific Languages"
- Mernik, M., Heering, J., Sloane, A. (2005). "When and How to Develop Domain-Specific Languages"
- Van Deursen, A., Klint, P., Visser, J. (2000). "Domain-Specific Languages: An Annotated Bibliography"

---

**Document Version:** 1.0
**Last Updated:** 2025-10-14
**Author:** Research into natural scripting syntax for Stellogen based on system declarations and elimination of `#(...)` notation
