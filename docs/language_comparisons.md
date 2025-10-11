# Stellogen: Comparative Analysis with Related Languages

**Status:** Research Document
**Date:** 2025-10-12
**Purpose:** Explore similarities and differences between Stellogen and related programming paradigms and languages

---

## Table of Contents

1. [Introduction](#introduction)
2. [Prolog and Datalog](#prolog-and-datalog)
3. [Lisp and Scheme](#lisp-and-scheme)
4. [MiniKanren and Relational Programming](#minikanren-and-relational-programming)
5. [Smalltalk](#smalltalk)
6. [Shen](#shen)
7. [Mercury](#mercury)
8. [Curry](#curry)
9. [Lambda Prolog](#lambda-prolog)
10. [Linear Logic Languages](#linear-logic-languages)
11. [Interaction Nets and Proof Nets](#interaction-nets-and-proof-nets)
12. [Term Rewriting Systems](#term-rewriting-systems)
13. [Concatenative Languages](#concatenative-languages)
14. [Unique Aspects of Stellogen](#unique-aspects-of-stellogen)
15. [Positioning in the Language Landscape](#positioning-in-the-language-landscape)
16. [Conclusion](#conclusion)

---

## Introduction

Stellogen is an experimental, **logic-agnostic** programming language based on **term unification** and **polarity-based interaction**. It draws inspiration from multiple paradigms while maintaining a unique identity.

**Core characteristics:**
- Unification as the fundamental operation
- Polarity-driven interaction (`+` positive, `-` negative, neutral)
- Constellations as computational units
- Types as sets of interactive tests
- Multi-paradigm: supports logic, functional, imperative, and object-oriented patterns
- Minimalist: built on a small set of primitives

This document explores how Stellogen relates to similar languages and approaches, identifying shared concepts and distinguishing features.

---

## Prolog and Datalog

### Overview

**Prolog** (Programming in Logic) and **Datalog** are logic programming languages based on first-order logic, Horn clauses, and unification.

**Key features:**
- Facts and rules (clauses)
- Unification and backtracking
- Query-driven computation
- SLD resolution strategy

### Similarities with Stellogen

#### 1. Unification is Central

Both use unification to match terms and bind variables.

**Prolog:**
```prolog
?- f(X, a) = f(b, Y).
X = b,
Y = a.
```

**Stellogen:**
```stellogen
' Unification happens during interaction
(:= query [(-f X a)])
(:= fact  [(+f b Y)])
' When they interact, X unifies with b, Y with a
```

#### 2. Logic Programming Patterns

Both support logic programming idioms.

**Prolog - Family relationships:**
```prolog
parent(tom, bob).
parent(bob, ann).

grandparent(X, Z) :- parent(X, Y), parent(Y, Z).

?- grandparent(tom, Z).
Z = ann.
```

**Stellogen - Same example (`examples/prolog.sg:13-29`):**
```stellogen
(:= family {
  [(+parent tom bob)]
  [(+parent bob ann)]
  [(+parent pat jim)]})

(:= grandparent {
  [(-grandparent X Z) (-parent X Y) (+parent Y Z)]})

(:= query [(-grandparent tom Z) Z])
(show (interact #grandparent @(process #query #family)))
' Result: [ann, jim]
```

#### 3. Relational Computation

Both can express relations rather than functions.

**Prolog - Addition:**
```prolog
add(0, Y, Y).
add(s(X), Y, s(Z)) :- add(X, Y, Z).

?- add(s(s(0)), s(s(0)), R).
R = s(s(s(s(0)))).
```

**Stellogen - Same (`examples/prolog.sg:3-10`):**
```stellogen
(:= add {
  [(+add 0 Y Y)]
  [(-add X Y Z) (+add (s X) Y (s Z))]})

(:= query1 [(-add <s s 0> <s s 0> R) R])
(show (interact #add @#query1))
' Result: (s (s (s (s 0))))
```

### Differences from Stellogen

#### 1. Polarity

**Prolog:** No polarity concept. All predicates are neutral.

**Stellogen:** **Polarity is fundamental**. Every ray has a polarity (`+`, `-`, or neutral) that drives interaction.

```stellogen
' +add and -add are complementary
[(+add 0 Y Y)]           ' Provides addition
[(-add X Y Z) ...]       ' Requests addition
```

This is inspired by **proof theory** (positive vs negative formulas) and **linear logic** (resources).

#### 2. Control Flow

**Prolog:** Uses **backtracking search**. The runtime explores the search space automatically.

```prolog
member(X, [X|_]).
member(X, [_|T]) :- member(X, T).

?- member(X, [1,2,3]).
X = 1 ;    % backtrack
X = 2 ;    % backtrack
X = 3.     % backtrack
```

**Stellogen:** Uses **interaction-based evaluation**. No automatic backtracking—computation is driven by term fusion.

```stellogen
' All matching stars interact simultaneously (or linearly with fire)
' No implicit search strategy
```

#### 3. Constellations vs Clauses

**Prolog:** Clauses are **ordered** and tried sequentially.

**Stellogen:** Constellations are **unordered sets** of stars. All applicable interactions happen (unless using linear `fire`).

```stellogen
(:= example {
  [(+f a) result1]
  [(+f b) result2]
  [(+f c) result3]})
' No ordering—all three stars coexist
```

#### 4. Focus and Evaluation Control

**Prolog:** Evaluation is automatic—you query and Prolog finds solutions.

**Stellogen:** You explicitly control **when** and **how** evaluation happens:
- `@` (focus): Evaluate before using
- `#` (call): Retrieve identifier
- `interact`: Non-linear interaction
- `fire`: Linear interaction
- `process`: Chain interactions

```stellogen
(:= x (+f a))
#x          ' Just the identifier
@#x         ' Focused/evaluated
(interact @#x #y)  ' Explicit interaction
```

#### 5. Type Systems

**Prolog:** Untyped (though Prolog dialects like Mercury add types).

**Stellogen:** **Types are user-defined interactive tests**, not built-in.

```stellogen
(spec nat {
  [(-nat 0) ok]
  [(-nat (s N)) (+nat N)]})

(:= zero (+nat 0))
(:: zero nat)  ' Type check via interaction
```

### Summary: Prolog vs Stellogen

| Aspect | Prolog | Stellogen |
|--------|--------|-----------|
| Foundation | Horn clauses + unification | Terms + polarity + interaction |
| Control | Backtracking search | Explicit interaction |
| Evaluation | Automatic goal-solving | Explicit focus and interaction |
| Order | Clauses are ordered | Constellations are unordered |
| Polarity | No | Yes (central concept) |
| Types | None (untyped) | User-defined via interactive tests |

**Key insight:** Stellogen takes unification from Prolog but replaces backtracking with polarity-based interaction, giving the user more control and a different computational model.

---

## Lisp and Scheme

### Overview

**Lisp** (and its minimalist dialect **Scheme**) are pioneering languages known for:
- S-expressions (symbolic expressions)
- Code as data (homoiconicity)
- Powerful metaprogramming (macros)
- Minimalism (especially Scheme)
- `eval` for runtime evaluation

### Similarities with Stellogen

#### 1. S-Expression Syntax

Both use S-expressions as the primary syntactic form.

**Scheme:**
```scheme
(define (add x y) (+ x y))
(add 2 3)  ; => 5
```

**Stellogen:**
```stellogen
(:= add { ... })
(show (interact #add @#query))
```

Both are homoiconic—code is data represented as lists/trees.

#### 2. Metaprogramming and Macros

Both support powerful macro systems for syntactic extension.

**Scheme:**
```scheme
(define-syntax when
  (syntax-rules ()
    [(when test body ...)
     (if test (begin body ...) #f)]))

(when (> x 0)
  (display "positive"))
```

**Stellogen:**
```stellogen
(new-declaration (spec X Y) (:= X Y))
(new-declaration (:: Tested Test)
  (== @(interact @#Tested #Test) ok))

(spec nat { ... })
(:: zero nat)
```

Both allow users to extend the language with new syntactic forms.

#### 3. The `eval` Primitive

Both have an `eval` function for runtime code evaluation.

**Scheme:**
```scheme
(define x '(+ 1 2))
(eval x (interaction-environment))  ; => 3
```

**Stellogen (`src/sgen_eval.ml:208-223`):**
```stellogen
(:= x (+f a))
(eval #x)  ' Reifies and evaluates the term
```

This enables meta-level computation—treating data as code.

#### 4. Minimalism

Both embrace minimalism—building complex systems from small sets of primitives.

**Scheme:** Built on ~6 primitives (cons, car, cdr, eq?, atom?, cond) + lambda.

**Stellogen:** Built on terms, unification, polarity, and interaction.

#### 5. Multi-Paradigm

Both support multiple paradigms.

**Scheme:** Functional, imperative, object-oriented (via macros/libraries).

**Stellogen:** Logic, functional, imperative, object-oriented (via constellations).

### Differences from Stellogen

#### 1. Computational Foundation

**Lisp/Scheme:** Based on **lambda calculus**—functions and application.

```scheme
((lambda (x) (* x x)) 5)  ; => 25
```

**Stellogen:** Based on **term unification** and **polarity interaction**.

```stellogen
(:= square {
  [(-square X R) (+mult X X R)]})
```

No inherent notion of "function application"—everything is interaction.

#### 2. Evaluation Strategy

**Scheme:** Eager evaluation (strict, call-by-value).

```scheme
(define (f x y) x)
(f 1 (/ 1 0))  ; Error! y is evaluated even though unused
```

**Stellogen:** **Explicit evaluation control** via focus `@` and interaction.

```stellogen
(:= x (error))
#x         ' Fine—just the identifier
@#x        ' Error! Evaluation forced
```

No automatic evaluation—you control when terms are evaluated.

#### 3. Unification

**Scheme:** No built-in unification. Variables are bound via assignment or lambda.

**Stellogen:** **Unification is the primary binding mechanism**.

```stellogen
' X unifies with (s 0) during interaction
[(-nat (s X)) ...]
```

#### 4. Polarity

**Scheme:** No concept of polarity.

**Stellogen:** Polarity drives computation.

```stellogen
[(+f X) ...]   ' Positive
[(-f X) ...]   ' Negative
```

#### 5. Types

**Scheme:** Dynamically typed, no static types.

**Stellogen:** **Types are interactive tests** defined by the user.

```stellogen
(spec nat { [(-nat 0) ok] ... })
```

### Summary: Lisp/Scheme vs Stellogen

| Aspect | Lisp/Scheme | Stellogen |
|--------|-------------|-----------|
| Foundation | Lambda calculus | Term unification + polarity |
| Syntax | S-expressions | S-expressions |
| Evaluation | Eager (strict) | Explicit (via `@`) |
| Metaprogramming | Macros (syntax-rules, defmacro) | Macros (new-declaration) |
| Unification | No | Yes (central) |
| Types | Dynamic | User-defined interactive tests |
| Paradigm | Functional (primarily) | Multi-paradigm (logic-agnostic) |

**Key insight:** Stellogen adopts Lisp's minimalism and metaprogramming spirit but replaces lambda calculus with term unification as the computational foundation.

---

## MiniKanren and Relational Programming

### Overview

**MiniKanren** is a family of embedded domain-specific languages for **relational programming**—expressing programs as relations rather than functions.

**Key features:**
- Based on unification and constraint solving
- Supports logic variables
- Interleaving search (fairness)
- Embedded in host languages (Scheme, Racket, Clojure, Haskell, etc.)

### Similarities with Stellogen

#### 1. Unification-Based

Both use unification to relate terms.

**MiniKanren (in Scheme):**
```scheme
(run* (q)
  (== q 'hello))
; => (hello)
```

**Stellogen:**
```stellogen
(:= fact [(+hello q)])
(:= query [(-hello X) X])
(show (interact #fact @#query))
```

#### 2. Relational Queries

Both can express relations that work in multiple directions.

**MiniKanren - append (relational):**
```scheme
(define appendo
  (lambda (l s out)
    (conde
      [(== '() l) (== s out)]
      [(fresh (a d res)
         (== `(,a . ,d) l)
         (== `(,a . ,res) out)
         (appendo d s res))])))

(run* (q) (appendo '(1 2) '(3 4) q))
; => ((1 2 3 4))

(run* (q) (appendo q '(3 4) '(1 2 3 4)))
; => ((1 2))

(run* (q) (appendo '(1 2) q '(1 2 3 4)))
; => ((3 4))
```

**Stellogen - Similar pattern:**
```stellogen
(:= appendo {
  [(+append [] S S)]
  [(-append [A|D] S [A|Res]) (+append D S Res)]})

' Forward
(:= q1 [(-append [1 2] [3 4] R) R])
(show (interact #appendo @#q1))

' Backward (if properly defined)
(:= q2 [(-append X [3 4] [1 2 3 4]) X])
(show (interact #appendo @#q2))
```

#### 3. Logic Variables

Both support logic variables that get bound through unification.

**MiniKanren:**
```scheme
(run* (q)
  (fresh (x y)
    (== x 1)
    (== y 2)
    (== q (list x y))))
; => ((1 2))
```

**Stellogen:**
```stellogen
' Variables (uppercase) get bound during interaction
[(-f X Y) (+bind X 1) (+bind Y 2) (result X Y)]
```

### Differences from Stellogen

#### 1. Embedding vs Standalone

**MiniKanren:** **Embedded DSL** in a host language (usually Scheme/Racket).

```scheme
; MiniKanren runs inside Scheme
(define (my-function)
  (run* (q)
    ...))
```

**Stellogen:** **Standalone language** with its own syntax and runtime.

#### 2. Search Strategy

**MiniKanren:** Uses **interleaving search** for fairness—ensures all branches are explored.

**Stellogen:** No automatic search strategy. Interaction is deterministic (or uses `fire` for linearity).

#### 3. Constraints

**MiniKanren:** Supports constraint logic programming (CLP) extensions:
- `=/=` (disequality)
- `symbolo`, `numbero` (type constraints)
- Finite domain constraints

**Stellogen:** Supports inequality constraints `!=` but not full CLP.

```stellogen
(:= example {
  [(+f a)]
  [(+f b)]
  @[(-f X) (-f Y) (r X Y) || (!= X Y)]})
```

#### 4. Negation

**MiniKanren:** No built-in negation (NAF would break monotonicity).

**Stellogen:** No built-in negation either, but polarity provides a different kind of duality.

```stellogen
[(+f X) ...]   ' Provides
[(-f X) ...]   ' Requires
```

### Summary: MiniKanren vs Stellogen

| Aspect | MiniKanren | Stellogen |
|--------|------------|-----------|
| Embedding | Embedded DSL | Standalone language |
| Search | Interleaving search | Explicit interaction |
| Relations | Yes | Yes (via constellations) |
| Constraints | Full CLP support | Limited (!=, slice) |
| Polarity | No | Yes |

**Key insight:** Stellogen and MiniKanren both embrace relational programming through unification, but Stellogen adds polarity and removes automatic search, giving more explicit control.

---

## Smalltalk

### Overview

**Smalltalk** is an object-oriented language known for:
- Pure object-oriented design (everything is an object)
- Message-passing as the fundamental operation
- Minimalism (objects + messages)
- Live programming environment
- Reflective and introspective

### Similarities with Stellogen

#### 1. Minimalism

Both build complex systems from minimal primitives.

**Smalltalk:** Objects + messages.

**Stellogen:** Terms + polarity + interaction.

#### 2. Message-Passing Metaphor

**Smalltalk:** Computation is sending messages to objects.

```smalltalk
5 squared.  "send 'squared' message to object 5"
array at: 1 put: 'hello'.  "send 'at:put:' message to array"
```

**Stellogen:** Computation is **interaction** between complementary rays.

```stellogen
[(+square 5)]      ' "Provides square of 5"
[(-square X) ...]  ' "Requests square"
' Interaction fuses them
```

This is analogous—requests (negative rays) are like messages, and provisions (positive rays) are like receivers.

#### 3. Reflection

**Smalltalk:** Objects can introspect and modify themselves.

```smalltalk
5 class.         "=> SmallInteger"
5 respondsTo: #squared.  "=> true"
```

**Stellogen:** `eval` provides a form of reflection—treating terms as code.

```stellogen
(:= x (+f a))
(eval #x)  ' Meta-level evaluation
```

#### 4. Everything is First-Class

**Smalltalk:** Classes, methods, blocks—all are objects.

**Stellogen:** Constellations, types, macros—all are expressions that can be manipulated.

```stellogen
(:= type1 { ... })
(:= type2 { ... })
(:= combined { #type1 #type2 })
```

### Differences from Stellogen

#### 1. Object-Oriented vs Logic-Agnostic

**Smalltalk:** Pure OO—everything is an object with methods.

**Stellogen:** **Logic-agnostic**—no imposed paradigm. Can encode OO, functional, logic, etc.

#### 2. Imperative State

**Smalltalk:** Objects have **mutable state**.

```smalltalk
counter := 0.
counter := counter + 1.
```

**Stellogen:** No built-in mutable state. Computation is **declarative** (via interaction).

```stellogen
' No assignment—only definitions and interactions
(:= value 0)
' Cannot mutate value
```

#### 3. Inheritance

**Smalltalk:** Class-based inheritance.

```smalltalk
Array subclass: #SortedArray ...
```

**Stellogen:** No inheritance. Composition via constellations.

```stellogen
(:= extended { #base #extra })
```

#### 4. Control Structures

**Smalltalk:** Control structures are methods on Boolean objects.

```smalltalk
x > 0 ifTrue: [ 'positive' ] ifFalse: [ 'non-positive' ]
```

**Stellogen:** Control is via **interaction and focus**.

```stellogen
' No if/then/else—use constellations that match
(:= check {
  [(+is-positive X) (result positive)]
  [(+is-negative X) (result negative)]})
```

### Summary: Smalltalk vs Stellogen

| Aspect | Smalltalk | Stellogen |
|--------|-----------|-----------|
| Paradigm | Object-oriented | Logic-agnostic (multi-paradigm) |
| Fundamental operation | Message passing | Polarity interaction |
| State | Mutable objects | Immutable terms |
| Minimalism | Objects + messages | Terms + interaction |
| Reflection | Object introspection | eval + meta-computation |

**Key insight:** Stellogen shares Smalltalk's minimalism and message-passing spirit but is more abstract—polarity interaction is a generalization that encompasses OO, logic, and functional styles.

---

## Shen

### Overview

**Shen** is a functional programming language with:
- Optional type system (Sequent calculus-based)
- Pattern matching
- Embedded Prolog
- Lisp-like syntax
- Philosophy: "Power comes with responsibility"

### Similarities with Stellogen

#### 1. Optional Type Systems

**Shen:** Types are optional—you can write untyped code or add type annotations.

```shen
(define factorial
  0 -> 1
  N -> (* N (factorial (- N 1))))
```

**Stellogen:** Types are user-defined interactive tests—completely optional.

```stellogen
(:= factorial { ... })
' No type required

(spec nat { ... })
(:: value nat)
' Optional type check
```

#### 2. Embedded Logic Programming

**Shen:** Has Prolog embedded via `prolog?` macro.

```shen
(prolog?
  (parent tom bob)
  (parent bob ann)
  (grandparent X Z :- (parent X Y) (parent Y Z)))
```

**Stellogen:** Supports Prolog-style logic programming natively via constellations.

```stellogen
(:= family { [(+parent tom bob)] ... })
(:= grandparent { [(-grandparent X Z) (-parent X Y) (+parent Y Z)] })
```

#### 3. Philosophy

**Shen:** "Types are optional; power comes with responsibility."

**Stellogen:** "The semantic power (and responsibility) belongs entirely to the user."

Both put the user in control rather than imposing a system.

### Differences from Stellogen

#### 1. Type System

**Shen:** **Sequent calculus**-based type system with type inference.

```shen
(define typed-function
  {number --> number}
  X -> (* X X))
```

**Stellogen:** Types are **interactive tests**, not static analysis.

```stellogen
(spec nat { [(-nat 0) ok] ... })
(:: zero nat)  ' Runtime interaction
```

#### 2. Pattern Matching

**Shen:** First-class pattern matching in function definitions.

```shen
(define member
  _ [] -> false
  X [X | _] -> true
  X [_ | Tail] -> (member X Tail))
```

**Stellogen:** Pattern matching happens via **unification during interaction**.

```stellogen
(:= member {
  [(+member X [X|_]) true]
  [(-member X [_|Tail]) (+member X Tail)]})
```

#### 3. Functional Emphasis

**Shen:** Primarily functional—functions are first-class.

**Stellogen:** **Logic-agnostic**—functional is one pattern among many.

### Summary: Shen vs Stellogen

| Aspect | Shen | Stellogen |
|--------|------|-----------|
| Types | Optional sequent calculus | Optional interactive tests |
| Pattern matching | Built-in syntax | Via unification |
| Paradigm | Functional + logic | Multi-paradigm |
| Philosophy | Power + responsibility | User-driven semantics |

**Key insight:** Both empower the user with optional type systems, but Stellogen goes further by making types part of the language's interactive semantics rather than a separate checking layer.

---

## Mercury

### Overview

**Mercury** is a **pure logic programming language** with:
- Strong static type system
- Modes and determinism
- Based on Prolog but with types and purity

**Key features:**
- Types: Strong, static, inferred
- Modes: Specify input/output for predicates
- Determinism: `det`, `semidet`, `multi`, `nondet`

### Similarities with Stellogen

#### 1. Logic Programming

Both support logic programming patterns.

**Mercury:**
```mercury
:- pred append(list(T), list(T), list(T)).
:- mode append(in, in, out) is det.

append([], Ys, Ys).
append([X | Xs], Ys, [X | Zs]) :- append(Xs, Ys, Zs).
```

**Stellogen:**
```stellogen
(:= append {
  [(+append [] Ys Ys)]
  [(-append [X|Xs] Ys [X|Zs]) (+append Xs Ys Zs)]})
```

#### 2. Declarative Semantics

Both emphasize declarative computation—specify what, not how.

### Differences from Stellogen

#### 1. Type System

**Mercury:** **Strong static typing** with type inference.

```mercury
:- type tree(T) ---> empty ; node(T, tree(T), tree(T)).
```

**Stellogen:** **No static types**—types are runtime interactive tests.

```stellogen
(spec tree { ... })  ' User-defined
```

#### 2. Modes

**Mercury:** Explicit **mode annotations** specify data flow.

```mercury
:- mode append(in, in, out) is det.
:- mode append(out, out, in) is multi.
```

**Stellogen:** No explicit modes. Data flow is implicit in polarity.

```stellogen
[(+append [] Ys Ys)]          ' Polarity suggests "provides append"
[(-append [X|Xs] Ys [X|Zs])]  ' "Requires append"
```

#### 3. Determinism

**Mercury:** Explicit **determinism declarations**.

- `det`: exactly one solution
- `semidet`: zero or one solution
- `multi`: one or more solutions
- `nondet`: zero or more solutions

**Stellogen:** No determinism analysis. Interaction produces whatever it produces.

#### 4. Purity

**Mercury:** Enforces **purity**—no side effects (except in IO monad).

**Stellogen:** No enforced purity, but constellations are declarative by nature.

### Summary: Mercury vs Stellogen

| Aspect | Mercury | Stellogen |
|--------|---------|-----------|
| Types | Strong static | Optional interactive tests |
| Modes | Explicit annotations | Implicit via polarity |
| Determinism | Analyzed and declared | Not tracked |
| Purity | Enforced | Not enforced |

**Key insight:** Mercury adds strong typing and mode analysis to logic programming. Stellogen takes the opposite approach—keeping it untyped and letting users define semantics.

---

## Curry

### Overview

**Curry** is a **functional logic programming language** combining:
- Functional programming (like Haskell)
- Logic programming (like Prolog)
- Non-deterministic computation
- Narrowing-based evaluation

### Similarities with Stellogen

#### 1. Functional + Logic

Both blend functional and logic paradigms.

**Curry - Logic:**
```curry
append [] ys = ys
append (x:xs) ys = x : append xs ys

-- Can run backwards
main = append xs [3,4] =:= [1,2,3,4]
-- xs = [1,2]
```

**Stellogen:**
```stellogen
(:= append {
  [(+append [] Ys Ys)]
  [(-append [X|Xs] Ys [X|Zs]) (+append Xs Ys Zs)]})
```

#### 2. Non-Determinism

**Curry:** Functions can be non-deterministic.

```curry
coin = 0
coin = 1

double x = x + x

main = double coin  -- Could be 0, 1, 2
```

**Stellogen:** Constellations can have multiple matching stars.

```stellogen
(:= coin {
  [(+coin 0)]
  [(+coin 1)]})
```

### Differences from Stellogen

#### 1. Type System

**Curry:** Hindley-Milner type system (like Haskell).

```curry
append :: [a] -> [a] -> [a]
```

**Stellogen:** No static types.

#### 2. Functional Syntax

**Curry:** Function application syntax.

```curry
map f xs
```

**Stellogen:** Interaction-based.

```stellogen
(interact #map @#f @#xs)
```

#### 3. Narrowing

**Curry:** Uses **narrowing** (combination of unification and reduction).

**Stellogen:** Uses **polarity-based interaction** (different mechanism).

### Summary: Curry vs Stellogen

| Aspect | Curry | Stellogen |
|--------|-------|-----------|
| Paradigm | Functional logic | Logic-agnostic |
| Types | Hindley-Milner | Optional interactive tests |
| Evaluation | Narrowing | Polarity interaction |

**Key insight:** Curry fuses functional and logic within a typed functional framework. Stellogen is more radical—no inherent paradigm imposed.

---

## Lambda Prolog

### Overview

**Lambda Prolog** (λProlog) extends Prolog with:
- Higher-order logic
- Lambda terms
- Implication goals
- Universal quantification in goals

### Similarities with Stellogen

#### 1. Logic Programming

Both support logic programming.

#### 2. Higher-Order Terms

**Lambda Prolog:** First-class lambda terms.

```prolog
map F [] [].
map F [X|Xs] [Y|Ys] :- Y = (F X), map F Xs Ys.
```

**Stellogen:** Can encode lambda calculus (`examples/lambda.sg`).

```stellogen
(:= id [(+id (exp [l|X] d)) (+id [r|X])])
```

### Differences from Stellogen

#### 1. Higher-Order Unification

**Lambda Prolog:** Uses **higher-order unification** (more complex than first-order).

**Stellogen:** Uses **first-order unification**.

#### 2. Typed

**Lambda Prolog:** Explicitly typed.

**Stellogen:** Untyped (types optional).

### Summary: Lambda Prolog vs Stellogen

| Aspect | Lambda Prolog | Stellogen |
|--------|---------------|-----------|
| Order | Higher-order | First-order |
| Types | Typed | Untyped |
| Lambda terms | Native | Encoded |

**Key insight:** Lambda Prolog extends Prolog with higher-order features. Stellogen stays first-order but adds polarity.

---

## Linear Logic Languages

### Overview

Languages based on **linear logic**, where resources are tracked and can't be duplicated or discarded freely:
- **Lolli:** Linear logic programming
- **LolliMon:** Linear logic with monadic encapsulation
- **Celf:** Linear logic programming (CLF)

**Key concepts:**
- Linear resources (use exactly once)
- Affine resources (use at most once)
- Tensor (`⊗`), lollipop (`-o`), par, plus, with

### Similarities with Stellogen

#### 1. Linear Interaction

Stellogen supports **linear evaluation** via `fire`.

**Stellogen (`examples/mll.sg`, `examples/smll.sg`):**
```stellogen
(new-declaration (::lin Tested Test)
  (== @(fire #Tested #Test) ok))

' fire uses resources exactly once (linear)
' interact allows reuse (non-linear)
```

#### 2. Polarity

Linear logic has **positive** and **negative** formulas, similar to Stellogen's polarities.

**Linear Logic:**
- Positive: `⊗` (tensor), `⊕` (plus), `1`, `0`
- Negative: `⅋` (par), `&` (with), `⊥`, `⊤`

**Stellogen:**
```stellogen
[(+f X) ...]  ' Positive polarity
[(-f X) ...]  ' Negative polarity
```

#### 3. Resources

Both track resources and control their use.

**Linear Logic:** Resources consumed upon use.

**Stellogen:** `fire` ensures linear usage; `interact` allows non-linear usage.

```stellogen
(fire #a #b)      ' Linear
(interact #a #b)  ' Non-linear
```

### Differences from Stellogen

#### 1. Logical Foundation

**Linear logic languages:** Built on **proof theory** and **sequent calculus**.

**Stellogen:** **Logic-agnostic**—inspired by linear logic but not bound to it.

#### 2. Explicit Connectives

**Linear logic languages:** Explicit connectives: `⊗`, `-o`, `&`, etc.

**Stellogen:** No explicit connectives—everything is encoded via constellations.

#### 3. Type System

**Linear logic languages:** Often typed (e.g., LF-based types in Celf).

**Stellogen:** Untyped with optional interactive tests.

### Summary: Linear Logic Languages vs Stellogen

| Aspect | Linear Logic Languages | Stellogen |
|--------|------------------------|-----------|
| Foundation | Linear logic (proof theory) | Term unification + polarity |
| Resources | Tracked via type system | Controlled via fire vs interact |
| Connectives | Explicit (⊗, -o, etc.) | Encoded in constellations |
| Types | Typed | Optional tests |

**Key insight:** Stellogen is inspired by linear logic (polarity, linearity) but doesn't commit to its formal system—it's a looser, more flexible interpretation.

---

## Interaction Nets and Proof Nets

### Overview

**Interaction nets** are a graph-rewriting formalism:
- Nodes with ports
- Nets (graphs) connected via wires
- Active pairs (two nodes connected) rewrite according to rules
- Based on Girard's **proof nets** (from linear logic)

**Proof nets:** Geometric representations of linear logic proofs without syntactic bureaucracy.

### Similarities with Stellogen

#### 1. Polarity-Based Interaction

**Interaction nets:** Nodes have **principal ports** (polarized).

**Stellogen:** Rays have **polarity** (`+`, `-`, neutral).

#### 2. Interaction Rules

**Interaction nets:** Active pairs trigger rewriting.

**Stellogen:** Complementary polarities trigger fusion.

```stellogen
[(+add 0 Y Y)]              ' Positive
[(-add X Y Z) ...]          ' Negative
' When they meet → interaction
```

#### 3. Theoretical Foundation

Both inspired by **Girard's linear logic** and **proof theory**.

#### 4. No Fixed Logic

**Interaction nets:** Users define their own interaction rules—the formalism is generic.

**Stellogen:** Users define constellations—the language is logic-agnostic.

### Differences from Stellogen

#### 1. Representation

**Interaction nets:** **Graphs** (nodes and edges).

**Stellogen:** **Terms** (symbolic expressions).

#### 2. Syntax

**Interaction nets:** Typically graphical or low-level notation.

**Stellogen:** S-expression-based syntax.

#### 3. Level of Abstraction

**Interaction nets:** Low-level formalism (implementation detail).

**Stellogen:** High-level programming language.

### Summary: Interaction Nets vs Stellogen

| Aspect | Interaction Nets | Stellogen |
|--------|------------------|-----------|
| Representation | Graphs | Terms |
| Polarity | Yes (principal ports) | Yes (ray polarity) |
| Interaction | Graph rewriting | Term fusion |
| Level | Low-level formalism | High-level language |

**Key insight:** Stellogen can be seen as a **term-based, high-level language** inspired by the principles of interaction nets and proof nets, but expressed symbolically rather than graphically.

---

## Term Rewriting Systems

### Overview

**Term rewriting systems (TRS)** are computational models based on:
- Terms (expressions)
- Rewrite rules: `left-hand side → right-hand side`
- Pattern matching and substitution
- Confluence, termination analysis

**Examples:** CafeOBJ, Maude, ASF+SDF

### Similarities with Stellogen

#### 1. Terms

Both use **terms** as the basic data structure.

**TRS:**
```
f(a, b)
g(f(X, Y), Z)
```

**Stellogen:**
```stellogen
(f a b)
(g (f X Y) Z)
```

#### 2. Pattern Matching

Both use **pattern matching** to trigger transformations.

**TRS:**
```
add(0, Y) → Y
add(s(X), Y) → s(add(X, Y))
```

**Stellogen:**
```stellogen
[(+add 0 Y Y)]
[(-add X Y Z) (+add (s X) Y (s Z))]
```

#### 3. Rewriting

**TRS:** Terms are rewritten according to rules.

**Stellogen:** Terms interact and fuse according to polarity.

### Differences from Stellogen

#### 1. Polarity

**TRS:** No polarity—rewrite rules are directional but not polarized.

**Stellogen:** Polarity is fundamental.

#### 2. Interaction vs Rewriting

**TRS:** **Rewriting**—replacing a term with another.

**Stellogen:** **Interaction**—fusing complementary terms.

#### 3. Confluence

**TRS:** Much research on **confluence** (Church-Rosser property) and termination.

**Stellogen:** No formal analysis of confluence yet (research language).

### Summary: TRS vs Stellogen

| Aspect | TRS | Stellogen |
|--------|-----|-----------|
| Foundation | Rewrite rules | Polarity interaction |
| Direction | Rules are directional | Polarities are complementary |
| Analysis | Confluence, termination | Not formalized yet |

**Key insight:** Stellogen shares the term-based foundation with TRS but adds polarity, changing the computational model from rewriting to interaction.

---

## Concatenative Languages

### Overview

**Concatenative languages** (e.g., Forth, Joy, Factor) are based on:
- Stack-based evaluation
- Function composition (concatenation)
- No variable names (point-free style)
- Minimalism

### Similarities with Stellogen

#### 1. Minimalism

Both embrace minimalism—small sets of primitives.

**Forth:** Stack + words (operations).

**Stellogen:** Terms + interaction.

#### 2. Composition

**Concatenative languages:** Compose by juxtaposition.

```forth
: square dup * ;
5 square .  \ 25
```

**Stellogen:** Compose via constellations and process.

```stellogen
(process
  #step1
  #step2
  #step3)
```

#### 3. Stack Notation

Stellogen has **stack notation** sugar: `<f a b c>` ≡ `(f (a (b c)))`.

```stellogen
<s s 0>  ' ≡ (s (s 0))
```

### Differences from Stellogen

#### 1. Stack-Based vs Term-Based

**Concatenative languages:** Stack is the primary data structure.

```forth
5 3 +  \ Push 5, push 3, pop both and push sum (8)
```

**Stellogen:** Terms are the primary structure—no implicit stack.

#### 2. Point-Free

**Concatenative languages:** No variable names—everything is point-free.

```joy
square == dup *
```

**Stellogen:** Variables are explicit (uppercase).

```stellogen
(:= square [(-square X R) (+mult X X R)])
```

### Summary: Concatenative vs Stellogen

| Aspect | Concatenative | Stellogen |
|--------|---------------|-----------|
| Foundation | Stack + composition | Terms + interaction |
| Variables | No (point-free) | Yes |
| Minimalism | Yes | Yes |

**Key insight:** Both are minimalist, but concatenative languages are stack-based and point-free, while Stellogen is term-based with explicit variables.

---

## Unique Aspects of Stellogen

Having compared Stellogen to related languages, we can now identify what makes it **unique**:

### 1. Logic-Agnostic Foundation

**Stellogen does not impose a fixed logic or type system.** Users define their own semantics.

- Not committed to classical logic (like Prolog)
- Not committed to intuitionistic logic (like Coq)
- Not committed to linear logic (though inspired by it)

**User defines meaning:**
```stellogen
' You define what "add" means
(:= add { ... })

' You define what "nat" type means
(spec nat { ... })
```

### 2. Polarity as a First-Class Concept

**Polarity drives computation**, not function application or rewriting.

```stellogen
[(+f X) ...]   ' Provides
[(-f X) ...]   ' Requires
```

This is inspired by:
- Proof theory (positive vs negative formulas)
- Linear logic (polarized connectives)
- Interaction nets (principal ports)

But Stellogen makes it **explicit and user-controlled**.

### 3. Explicit Evaluation Control

Most languages evaluate automatically. Stellogen gives **fine-grained control**:

```stellogen
#x            ' Reference (no evaluation)
@#x           ' Focus (evaluate)
(interact #x #y)   ' Non-linear interaction
(fire #x #y)       ' Linear interaction
(process #a #b #c) ' Chained interaction
(eval #x)          ' Meta-level evaluation
```

### 4. Types as Interactive Tests

**Types are not annotations or static checks**—they are **runtime constellations** that interact with values.

```stellogen
(spec nat {
  [(-nat 0) ok]
  [(-nat (s N)) (+nat N)]})

(:= zero (+nat 0))
(:: zero nat)
' Type check ≡ (== @(interact @#zero #nat) ok)
```

This is a radically different approach from all other languages.

### 5. Constellations: Unordered Sets of Stars

**Constellations** are the computational units—unordered sets of stars (rays with potential focus).

```stellogen
(:= example {
  [(+f a) result1]
  [(+f b) result2]
  [(-g X) (+f X)]})
```

This is different from:
- Prolog clauses (ordered)
- Functions (have a defined head)
- Objects (have identity and state)

### 6. Multi-Paradigm Without Commitment

Stellogen supports **all paradigms** without committing to any:

| Paradigm | Stellogen Encoding |
|----------|-------------------|
| Logic | Constellations as clauses |
| Functional | Layered constellations enforcing order |
| Imperative | Iterative recipes (process) |
| Object-oriented | Structured constellations (records) |

**No paradigm is privileged**—the user chooses the pattern.

### 7. Metaprogramming at the Core

Macros are not an add-on—they're **fundamental** to how Stellogen is extended.

```stellogen
(new-declaration (spec X Y) (:= X Y))
(new-declaration (:: Tested Test) ...)
```

Users define new declaration forms, not just syntactic sugar.

### 8. Inspiration from Transcendental Syntax

From `README.md`:
> It has been designed from concepts of Girard's transcendental syntax.

**Transcendental syntax** (Girard) is a radical rethinking of logic and syntax:
- Syntax that doesn't impose logic
- Logic emerges from interaction
- No fixed rules—everything is dynamic

Stellogen embodies this philosophy—no imposed logic, user-driven semantics.

---

## Positioning in the Language Landscape

### Stellogen's Niche

Stellogen occupies a **unique position** in the programming language landscape:

```
                    LOGIC PROGRAMMING
                           |
              Prolog       |      Datalog
                  \        |        /
                   \       |       /
                    \      |      /
           Mercury   \     |     /   MiniKanren
              (typed) \    |    /  (relational)
                       \   |   /
                        \  |  /
        Curry -------- STELLOGEN -------- Linear Logic Languages
    (functional-        (polarity,            (resource-aware)
      logic)         unification,
                     logic-agnostic)
                          /   \
                         /     \
                        /       \
                  Lisp/Scheme  Interaction Nets
                (metaprogramming) (graph rewriting)
                       |              |
                  Smalltalk      Proof Nets
                 (minimalism)  (proof theory)
```

**Stellogen is at the intersection of:**
1. **Logic programming** (unification, relations)
2. **Proof theory** (polarity, linearity)
3. **Metaprogramming** (macros, user-defined semantics)
4. **Minimalism** (small core, emergent complexity)

### What Stellogen Is NOT

To understand Stellogen, it's also important to clarify what it's **not**:

1. **Not a Prolog replacement**: No backtracking, different control model
2. **Not a functional language**: No inherent lambda or application
3. **Not typed**: Types are optional and runtime-based
4. **Not production-ready**: Experimental/research language
5. **Not specialized**: Not tied to any specific domain or paradigm

### Stellogen's Purpose

From `README.md`:
> The goal is not to replace existing languages, but to **test how far this idea can be pushed** and what new programming paradigms might emerge from it.

Stellogen is a **research language** exploring:
- What happens when you build a language on **pure unification + polarity**?
- Can a language be **truly logic-agnostic**?
- How do users define semantics without imposed structure?
- What patterns emerge from polarity-driven interaction?

---

## Conclusion

### Summary of Comparisons

| Language/System | Shared Concepts | Key Differences |
|-----------------|----------------|-----------------|
| **Prolog/Datalog** | Unification, logic programming | Polarity, explicit control, no backtracking |
| **Lisp/Scheme** | S-expressions, metaprogramming, eval | Term unification vs lambda calculus |
| **MiniKanren** | Unification, relational programming | Standalone vs embedded, polarity |
| **Smalltalk** | Minimalism, message-passing metaphor | Logic-agnostic vs OO, polarity vs messages |
| **Shen** | Optional types, logic programming | Types as tests vs sequent calculus |
| **Mercury** | Logic programming | Untyped vs strongly typed, no modes |
| **Curry** | Functional logic | Logic-agnostic vs functional paradigm |
| **Lambda Prolog** | Logic programming | First-order vs higher-order |
| **Linear Logic Languages** | Linearity, polarity, resources | Logic-agnostic vs proof-theoretic |
| **Interaction Nets** | Polarity, interaction-based | Terms vs graphs, high-level vs low-level |
| **TRS** | Terms, pattern matching | Interaction vs rewriting |
| **Concatenative** | Minimalism, composition | Terms vs stack, variables vs point-free |

### Stellogen's Unique Identity

Stellogen synthesizes ideas from many sources but creates something **genuinely new**:

1. **Polarity-driven interaction** as the fundamental computational model
2. **Logic-agnostic** foundation—no imposed paradigm
3. **Types as interactive tests**—runtime, user-defined
4. **Explicit evaluation control**—fine-grained user control
5. **Multi-paradigm without commitment**—encode any pattern

### Philosophical Position

Stellogen embodies a radical idea:

> **Computation and meaning can be built from the same raw material (term unification) without types or logic imposed from above.**

This is a departure from nearly all programming languages, which either:
- Impose a logic (classical, intuitionistic, linear, etc.)
- Impose a paradigm (functional, OO, logic, etc.)
- Impose a type system (static, dynamic, dependent, etc.)

Stellogen **imposes nothing**—it provides primitives and lets users define semantics.

### Future Directions

Stellogen's approach raises interesting research questions:

1. **Expressiveness:** What can/can't be expressed in this model?
2. **Formalization:** Can we formalize polarity interaction rigorously?
3. **Performance:** How does this compare to traditional evaluation strategies?
4. **Type systems:** Can we build sophisticated type systems within this framework?
5. **Paradigms:** What new programming patterns emerge from this foundation?
6. **Applications:** Where would this approach be particularly useful?

### Final Thoughts

Stellogen is an **experimental exploration** at the boundaries of programming language design. It shares DNA with many languages—Prolog's unification, Lisp's metaprogramming, linear logic's polarity, interaction nets' dynamics—but combines them in a unique way.

Whether Stellogen-style languages become practical tools or remain theoretical curiosities, they push us to **rethink fundamental assumptions** about computation, types, and semantics.

**The key insight:** Polarity-based interaction on terms is a viable computational model that's neither functional, logical, nor imperative—it's something else, something more abstract and flexible.

**Stellogen asks:** What if we gave programmers **just terms, unification, and polarity**, and let them build everything else?

The answer is still being explored.

---

## References

### Stellogen

- Repository: https://github.com/engboris/stellogen
- Wiki: https://github.com/engboris/stellogen/wiki/Basics-of-Stellogen
- Examples: `/examples/*.sg`
- Documentation: `/docs/*.md`

### Prolog and Logic Programming

- **Prolog:** Bratko, I. (2011). *Prolog Programming for Artificial Intelligence*
- **Datalog:** Abiteboul, S., Hull, R., & Vianu, V. (1995). *Foundations of Databases*

### Linear Logic

- Girard, J.-Y. (1987). "Linear Logic"
- Girard, J.-Y. (2001). "Locus Solum: From the Rules of Logic to the Logic of Rules"

### MiniKanren

- Byrd, W. E., Holk, E., & Friedman, D. P. (2012). "miniKanren, Live and Untagged"
- The Reasoned Schemer (Friedman, Byrd, Kiselyov)

### Shen

- Tarver, M. (2015). *The Book of Shen*

### Interaction Nets

- Lafont, Y. (1990). "Interaction Nets"
- Mackie, I. (2011). "The Interaction Combinators"

### Other Languages

- **Mercury:** https://mercurylang.org/
- **Curry:** https://www-ps.informatik.uni-kiel.de/currywiki/
- **Lambda Prolog:** http://www.lix.polytechnique.fr/~dale/lProlog/

---

**Document Version:** 1.0
**Last Updated:** 2025-10-12
**Author:** Research analysis of Stellogen's position in the programming language landscape
