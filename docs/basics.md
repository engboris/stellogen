# Learn Stellogen

> **Disclaimer**: This document was written with the assistance of Claude Code and represents exploratory research and analysis. The content may contain inaccuracies or misinterpretations and should not be taken as definitive statements about the Stellogen language implementation.

Stellogen is an experimental, logic-agnostic programming language built on **term unification**. Instead of types or fixed logic, programs and meaning are expressed with the same raw material.

This guide walks you through the basics.

---

## Comments

```stellogen
' single line

'''
multi
line
'''
```

## Terms and Unification

A **term** is either:

* A variable: starts with uppercase (`X`, `Y`, `Var`).
* A function: a sequence beginning with a lowercase or special symbol, followed by terms (`(f a X)`).

Examples:

```stellogen
X
(f X)
(h a X)
(add X Y Z)
```

**Unification** = finding substitutions that make two terms identical.

```stellogen
'''
(f X)  ~  (f (h a))    =>  {X := (h a)}
(f X)  ~  X            =>  ❌ (circular)
(f X)  ~  (g X)        =>  ❌ (different heads)
'''
```

**All Stellogen expressions are actually terms.**

---

## Syntactic sugar

### Omission

A constant can be written without parentheses: `f` instead of `(f)`.

### Cons lists

```stellogen
[a b c]
```

means

```stellogen
(%cons a (%cons b %nil))
```

The empty list is `[]` (denoting the constant `%nil`).

### Stacks

```stellogen
<a b c>
```

is an interactive application representing

```stellogen
(a (b c))
```

### Groups

```
{ a b c }
```

means

```
(%group a b c)
```

### Special operators

Some special operators are written as prefix of the expression:

```stellogen
#(f X)
#[(f X)]
@(f X)
@[(f X)]
```

### Macros

It is possible to declare aliases for expressions:

```stellogen
(new-declaration (spec X Y) (:= X Y))
```

after this declaration, `(spec X Y)` stands for `(:= X Y)`.

---

## Rays

A **ray** is a term with polarity:

* `(+f X)` → positive
* `(-f X)` → negative
* `(f X)`  → neutral (does not interact)

Two rays interact if they have opposite polarities **and** their terms unify:

```stellogen
'''
(+f X)   ~   (-f (h a))    =>  {X := (h a)}
(+f X)   ~   (+f a)        =>  ❌ (same polarity)
'''
```

---

## Stars and Constellations

* A **star** is a cons list of rays:

  ```stellogen
  [(+f X) (-f (h a)) (+g Y)]
  ```

  Empty star: `[]`

* A **constellation** is a group of stars `{ }`:

  ```stellogen
  { (+f X) (-f X) (+g a) }
  ```

  Empty constellation: `{}`

Variables are local to each star.

---

## Execution by Fusion

Execution = stars interacting through **fusion** (Robinson’s resolution rule).

When rays unify:

* They disappear (consumed).
* Their substitution applies to the rest of the star.
* Stars merge.

Example of constellation:

```stellogen
{ [(+f X) X] [(-f a)] }
```

Fusion along two matching rays: `[(+f X) X]` with `[(-f a)]` → `{X := a}`
Result: `a`

---

## Focus and Action/State

During execution, we separate stars into *actions* and *states*.

State stars are marked with `@`.
They are the “targets” for interaction.

```stellogen
{ [+a b] @[-c d] }
```

**Intuition:** Focus corresponds to distinguishing **data (states)** from **rules/program (actions)**:

* **States** (`@`) = what you're computing (the data being transformed)
* **Actions** (no `@`) = how you compute (the rules/program that transforms)

This is like a subject-verb distinction: states are what the computation is "about", and actions are what "happens to" the states.

Execution duplicates actions and fuses them with state stars until no more interactions are possible.
The result is a new constellation, like the "normal form" of computation.

---

## Defining Constellations

You can give names to constellations with the `:=` operator:

```stellogen
(:= a)
(:= x {[+a] [-a b]})
(:= z (-f X))
```

Delimiters can be omitted when it is obvious that a single ray or star is defined.

You can refer to identifiers with `#`:

```stellogen
(:= y #x)
(:= union1 { #x #y #z })   ' unions constellations
```

Unlike functions, order does not matter.

You can focus all stars of a constellation with `@`:

```stellogen
(:= f @{ [a] [b] [c] })
```

---

## Inequality Constraints

Add constraints with `[ some star || (!= X1 Y1) ... (!= Xn Yn)]`:

```stellogen
(:= ineq {
  [(+f a)]
  [(+f b)]
  @[(-f X) (-f Y) (r X Y) || (!= X Y)]})
```

where several equality constraints can be chained after `||`.

This prevents `X` and `Y` from unifying to the same concrete value.

---

## Pre-execution

You can precompute expressions:

```stellogen
(:= x [(+f X) X])
(:= y (-f a))
(:= ex (interact @#x #y)) ' normal execution
(:= ex (fire @#x #y))     ' actions are used exactly once
```

This evaluates and stores the resulting constellation.

---

## Let's write a program

A program consists in a series of commands.

### Commands

* **Show without execution**:

  ```stellogen
  (show { [+a] [-a b] })
  ```

* **Show with execution**:

  ```stellogen
  <show interact { [+a] [-a b] }>
  ```

### Example

```stellogen
(:= add {
  [(+add 0 Y Y)]
  [(-add X Y Z) (+add (s X) Y (s Z))]})

' 2 + 2 = R
(:= query [(-add <s s 0> <s s 0> R) R])

(show (interact #add @#query))
```

---

## Logic Programming

Constellations can act like logic programs (à la Prolog).

### Facts

```stellogen
(+childOf a b)
(+childOf a c)
(+childOf c d)
```

### Rule

```stellogen
{ (-childOf X Y) (-childOf Y Z) (+grandParentOf Z X) }
```

### Query

```stellogen
[(-childOf X b) (res X)]
```

### Putting it together

```stellogen
(:= knowledge {
  [(+childOf a b)]
  [(+childOf a c)]
  [(+childOf c d)]
  [(-childOf X Y) (-childOf Y Z) (+grandParentOf Z X)]
})

(:= query [(-childOf X b) (res X)])
<show interact { #knowledge @#query }>
```

This asks: *Who are the children of `b`?*

---

## Expect assertion

```
(== x y)
```

does nothing if `x` and `y` are equal or fails with an error when they are different.

---

## Processes

A **process** chains constellations step by step:

```stellogen
(:= c (process
  (+n0 0)                 'base constellation
  [(-n0 X) (+n1 (s X))]   'interacts with previous
  [(-n1 X) (+n2 (s X))])) 'interacts with previous
(show #c)
```

It’s similar to tactics in proof assistants (Rocq) or imperative programs that update state.

---

## Types as Sets of Tests

In Stellogen, **types are sets of tests** that a constellation must pass to be of that type.

For example, we define a type for natural numbers:

```stellogen
(new-declaration (spec X Y) (:= X Y))
(spec nat {
  [(-nat 0) ok]              ' test 1
  [(-nat (s N)) (+nat N)]})  ' test 2
```

A constellation must pass **all tests** to be considered of type `nat`.

We then define the behavior of type assertions with a macro:

```stellogen
(new-declaration (:: Tested Test)
  (== @(interact @#Tested #Test) ok))
```

It says that a `Tested` is of type `Test` when their interaction with focus on `Tested` is equal to `ok`.

A constellation can have one or several types:

```stellogen
(:: 2 nat)
(:: 2 otherType)
(:: 2 otherType2)
```
