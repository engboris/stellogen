# System Locking and Internal DSLs in Stellogen

> **Disclaimer**: This document was written with the assistance of Claude Code and represents exploratory research and analysis. The content may contain inaccuracies or misinterpretations and should not be taken as definitive statements about the Stellogen language implementation.

**Status:** Research Document / Design Proposal
**Date:** 2025-10-12
**Purpose:** Explore the design of "system locking" mechanisms that allow crystallizing Stellogen code into constrained systems with specific rules, enabling internal DSLs while maintaining freedom and flexibility

**Related:** [GitHub Issue #20](https://github.com/engboris/stellogen/issues/20)

---

## Table of Contents

1. [Introduction](#introduction)
2. [The Workshop Metaphor](#the-workshop-metaphor)
3. [The Need for Crystallization](#the-need-for-crystallization)
4. [Girard's Transcendental Syntax and Regularity](#girards-transcendental-syntax-and-regularity)
5. [Internal DSLs in Other Languages](#internal-dsls-in-other-languages)
6. [System Locking: Core Concepts](#system-locking-core-concepts)
7. [Proposed Design](#proposed-design)
8. [Examples](#examples)
9. [Comparison with Other Approaches](#comparison-with-other-approaches)
10. [Implementation Considerations](#implementation-considerations)
11. [Conclusion](#conclusion)

---

## Introduction

### The Design Challenge

Stellogen is fundamentally **open and free**—a workshop where programmers construct everything from elementary building blocks (terms, unification, polarity, constellations). This freedom is powerful but can be overwhelming. Sometimes, we want to work within **constrained systems** that provide:

- **Better programmer experience**: Natural, ergonomic patterns
- **Guarantees**: Specific properties enforced by the system
- **Framework-like structure**: Well-defined patterns and conventions
- **Domain-specific semantics**: Tailored to particular problem domains

The challenge is: **How do we "crystallize" or "freeze" practices into systems with rules and constraints, while still maintaining the freedom to escape these systems when needed?**

### The Core Idea

**System locking** is a mechanism to:

1. **Define systems** with specific constraints (allowed macros, required patterns, invariants)
2. **Lock code into systems** to gain guarantees and better ergonomics
3. **Maintain freedom** by allowing systems to be unlocked or escaped when necessary

This is analogous to:
- **Racket's `#lang` mechanism**: Creating internal DSLs within a host language
- **Type systems**: Constraining programs to gain safety, but optional
- **Module systems**: Encapsulation with controlled interfaces
- **Design by contract**: Invariants and pre/post-conditions

But uniquely tailored to Stellogen's philosophy of **logic-agnostic, user-driven semantics**.

### Philosophical Foundation

From Girard's transcendental syntax:

> What makes **general reasoning possible** is that objects have **regular, uniform parts**—like ID cards or passports that enable universal identification.

**Key insight:** Genericity requires regularity. To reason about multiple things uniformly, they must share some common structure.

In Stellogen terms:
- **Freedom** = No imposed structure
- **Systems** = Chosen regular structure
- **Locking** = Enforcing regularity within a scope
- **Unlocking** = Returning to freedom

**Crucially:** Systems are not jails. They're **voluntary constraints** that provide benefits but can be exited.

---

## The Workshop Metaphor

### Stellogen as a Workshop

Imagine Stellogen as an **open workshop** with basic tools:

```
Workshop contains:
  - Raw materials: Terms
  - Basic tools: Unification, polarity
  - Assembly method: Interaction
  - Building blocks: Constellations
```

In this workshop, you can build **anything**:

```stellogen
' Build a natural number system
(:= nat { [(-nat 0) ok] [(-nat (s N)) (+nat N)] })

' Build a type system
(macro (:: Tested Test) ...)

' Build a logic
(:= prolog-rules { ... })

' Build an object system
(:= object { ... })
```

**Advantage:** Total freedom, maximum expressiveness.

**Disadvantage:** No guarantees, no ergonomic patterns, easy to get lost.

### Crystallizing into Systems

Now imagine **crystallizing** some of these practices:

```stellogen
' Instead of this free-form code:
(:= my-type { ... })
(:= my-value ...)
(:: my-value my-type)

' Crystallize into a "typed system":
(system typed-lang
  :requires [type-checking-macros]
  :enforces [all-values-typed]
  :provides [type-safety]

  (type nat ...)
  (value zero : nat)
  (value one : nat))
```

**Advantage:** Structure, guarantees, better ergonomics.

**Disadvantage:** Less freedom within the system.

**Key feature:** Can exit the system when needed:

```stellogen
(unlock typed-lang)  ; Return to freedom
(:= untyped-hack ...)
(lock typed-lang)    ; Re-enter system
```

---

## The Need for Crystallization

### Problem 1: Repetitive Patterns

Without systems, common patterns must be repeated:

```stellogen
' Define type
(spec person-type { ... })

' Define constructor
(:= make-person ...)

' Define accessors
(:= get-name ...)
(:= get-age ...)

' Define type check
(:: person-instance person-type)

' Define serialization
(:= serialize-person ...)

' Define equality
(:= person-eq ...)
```

**Every new data type** requires all this boilerplate.

**With a system:**

```stellogen
(system record-system
  (defrecord person
    [name : string]
    [age : nat])

  ; Automatically provides:
  ;   - make-person
  ;   - get-name, get-age
  ;   - Type checking
  ;   - Serialization
  ;   - Equality
)
```

### Problem 2: Lack of Guarantees

Free-form Stellogen provides no guarantees:

```stellogen
' Might work
(:= add { [(+add 0 Y Y)] ... })

' Might not work
(:= add { [(+add X Y)] })  ; Missing third argument

' Might loop forever
(:= loop { [(-loop X) (+loop X)] })

' Might violate invariants
(:= nat-value (+nat []))  ; [] is not a nat
```

**With a system:**

```stellogen
(system total-functions
  :enforces [termination coverage]

  (defun add (x y : nat) : nat
    (match x
      [0 → y]
      [(s n) → (s (add n y))]))

  ; Compiler checks:
  ;   - Termination (structural recursion on x)
  ;   - Coverage (all patterns of nat covered)
  ;   - Type correctness (returns nat)
)
```

### Problem 3: Domain-Specific Needs

Different domains need different patterns:

**Logic programming:**
```stellogen
(system prolog-like
  :syntax [clauses facts queries]

  (fact (parent tom bob))
  (rule (grandparent X Z)
    (parent X Y) (parent Y Z))

  (query (grandparent tom Z)))
```

**Functional programming:**
```stellogen
(system functional
  :features [higher-order-functions pattern-matching]

  (defun map (f xs)
    (match xs
      [[] → []]
      [[h|t] → [(f h) | (map f t)]]))

  (defun filter (p xs) ...))
```

**Object-oriented:**
```stellogen
(system oop
  :features [classes inheritance methods]

  (class Animal
    (field name)
    (method speak () ...))

  (class Dog (extends Animal)
    (method speak () "Woof!")))
```

Each domain has **different needs**. Systems let us **crystallize domain-specific patterns**.

### Problem 4: Collaboration and Communication

Free-form code is **hard to communicate**:

```stellogen
' What does this do?
(:= mysterious {
  [(+f X) (-g X) (+h X)]
  [(-f Y) (+i Y) (-j Y)]})
```

**With a system:**

```stellogen
(system state-machine
  (state idle
    (on event-a → processing))

  (state processing
    (on event-b → idle)))

; Clear: This is a state machine
; Constraints: Only valid transitions allowed
; Communication: Domain vocabulary (state, event, transition)
```

Systems provide **shared vocabulary** and **common understanding**.

---

## Girard's Transcendental Syntax and Regularity

### Transcendental Syntax

**Jean-Yves Girard's transcendental syntax** is a radical rethinking of logic:

1. **No fixed logic**: Logic is not imposed from above
2. **Syntax first**: Syntax is primary, logic emerges from interaction
3. **Dynamics over statics**: Computation drives meaning
4. **No types a priori**: Types emerge from use, not declared beforehand

Stellogen embodies these principles—it's **logic-agnostic**, with **no imposed types or rules**.

### The Paradox of Regularity

But Girard also recognizes a paradox:

> To reason **generally** about things, they must be **regular** (uniform in some way).

**Example - Arithmetic:**

To prove properties of **all natural numbers**, we need:
- A **regular structure**: 0, s(0), s(s(0)), ...
- **Uniform rules**: Induction works because structure is regular

Without regularity, we can't do general reasoning:
```
If every number were unique with no pattern:
  {blob₁, ★, quantum, 42ish, ...}
How could we prove anything about "all numbers"?
```

**Regularity enables genericity.**

### The ID Card Metaphor

Girard uses the metaphor of **ID cards/passports**:

**ID Card properties:**
- **Standard format**: Photo, name, birthdate, ID number
- **Uniform structure**: All ID cards have the same fields
- **Enables reasoning**: Police can check IDs uniformly because structure is regular

**Without standard ID cards:**
- Person A brings a painting
- Person B brings a poem
- Person C brings a rock with their name carved on it
- How can anyone verify identity uniformly?

**The lesson:** Regularity enables **universal operations**.

### Application to Stellogen

**Free Stellogen** (no regularity):

```stellogen
' Every definition is unique
(:= thing1 { [(+weird X) ...] })
(:= thing2 { [(-strange) ...] })
(:= thing3 (+mystery))

' Hard to reason about uniformly
' No general operations possible
```

**Systematic Stellogen** (chosen regularity):

```stellogen
(system typed
  ; Regular structure: All values have type annotations

  (:= zero : nat (+nat 0))
  (:= one : nat (+nat (s 0)))
  (:= true : bool (+bool #t))

  ; Now we can reason uniformly:
  ;   - All values have known types
  ;   - Type checker works uniformly
  ;   - Generic operations possible
)
```

**Key insight:** Systems impose **chosen regularity** to enable **general reasoning** within that system.

### Moulds and Epidictic

From Girard's work on **moulds** (the French "moules"):

- **Mould**: A regular template/pattern that terms conform to
- **Epidictic**: The act of displaying/showing conformance to a pattern
- **Systemic reasoning**: Only possible when terms fit a mould

In Stellogen terms:

```stellogen
; Mould: "All natural numbers have form 0 or (s N)"
(system nat-system
  :mould [0 | (s N)]

  (:= zero : nat 0)
  (:= one : nat (s 0))

  ; Can do induction because terms fit the mould
)

; Without mould: Can't do induction
(:= weird-nat (+nat "five"))  ; Doesn't fit mould
```

**Epidictic** = "Here's my ID card (mould), proving I belong to this system"

---

## Internal DSLs in Other Languages

Before designing system locking for Stellogen, let's examine how other languages create internal DSLs.

### Racket's `#lang` Mechanism

**Racket** is famous for its **language-oriented programming**:

```racket
#!racket
; This is Racket

(define (hello name)
  (printf "Hello, ~a!\n" name))
```

```racket
#lang datalog
; This is Datalog embedded in Racket

parent(tom, bob).
parent(bob, ann).

grandparent(X, Z) :- parent(X, Y), parent(Y, Z).

grandparent(tom, Z)?
```

```racket
#lang typed/racket
; This is Typed Racket

(: factorial (-> Natural Natural))
(define (factorial n)
  (if (zero? n) 1 (* n (factorial (- n 1)))))
```

**How it works:**

1. `#lang` specifies a **language module**
2. Language module defines:
   - Reader (how to parse syntax)
   - Expander (how to expand macros)
   - Runtime (what primitives are available)
3. Each language is a **complete DSL** within Racket

**Key features:**
- Each `#lang` is a **separate language**
- Syntax can be completely different
- Different semantics, different guarantees
- Languages compose (can use Racket from within DSL)

### Haskell's Type Classes and Constraints

**Haskell** uses **type classes** to define constrained systems:

```haskell
-- Define a system (type class)
class Eq a where
  (==) :: a -> a -> Bool

-- Lock a type into the system
instance Eq Bool where
  True == True = True
  False == False = True
  _ == _ = False

-- Functions constrained to the system
elem :: Eq a => a -> [a] -> Bool
elem x [] = False
elem x (y:ys) = x == y || elem x ys
```

**Constraints as systems:**
```haskell
-- Only works for types in the Eq system
(==) :: Eq a => a -> a -> Bool

-- Only works for types in the Ord system
sort :: Ord a => [a] -> [a]

-- Requires both systems
unique :: (Eq a, Ord a) => [a] -> [a]
```

### Scala's Implicits and Extension Methods

**Scala** uses **implicits** to extend types with new capabilities:

```scala
// Define a system
trait Show[A] {
  def show(a: A): String
}

// Lock a type into the system
implicit val intShow: Show[Int] = new Show[Int] {
  def show(i: Int) = i.toString
}

// Use the system
def display[A](a: A)(implicit s: Show[A]): String = s.show(a)

display(42)  // Works: Int is in Show system
display("hi") // Error: String not in Show system (unless we add it)
```

### Rust's Traits and Derive Macros

**Rust** uses **traits** for system-like constraints:

```rust
// Define a system
trait Serialize {
    fn serialize(&self) -> String;
}

// Lock a type into the system
#[derive(Serialize)]  // Auto-generates implementation
struct Person {
    name: String,
    age: u32,
}

// Or manually
impl Serialize for Person {
    fn serialize(&self) -> String {
        format!("{{name: {}, age: {}}}", self.name, self.age)
    }
}

// Generic over the system
fn save<T: Serialize>(obj: &T) {
    let data = obj.serialize();
    // save to file...
}
```

### OCaml's Modules and Signatures

**OCaml** uses **module signatures** to define interfaces:

```ocaml
(* Define a system (signature) *)
module type ORDERED = sig
  type t
  val compare : t -> t -> int
end

(* Lock a module into the system *)
module IntOrdered : ORDERED = struct
  type t = int
  let compare x y = x - y
end

(* Generic over the system *)
module MakeSet (Ord : ORDERED) = struct
  (* Set operations using Ord.compare *)
end

module IntSet = MakeSet(IntOrdered)
```

### Summary: What These Systems Provide

| Language | Mechanism | What It Provides |
|----------|-----------|------------------|
| **Racket** | `#lang` | Complete DSLs with custom syntax |
| **Haskell** | Type classes | Constrained polymorphism |
| **Scala** | Implicits | Ad-hoc extension |
| **Rust** | Traits | Interface contracts |
| **OCaml** | Module signatures | Structural constraints |

**Common themes:**
1. **Define system**: Specify what's required (interface, protocol, mould)
2. **Lock into system**: Implement requirements for a type/module
3. **Use system**: Generic code that assumes system properties
4. **Guarantees**: System ensures certain properties hold

---

## System Locking: Core Concepts

### What is a System?

A **system** in Stellogen is:

1. **A constrained subset of the language** with specific rules
2. **A set of allowed macros/constructs** (the "vocabulary")
3. **Invariants that must be maintained** (the "laws")
4. **A regular structure** that enables reasoning (the "mould")

**Metaphors:**
- **Workshop → Factory**: From free assembly to assembly line with QA
- **Playground → Sports field**: From free play to rule-bound game
- **Wilderness → Garden**: From chaos to cultivated order

### The Three Pillars of a System

**1. Vocabulary (Allowed Macros)**

What constructs are permitted within the system?

```stellogen
(system functional
  :vocabulary [defun match lambda let]

  ; Can use: defun, match, lambda, let
  ; Cannot use: := (too low-level)
)
```

**2. Laws (Invariants)**

What properties must hold?

```stellogen
(system typed
  :laws [
    (all-values-have-types)
    (type-checks-must-pass)
  ]

  ; Enforced: Every value has explicit type
  ; Enforced: Type checking succeeds
)
```

**3. Mould (Regular Structure)**

What structural regularity is required?

```stellogen
(system algebraic-data
  :mould [
    (type T = C1 args1 | C2 args2 | ...)
    (all-constructors-known)
  ]

  ; Structure: Sum of products
  ; Enables: Exhaustiveness checking
)
```

### Locking and Unlocking

**Locking** = Entering a system (gaining constraints and guarantees)

```stellogen
(lock my-system)
; Now in my-system
; Constraints active
; Guarantees available
```

**Unlocking** = Exiting a system (returning to freedom)

```stellogen
(unlock my-system)
; Back to free Stellogen
; No constraints
; No guarantees
```

**Key principle:** Systems are not jails—you can **always escape**.

### The ID Card Mechanism

Inspired by Girard's metaphor, every entity in a system has an **ID card**:

```stellogen
(system typed
  ; ID card for this system: Type annotation

  (:= zero
    @id-card (type-annotation nat)  ; The ID card
    (+nat 0))

  ; System can check ID cards uniformly
)
```

**ID card** = Regular, inspectable data that proves conformance to system.

In practice, this might be:
- A type annotation
- A tag/label
- A specific constellation pattern
- Metadata attached to definitions

### Plugin Constellations

A **plugin constellation** acts as the **ID card validator**:

```stellogen
(system my-system
  :plugin-constellation system-checker

  (:= system-checker {
    ; Check that all values have required properties
    [(-check-id-card Value)
     (-has-type Value Type)
     (+valid-id Type)]

    [(-check-id-card Value)
     (+invalid-id Value)]
  })
)
```

The plugin constellation:
- **Validates** that entities conform to system requirements
- **Provides uniform checking** across all system entities
- **Acts as the gatekeeper** for the system

---

## Proposed Design

### Syntax for Defining Systems

**Basic system definition:**

```stellogen
(defsystem <name>
  [:vocabulary <list-of-allowed-macros>]
  [:laws <list-of-invariants>]
  [:mould <structural-pattern>]
  [:plugin <constellation>]

  <body>)
```

**Example:**

```stellogen
(defsystem typed-nat
  :vocabulary [type defval check]
  :laws [(all-values-typed) (types-valid)]
  :mould [(type T ...) (defval x : T ...)]
  :plugin type-checker

  (:= type-checker {
    [(-check-typed (defval X : T V))
     (+has-type X T)
     (+type-valid T)]
  })

  (type nat)
  (defval zero : nat 0)
  (defval one : nat (s 0)))
```

### Syntax for Entering/Exiting Systems

**Enter a system:**

```stellogen
(begin-system typed-nat)
; or
(lock typed-nat)
```

**Exit a system:**

```stellogen
(end-system typed-nat)
; or
(unlock typed-nat)
```

**Scoped system:**

```stellogen
(within-system typed-nat
  ; Code here is in the system
  (defval two : nat (s (s 0)))
  (check two))

; Automatically unlocked after block
```

### Vocabulary Enforcement

When in a system, only **allowed macros** can be used:

```stellogen
(defsystem restricted
  :vocabulary [defun deftype]

  (defun add ...)  ; OK: defun is allowed

  (:= raw ...)  ; ERROR: := not in vocabulary
)
```

**Benefit:** Enforces high-level abstractions, prevents low-level escape hatches.

### Law Enforcement

Systems can enforce **invariants**:

```stellogen
(defsystem typed
  :laws [(every-value-has-type)]

  (defval x : nat 0)  ; OK: has type
  (defval y 0)        ; ERROR: no type annotation
)
```

**Implementation:** Laws are predicates checked by the plugin constellation.

### Mould Checking

The **mould** specifies structural patterns:

```stellogen
(defsystem adt
  :mould [
    (deftype T = C1 T1 | C2 T2 | ...)
    (match-exhaustive)
  ]

  (deftype option = None | Some a)

  (defun get-or-default (opt default)
    (match opt
      [None → default]
      [(Some x) → x]))
  ; Checked: All constructors (None, Some) covered
)
```

### Plugin Constellation as Validator

The **plugin constellation** validates conformance:

```stellogen
(defsystem my-system
  :plugin my-validator

  (:= my-validator {
    ; Validate that value V conforms to system
    [(-validate V)
     (-extract-id-card V Card)
     (-check-card Card)
     (+valid V)]

    ; If no ID card, invalid
    [(-validate V)
     (-no-id-card V)
     (+invalid V)]
  })

  ; When defining in system, plugin checks
  (defval x ...)  ; → (-validate x) is called
)
```

### Escaping the System

Even within a system, you can **escape temporarily**:

```stellogen
(within-system typed
  (defval x : nat 0)

  (escape
    ; Temporarily unlock
    (:= y "untyped-string")  ; Low-level, no type
  )

  (defval z : nat (s 0))
  ; Back in system
)
```

**Use case:** When you need low-level power but mostly want high-level safety.

### Nested Systems

Systems can be **nested** or **combined**:

```stellogen
(defsystem typed ...)
(defsystem functional ...)

(begin-system typed)
  (begin-system functional)
    ; In both systems
    ; Both vocabularies available
    ; Both laws enforced
  (end-system functional)
(end-system typed)
```

### Inheriting Systems

Systems can **extend** other systems:

```stellogen
(defsystem base
  :vocabulary [def use])

(defsystem extended
  :extends base
  :vocabulary [deftype match]  ; Adds to base vocabulary
  :laws [(types-valid)])
```

---

## Examples

### Example 1: Typed System

**Goal:** Ensure all values have types and type checks pass.

```stellogen
(defsystem typed
  :vocabulary [type defval :: check]
  :laws [(all-typed) (types-valid)]
  :plugin type-validator

  (:= type-validator {
    [(-validate (defval X : T V))
     (+check-type V T)
     (+valid (defval X : T V))]

    [(-validate (defval X V))  ; No type annotation
     (+error "Value must have type annotation")]
  })

  ; Use the system
  (type nat {
    [(-nat 0) ok]
    [(-nat (s N)) (+nat N)]})

  (defval zero : nat 0)
  (defval one : nat (s 0))

  (check zero)  ; Type check
  (check one))
```

**Guarantees:**
- All values have explicit types
- Type checks succeed
- Uniform structure (all have `(defval X : T V)` form)

### Example 2: Functional System

**Goal:** Only pure functions, no side effects.

```stellogen
(defsystem pure-functional
  :vocabulary [defun lambda match let]
  :laws [(no-side-effects) (terminating)]
  :plugin purity-checker

  (:= purity-checker {
    ; Check function for purity
    [(-validate (defun Name Args Body))
     (-check-pure Body)
     (+valid (defun Name Args Body))]

    ; Recursive call OK if structural recursion
    [(-check-pure (Name Args))
     (-structural-recursion Name Args)
     (+pure (Name Args))]

    ; Disallow impure operations
    [(-check-pure (show X))
     (+error "show is impure (I/O)")]
  })

  (defun map (f xs)
    (match xs
      [[] → []]
      [[h|t] → [(f h) | (map f t)]]))

  (defun filter (p xs)
    (match xs
      [[] → []]
      [[h|t] →
        (if (p h)
          [h | (filter p t)]
          (filter p t))]))

  ; (show x)  ; ERROR: show not allowed (impure)
)
```

**Guarantees:**
- No side effects
- Termination (structural recursion)
- Pure functional semantics

### Example 3: State Machine System

**Goal:** Domain-specific language for state machines.

```stellogen
(defsystem state-machine
  :vocabulary [state on transition emit]
  :mould [
    (state Name (on Event → NextState)*)
    (all-states-reachable)
  ]
  :plugin fsm-validator

  (:= fsm-validator {
    [(-validate (state S Transitions))
     (-check-transitions Transitions)
     (+valid (state S Transitions))]

    [(-check-transitions [])
     (+ok)]

    [(-check-transitions [(on E → S) | Rest])
     (-state-exists S)
     (+check-transitions Rest)]
  })

  ; Define state machine
  (state idle
    (on start → running))

  (state running
    (on pause → paused)
    (on stop → idle))

  (state paused
    (on resume → running)
    (on stop → idle))

  ; Plugin validates:
  ;   - All transitions point to defined states
  ;   - All states are reachable
  ;   - No undefined events
)
```

**Guarantees:**
- Valid state machine
- All transitions well-defined
- Domain-specific vocabulary

### Example 4: Prolog-like System

**Goal:** Logic programming with clauses and queries.

```stellogen
(defsystem logic-prog
  :vocabulary [fact rule query]
  :laws [(clauses-well-formed)]
  :plugin logic-validator

  (:= logic-validator {
    [(-validate (fact F))
     (-check-ground F)
     (+valid (fact F))]

    [(-validate (rule Head Body))
     (-check-vars Head Body)
     (+valid (rule Head Body))]
  })

  (fact (parent tom bob))
  (fact (parent bob ann))

  (rule (grandparent X Z)
    (parent X Y)
    (parent Y Z))

  (query (grandparent tom Z))
)
```

**Guarantees:**
- Facts are ground (no variables)
- Rules are well-formed
- Queries are valid

### Example 5: OOP System

**Goal:** Object-oriented programming with classes and methods.

```stellogen
(defsystem oop
  :vocabulary [class field method new send]
  :laws [(single-inheritance) (methods-defined)]
  :plugin oop-validator

  (:= oop-validator {
    [(-validate (class C Parent Fields Methods))
     (-parent-exists Parent)
     (-methods-well-formed Methods)
     (+valid (class C Parent Fields Methods))]
  })

  (class Animal
    (field name)
    (method speak () "..."))

  (class Dog (extends Animal)
    (method speak () "Woof!"))

  (class Cat (extends Animal)
    (method speak () "Meow!"))

  (defval fido (new Dog "Fido"))
  (send fido speak)  ; "Woof!"
)
```

**Guarantees:**
- Single inheritance
- Methods defined for all classes
- Message sends are valid

### Example 6: Mixing Systems

**Goal:** Combine typed system with functional system.

```stellogen
; Define systems
(defsystem typed ...)
(defsystem functional ...)

; Use both
(begin-system typed)
  (type nat)
  (defval zero : nat 0)

  (begin-system functional)
    ; Now in both systems
    ; Can use typed and functional constructs

    (defun add : (nat → nat → nat) (x y)
      (match x
        [0 → y]
        [(s n) → (s (add n y))]))

    ; Both systems enforce constraints:
    ;   - typed: add must have type annotation
    ;   - functional: add must be pure
  (end-system functional)
(end-system typed)
```

### Example 7: Escaping a System

**Goal:** Mostly typed, but allow escape hatch.

```stellogen
(begin-system typed
  (defval x : nat 0)
  (defval y : nat (s 0))

  ; Need low-level hack
  (escape
    (:= debug-print
      {[(+debug X) (show X)]})
    ; Not type-checked, low-level
  )

  ; Back in typed system
  (defval z : nat (s (s 0)))

  ; Use escape hatch
  (escape
    (exec #debug-print @#z))
)
```

---

## Comparison with Other Approaches

### vs Racket's `#lang`

| Aspect | Racket `#lang` | Stellogen Systems |
|--------|---------------|-------------------|
| **Scope** | Entire file | Any scope (block, function, etc.) |
| **Syntax** | Can change completely | Same S-expressions |
| **Entry/Exit** | One language per file | Can lock/unlock dynamically |
| **Nesting** | No (one #lang per file) | Yes (nested systems) |
| **Implementation** | Separate reader/expander | Plugin constellation + macros |

**Advantage of Stellogen:** More fine-grained control, can mix freely.

### vs Haskell's Type Classes

| Aspect | Haskell Type Classes | Stellogen Systems |
|--------|---------------------|-------------------|
| **Scope** | Types | Any code |
| **Constraints** | Type-level only | Any invariants |
| **Opt-in** | Via instance declarations | Via lock/unlock |
| **Escape** | No (can't escape type system) | Yes (unlock) |
| **Checking** | Compile-time | Configurable |

**Advantage of Stellogen:** Not limited to types, can escape.

### vs Module Systems (OCaml, ML)

| Aspect | Module Signatures | Stellogen Systems |
|--------|------------------|-------------------|
| **Granularity** | Module-level | Any scope |
| **Interface** | Fixed signature | Dynamic plugin |
| **Flexibility** | Rigid structure | Flexible mould |
| **Escape** | No | Yes |

**Advantage of Stellogen:** More flexible, finer granularity.

### vs Design by Contract (Eiffel)

| Aspect | DbC (Eiffel) | Stellogen Systems |
|--------|-------------|-------------------|
| **Constraints** | Pre/post-conditions | Laws + moulds |
| **Checking** | Runtime assertions | Plugin constellation |
| **Vocabulary** | Same language | Restricted vocabulary |
| **Opt-out** | Can't disable | Can unlock |

**Advantage of Stellogen:** Vocabulary control, opt-out available.

### Unique Aspects of Stellogen's Approach

1. **Dynamic scope:** Lock/unlock at any granularity
2. **Plugin validation:** User-defined checking via constellations
3. **Vocabulary restriction:** Limit available constructs
4. **Escapable:** Always can unlock
5. **Composable:** Nested/combined systems
6. **Logic-agnostic:** No imposed semantics

---

## Implementation Considerations

### Compile-Time vs Runtime Checking

Systems can be checked at different times:

**Compile-time (static):**

```stellogen
(defsystem typed
  :check-time compile
  :plugin type-checker

  ; Checked when code is compiled
  (defval x : nat 0))
```

**Runtime (dynamic):**

```stellogen
(defsystem runtime-checked
  :check-time runtime
  :plugin runtime-validator

  ; Checked when code executes
  (defval x : nat 0))
```

**Hybrid:**

```stellogen
(defsystem hybrid
  :check-time [compile runtime]

  ; Some checks at compile-time
  ; Some checks at runtime
)
```

### Macro Expansion and Systems

Systems interact with macro expansion:

**Option 1: Systems apply after macro expansion**

```
Source → Macro expansion → System checking → Execution
```

**Option 2: Systems apply before macro expansion**

```
Source → System checking → Macro expansion → Execution
```

**Option 3: Integrated**

```
Source → (Macro expansion ↔ System checking) → Execution
```

**Recommendation:** Option 3 (integrated) for maximum flexibility.

### Performance Considerations

**Static checking (compile-time):**
- **Pros:** No runtime overhead
- **Cons:** Longer compilation time

**Dynamic checking (runtime):**
- **Pros:** Fast compilation
- **Cons:** Runtime overhead

**Caching:**

```stellogen
(defsystem cached
  :check-time compile
  :cache-results true

  ; Results cached, only check when code changes
)
```

### Error Messages

Systems should provide **clear error messages**:

```stellogen
(defsystem typed
  :plugin type-checker

  (defval x 0)  ; ERROR
  ; Error: Value 'x' missing type annotation
  ; In system: typed
  ; Required by law: all-typed
  ; Fix: Add type annotation
  ;   (defval x : nat 0)
)
```

### Debugging Systems

Tools for debugging system definitions:

```stellogen
; Inspect system
(inspect-system typed)
; → Vocabulary: [type defval :: check]
; → Laws: [(all-typed) (types-valid)]
; → Plugin: type-validator

; Test system without entering
(test-in-system typed
  (defval x 0))
; → Error: Missing type annotation

; Trace system checking
(trace-system typed
  (defval x : nat 0))
; → Checking law: all-typed ✓
; → Checking law: types-valid ✓
; → Plugin validation: ✓
```

### Gradual Adoption

Systems can be adopted gradually:

```stellogen
; Start free
(:= x 0)
(:= y 1)

; Add system incrementally
(begin-system typed
  (defval z : nat 2)
(end-system typed)

; Mix free and systematic code
(:= free-value 3)

(begin-system typed
  (defval typed-value : nat 4)
(end-system typed)
```

---

## Conclusion

### Summary

**System locking** provides a way to **crystallize Stellogen practices** into **constrained systems** with:

1. **Restricted vocabulary**: Only allowed macros
2. **Enforced laws**: Invariants that must hold
3. **Regular moulds**: Structural patterns enabling reasoning
4. **Plugin validation**: User-defined checking

**Key benefits:**

- **Better ergonomics**: Domain-specific abstractions
- **Guarantees**: Properties enforced by system
- **Communication**: Shared vocabulary and understanding
- **Flexibility**: Can lock/unlock dynamically

**Crucially:** Systems are **not jails**—they're **voluntary constraints** that can be escaped.

### Philosophical Alignment

System locking aligns with Stellogen's philosophy:

1. **User-driven**: Users define systems and constraints
2. **Logic-agnostic**: No imposed logic, systems are optional
3. **Minimal core**: Systems built on same primitives (constellations, macros)
4. **Freedom preserved**: Can always unlock/escape

It also embraces Girard's insights:

1. **Regularity enables reasoning**: Moulds provide uniform structure
2. **Transcendental syntax**: No fixed logic, emerges from use
3. **ID cards**: Plugin constellations validate conformance

### Comparison with Related Work

| Feature | Racket `#lang` | Haskell Type Classes | Stellogen Systems |
|---------|---------------|---------------------|-------------------|
| **Syntax change** | Yes | No | No |
| **Type-level** | No | Yes | Optional |
| **Escapable** | No | No | **Yes** |
| **Dynamic scope** | No (file-level) | No | **Yes** |
| **User-defined** | Yes | Yes | **Yes** |
| **Runtime checking** | Partial | No | **Yes** |

**Stellogen's unique contribution:** Escapable, dynamic-scope systems with user-defined validation.

### Open Questions

1. **Syntax:** What's the best syntax for system definitions?
   - `(defsystem ...)` vs `(system ... end)` vs other?

2. **Checking:** When to check?
   - Compile-time, runtime, or hybrid?
   - How to make it efficient?

3. **Composition:** How do systems compose?
   - Nested systems: Both active? Priority?
   - Conflicting laws: Error or resolution strategy?

4. **Standard library:** What systems should be provided?
   - Typed, functional, OOP, state machines, logic?
   - How to organize?

5. **Tooling:** What tools are needed?
   - System browser, debugger, profiler?
   - IDE integration?

6. **Performance:** How to minimize overhead?
   - Caching, optimization, selective checking?

7. **Migration:** How to migrate code into/out of systems?
   - Automatic conversion?
   - Gradual typing-style approach?

### Next Steps

1. **Prototype implementation:**
   - Start with simple system (e.g., typed)
   - Implement lock/unlock mechanism
   - Build plugin constellation support

2. **Experiment with examples:**
   - Implement examples from this document
   - Discover pain points and missing features
   - Refine design based on experience

3. **Community feedback:**
   - Discuss on GitHub issue #20
   - Gather use cases from users
   - Iterate on design

4. **Standardization:**
   - Once design stabilizes, document formally
   - Create standard library of systems
   - Build tooling support

### Final Thoughts

System locking represents a **middle ground** between:
- **Total freedom** (current Stellogen)
- **Total constraint** (traditional type systems, module systems)

It asks: **What if constraints were optional, user-defined, and escapable?**

This aligns with Stellogen's core philosophy:

> The semantic power (and responsibility) belongs entirely to the user.

Systems **empower** users to:
- Define their own constraints
- Choose when to be constrained
- Escape when necessary
- Build domain-specific languages

**The workshop metaphor evolved:**
- **Stellogen** = Open workshop
- **Systems** = Specialized workstations within the workshop
- **Locking** = Working at a specialized workstation
- **Unlocking** = Returning to open workshop

**The goal:** Provide structure when helpful, freedom when needed.

As Girard teaches us: **Regularity enables reasoning.** But Stellogen adds: **Freedom enables creativity.**

System locking gives us **both**.

---

## References

### GitHub

- [Issue #20: System lock (Girard's epidictic/systems)](https://github.com/engboris/stellogen/issues/20)
- [Stellogen Repository](https://github.com/engboris/stellogen)

### Girard's Work

- Girard, J.-Y. (2001). "Locus Solum: From the Rules of Logic to the Logic of Rules"
- Girard, J.-Y. (2007). "Le Point Aveugle: Cours de logique" (The Blind Spot)
- Girard, J.-Y. (2011-2016). "Transcendental Syntax" (lecture notes and papers)

### Language Design

- **Racket:** Flatt, M. (2012). "Creating Languages in Racket"
- **Haskell:** Hall, C. et al. (1996). "Type Classes in Haskell"
- **OCaml:** Leroy, X. (2000). "The Objective Caml System"
- **Scala:** Odersky, M. (2008). "The Scala Language Specification"

### Type Theory

- Pierce, B. (2002). "Types and Programming Languages"
- Cardelli, L. (1996). "Type Systems"

### DSLs

- Fowler, M. (2010). "Domain-Specific Languages"
- Hudak, P. (1998). "Modular Domain Specific Languages and Tools"

---

**Document Version:** 1.0
**Last Updated:** 2025-10-12
**Author:** Research and design exploration of system locking mechanisms in Stellogen
