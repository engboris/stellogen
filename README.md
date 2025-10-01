# Stellogen

Stellogen is an experimental, "logic agnostic" language that asks: what if
programs and their meaning were built from the same raw material, term
unification, without types or logic imposed from above?

Stellogen is a *logic-agnostic* programming language based on term unification.
It has been designed from concepts of Girard's transcendental syntax.

Stellogen explores a different way of thinking about programming languages:
instead of relying on primitive types or fixed logical rules, it is built on
the simple principle of term unification. The goal is not to replace existing
languages, but to test how far this idea can be pushed and what new programming
paradigms might emerge from it.

**For the moment, it is an experimental proof of concept, not a fully
designed or specified programming language. It is better understood as a
research project or an esoteric language.**

## Philosophy

Programs exist to solve needs, but they don’t always behave as expected. To
reduce this gap, we use a separate formal language of types. Types act like
**questions** we can ask, and programs act as **answers**.

This language of types is powerful, but it also shapes and constrains the way
we design programs. It defines which questions are even possible to ask. Typed
functional languages, dependent types, and other formal systems provide
remarkable guarantees, but they also impose a logic you must follow, even when
you might prefer to proceed more directly, or even outside of such a system.

Stellogen takes another path. It offers elementary interactive building blocks
where both computation and meaning live in the same language. In this setting,
compilers and interpreters no longer carry semantic authority: their role is
only to check that blocks connect. The semantic power (and the responsibility
that comes with it) belongs entirely to the user.

## Key characteristics

- Programs are **typable**, but without primitive types or predefined type
systems;
- Both computation and typing rely on the same mechanism: **term unification**.
- It is multi-paradigm:

| Paradigm        | Stellogen equivalent                                     |
| --------------- | ---------------------------------------------------------|
| Logic           | Constellations (elementary blocks)                       |
| Functional      | Layered constellations enforcing order of interaction    |
| Imperative      | Iterative recipes for building constellations            |
| Object-oriented | Structured constellations                                |

## Influences

Stellogen borrows ideas from several traditions: from **Prolog/Datalog** for
the power of unification; from **Smalltalk** for the minimalism of
message-passing and objects; from **Rocq** for the proof-as-program paradigm;
from **Scheme/Racket** for the spirit of metaprogramming; and from **Shen** for
the philosophy of optional type systems where *power comes with responsibility*.

## How it works

The language uses extended S-expressions.

Here is a commented example of the definition of a finite state machine
accepting words ending with `00`.

```
' We define a macro 'spec' for type definition
' It is just an alias for the definition [:=]
(new-declaration (spec X Y) (:= X Y))

' We define a macro for type assertion
(new-declaration (:: Tested Test)
  (== @(interact @#Tested #Test) ok)) ' triggers interaction and expects [ok]

' The type [binary] is defined as a set of three interactive tests
' According to the previous macro, the tests pass when interaction gives [ok]
(spec binary {
  [(-i []) ok]          ' returns [ok] on empty list
  [(-i [0|X]) (+i X)]   ' matches on [0] and checks the tail
  [(-i [1|X]) (+i X)]}) ' matches on [1] and checks the tail
                        ' otherwise the term remains unchanged

' We define some words
(:= word1 (+i [0 1 1]))
(:= word2 (+i [2 3]))

' succeeds -> [ok] is obtained on interaction with test [binary]
(:: word1 binary)

' fails
' (:: word2 binary)
```

More examples can be found in `examples/`.

## Learn

This project is still in development, hence the syntax and features
are still changing frequently.

To learn more about the current implementation of stellogen:

https://github.com/engboris/stellogen/wiki/Basics-of-Stellogen

A more complete guide is in production.

# Use

You can either download a
[released binary](https://github.com/engboris/stellogen/releases)
(or ask for a binary), install using
[opam](https://opam.ocaml.org/), or build the program from sources.

## Install using opam

Install [opam](https://ocaml.org/docs/installing-ocaml).

Install the latest development version of the package from this repo with

```
opam pin tsyntax https://github.com/engboris/stellogen.git
```

## Build from sources

Install `opam` and OCaml from `opam` : https://ocaml.org/docs/installing-ocaml

Install `dune`:
```
opam install dune
```

Install dependencies
```
opam install . --deps-only --with-test
```

Build the project
```
dune build
```

Executables are in `_build/default/bin/`.

## Build from sources using Nix

Install dependencies
```
nix develop
```

Build the project
```
dune build
```

Executables are in `_build/default/bin/`.

## Commands

Assume the executable is named `sgen.exe`. Interpreter Stellogen programs with:

```
./sgen.exe run <inputfile>
```

or if you use Dune:

```
dune exec sgen run -- <inputfile>
```

For other commands, use the `--help` flag at the end of the command.
