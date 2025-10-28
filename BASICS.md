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

'''
multi
line
'''
```

## Everything is a term!

In stellogen **everything** is a term.

A **term** is either:

* A variable: starts with uppercase (`X`, `Y`, `Var`).
* A function: a sequence of symbols surrounded by parentheses, beginning with a
  lowercase or special symbol, followed by terms:

```
' this program does nothing but you can check the validity of expressions
(f a X)
(:: x t)

' several terms can be on the same line
(add 2 2) (fact 3)
```

In the special case of constants (function without argument) we can omit
parentheses:

```
a
$
a $ :b c
```

## Rays and compatibility

**Unification** = finding substitutions that make two terms identical.

You can check if two terms are matchable with the term `(~= t u)` where `t` and
`u` are terms.

For example:

```stellogen
(~= (f X)  (f (h a)))  '  =>  they match with {X := (h a)}
(~= (f X)  X)          '  =>  ❌ (circular)
(~= (f X)  (g X))      '  =>  ❌ (they don't match because different head symbol)
```

A **ray** is a term with polarity:

* `(+f X)` → positive
* `(-f X)` → negative
* `(f X)`  → neutral (does not interact)

Two rays and **compatible** and can interact if they have opposite polarities
**and** their terms unify.

```stellogen
'''
(+f X) and (-f (h a)))  are compatible with {X := (h a)}
(+f X) and (+f a))      are incompatible because they have same head polarity
'''
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

## Make terms interact with Stars and Constellations

Stars and constellations are special terms which can interact with each other.

* A **star** block of rays:

```stellogen
[(+f X) (-f (h a)) (+g Y)]
```

Square brackets are omitted when there is a single ray.

* A **constellation** is a group of stars:

```stellogen
{ (+f X) [(-f X) (+g a)] }
```

Variables are local to each star. So, in the above example, the `X` in `(+f X)`
and the one in `[(-f X) (+g a)]` are not bound.

## Principles of Star Fusion

The idea of **fusion** is that stars can collide along compatible rays and merge.

When rays of two stars unify:

* They disappear (consumed).
* Their substitution applies to their neighbors rays.
* Their stars merge.

Example of interaction:

```stellogen
'''
star 1: [(+f X) X]
star 2: (-f a)

' connexion
(-f a) ------ (+f X) X

' annihilation and merge with resolution {X:=a}
X

' propagation
a         ' <-- this is the result of execution
'''
```

Note: this corresponds to the so-called Robinson's resolution rule in formal
logic.

## Focus and Action/State

For execution to even work in the first place, we need to group stars into
*actions* and *states*.

State stars are marked with `@`. They are the “targets” for interaction.
The other stars are actions.

For example:

```stellogen
' state:  @[-c d]
' action: [+a b]
(:= d { [+a b] @[-c d] })
```

**Intuition:** Focus corresponds to distinguishing **data** from
**rules/program**:

* **States** (`@`) = what you're computing (the data being transformed)
* **Actions** (no `@`) = how you compute (the rules/program that transforms)

You can also focus all stars of a constellation with `@`:

```stellogen
(:= f @{ [a] [b] [c] })
```

## Execution of Constellations

Execution = stars interacting through **fusion**.

Execution duplicates actions and fuses them with state stars until no more
interactions are possible. The result is a new constellation.

**Let's execute constellations!**

```stellogen
(:= x [(+f X) X])
(:= y (-f a))

(:= res1 (exec @#x #y))  ' normal execution
(show #res1)

(:= res2 (fire @#x #y))  ' actions are used exactly once
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
(show (exec #ineq))
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
(show (exec { #facts #rules @#query }))
```

This asks: *Who are the children of `b`?*

---

## Expect assertion

This is a more strict version of the matching `~=` term which expects
syntactic equality.

```stellogen
(== a a)    ' does nothing
' (== a b)  ' fails with an error
```

---

## Advanced syntax manipulation

### Parametric definitions

Definitions are actually terms like others so they can be *parametric*:

```stellogen
(:= (initial Q) [(-i W) (+a W Q)])
```

In this case, calling

```stellogen
#(initial q0)
```

will replace `Q` by `q0` in `[(-i W) (+a W Q)]` so we get

```stellogen
[(-i W) (+a W q0)]
```

### Macros

**Macros** work like definitions except that are applied before actual
execution in a preprocessing phase:

```
' replace (spec X Y) by (:= X Y) everywhere in the code
(macro (spec X Y) (:= X Y))
```

Notice that they do not involve any call with `#`, they replace terms.

### Nested phantom constellations

Some terms like `:=`, `show` or `==` are not interactive terms which can
be executed as constellations but they have an effect on the environement.

In fact, they can occur anywhere in the code and produce an effect when
evaluated but they and considered like empty constellations `{}`.

For example:

```stellogen
(exec [(+f X) X] (-f a) (:= x "Hello1"))
(show #x)
(:= y (show "Hello2"))
#y
```

---

## File import

It is possible to import the content of a file through their relative path:

```stellogen
(use "filename")
```

For macros use:

```stellogen
(use-macros "filename")
```

Because macros are applied before actual execution.

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
(macro (:: Tested Test) (== @(exec @#Tested #Test) ok))
```

It says that a `Tested` is of type `Test` when their interaction with focus on
`Tested` is equal to `ok`.

A constellation can have one or several types:

```stellogen
' passes the test
(:= 2 (+nat <s s 0>))
(:: 2 nat)

' does not pass the test
(:= 2 (+nat 2)
' (:: 2 nat)
```

Notice that a constellation can have several types providing it passes all
the tests of those types.
