# Learn Stellogen

Stellogen is an experimental, logic-agnostic programming language built on
**term unification**. Instead of types or fixed logic, programs and meaning are
expressed with the same raw material.

This guide walks you through the basics.

---

## Let's start!

Follow the install instructions in the README file of the repository.

Open your favorite text editor and create a file `test.sg`. If you use Linux,
you can open the watcher with `sgen watch test.sg` on your terminal. Otherwise,
you can run your file with `sgen run test.sg`.

Check that everything works fine by writing and running the following program
(if you use the watcher, it will run on change and display the result on your
terminal):

```
(show "Hello, world")
```

## Show

The `show` command is used to display an expression on the screen. It will be
useful through this whole guide.

---

## Comments

You can add comments to explain what your program does or to make it more
readable.

```stellogen
' single line
(show "Hello, world")

'''
multi
line
'''
```

## Terms and Unification

In stellogen **everything** is a term.

A **term** is either:

* A variable: starts with uppercase (`X`, `Y`, `Var`).
* A function: a sequence of symbols beginning with a lowercase or special
  symbol, followed by terms (`(f a X)`, `(:: x t)`).

In the special case of constants (function without argument) we can omit
parentheses (`f`, `a`, `::`).

**Unification** = finding substitutions that make two terms identical.

For example:

```stellogen
'''
(f X)  ~  (f (h a))    =>  they match with {X := (h a)}
(f X)  ~  X            =>  ❌ (circular)
(f X)  ~  (g X)        =>  ❌ (they don't match because different head symbol)
'''
```

## Rays and compatibility

A **ray** is a term with polarity:

* `(+f X)` → positive
* `(-f X)` → negative
* `(f X)`  → neutral (does not interact)

Two rays and **compatible** and can interact if they have opposite polarities
**and** their terms unify. You can check compatibility with the term
`(~= t u)` with arguments `t` and `u` which are rays.

```stellogen
(~= (+f X) (-f (h a)))   ' =>  succeeds with {X := (h a)}
(~= (+f X) (+f a))       ' =>  ❌ (fails because same polarity)
```

---

## Definitions and calls

Our most useful term will be definitions written `(:= x t)` where `x` is the
name associated to the definition and `t` is a term. For example:

```stellogen
(:= a (+f X))
```

You can invoke a definition by prefixing a name with `#`:

```stellogen
(show #a)
```

---

## Syntactic sugar

There are shorthands to build complex but useful terms.

### Cons lists

```stellogen
(show [a b c])  ' means (%cons a (%cons b %nil)), a list containing a and b
(show [])       ' means %nil, the empty list
```

### Stacks

You can accumulate application of function symbols.

```stellogen
(show <a b c>)  ' means (a (b c))
```

### Groups

```stellogen
(show { a b c })  ' means (%group a b c)
(show {})         ' means (%group), the empty group
```

---

## Stars and Constellations

* A **star** is a cons list of rays:

```stellogen
(show [(+f X) (-f (h a)) (+g Y)])
```

Square brackets are omitted when there is a single ray.

* A **constellation** is a group of stars:

```stellogen
(show { (+f X) [(-f X) (+g a)] })
```

Variables are local to each star. So, in the above example, the `X` in `(+f X)`
and the one in `[(-f X) (+g a)]` are not bound.

---

## Principles of Execution

Execution = stars interacting through **fusion** (Robinson’s resolution rule).

When rays unify:

* They disappear (consumed).
* Their substitution applies to the rest of the star.
* Stars merge.

Example of constellation:

```stellogen
(:= c { [(+f X) X] (-f a) })
```

Fusion along two matching rays: `[(+f X) X]` with `[(-f a)]` → `{X := a}`
Result: `a`.

## Focus and Action/State

Before execution, we separate stars into *actions* and *states*.

State stars are marked with `@`.
They are the “targets” for interaction.

```stellogen
(:= d { [+a b] @[-c d] })
```

**Intuition:** Focus corresponds to distinguishing **data (states)** from
**rules/program (actions)**:

* **States** (`@`) = what you're computing (the data being transformed)
* **Actions** (no `@`) = how you compute (the rules/program that transforms)

Execution duplicates actions and fuses them with state stars until no more
interactions are possible.
The result is a new constellation, like the "normal form" of computation.

You can focus all stars of a constellation with `@`:

```stellogen
(:= f @{ [a] [b] [c] })
```

## Let's execute constellations!

```stellogen
(:= x [(+f X) X])
(:= y (-f a))

(:= res1 (interact @#x #y)) ' normal execution
(show #res1)

(:= res2 (fire @#x #y))     ' actions are used exactly once
(show #res2)
```

---

## Inequality Constraints

Add constraints with `[ some star || (!= X1 Y1) ... (!= Xn Yn)]`:

```stellogen
(:= ineq {
  [(+f a)]
  [(+f b)]
  @[(-f X) (-f Y) (r X Y) || (!= X Y)]})
(show (interact #ineq))
```

where several equality constraints can be chained after `||`.

This prevents `X` and `Y` from unifying to the same concrete value.


---

## Logic Programming

Constellations can act like logic programs (à la Prolog).

### Facts

```stellogen
(:= facts {
  [(+childOf a b)]
  [(+childOf a c)]
  [(+childOf c d)]
})
```

### Rule

```stellogen
(:= rules { (-childOf X Y) (-childOf Y Z) (+grandParentOf Z X) })
```

### Query

```stellogen
[(-childOf X b) (res X)]
```

### Putting it together

```stellogen
(:= facts {
  [(+childOf a b)]
  [(+childOf a c)]
  [(+childOf c d)]
  [(-childOf X Y) (-childOf Y Z) (+grandParentOf Z X)]
})

(:= rules { (-childOf X Y) (-childOf Y Z) (+grandParentOf Z X) })

(:= query [(-childOf X b) (res X)])
(show (interact { #facts #rules @#query }))
```

This asks: *Who are the children of `b`?*

---

## Expect assertion

This is a more strict version of the matching `~=` term which expects
syntactic equality.

```
(== a a)  ' does nothing
(== a b)  ' fails with an error
```

---

## Types as Sets of Tests

In Stellogen, **types are sets of tests** that a constellation must pass to be
of that type.

For example, we define a type for natural numbers which is simply a
constellation corresponding to a "test":

```stellogen
(:= nat {
  [(-nat 0) ok]
  [(-nat (s N)) (+nat N)]})
```

A constellation must pass **all tests** to be considered of type `nat`.

We then define the behavior of type assertions with a macro:

```stellogen
(macro (:: Tested Test) (== @(interact @#Tested #Test) ok))
```

It says that a `Tested` is of type `Test` when their interaction with focus on
`Tested` is equal to `ok`.

A constellation can have one or several types:

```stellogen
(:= 2 (+nat <s s 0>))
(:: 2 nat)
```

Notice that a constellation can have several types providing it passes all
the tests of those types.
