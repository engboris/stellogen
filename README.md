# Stellogen

**Note: this project is an experimental proof of concept, not a fully
designed or specified programming language. It is better understood as a
research project or an esoteric language.**

Stellogen is a *logic-agnostic* programming language based on term unification.
It has been designed from concepts of Girard's transcendental syntax.

## Key characteristics

- **typable** but without primitive types nor type systems
- both computation and typing are based on basic **term unification** between
blocks of terms.

It is multi-paradigm:
- _logic programs_ called "constellations" are the elementary blocks of
programming;
- _functional programs_ correspond to layered constellations enforcing an order
of interaction;
- _imperative programs_ are iterative recipes constructing constellations;
- _objects_ are ways to structure constellations.

## Influences

It draws (or try to draw) inspiration from:
- Prolog/Datalog (for unification-based computation and constraint solving);
- Smalltalk (for message-passing, object-oriented paradigm and minimalism);
- Coq (for proof-as-program paradigm and iterative programming with tactics);
- Scheme/Racket (for minimalism and metaprogramming);
- Shen (for its optional type systems and its "power and responsibility"
philosophy).

## Syntax samples

Finite state machine

```
(new-declaration (:: Tested Test)
  (== @(exec { @#Tested #Test }) ok))

(spec binary {
  [(-i []) ok]
  [(-i [0|X]) (+i X)]
  [(-i [1|X]) (+i X)]})

'input words
(:= e (+i []))
(:: e binary)

(:= 0 (+i [0]))
(:: 0 binary)

(:= 000 (+i [0 0 0]))
(:: 000 binary)

(:= 010 (+i [0 1 0]))
(:: 010 binary)

(:= 110 (+i [1 1 0]))
(:: 110 binary)

'''
automaton accepting words ending with 00
'''
(:= (initial Q) [(-i W) (+a W Q)])
(:= (accept Q) [(-a [] Q) accept])
(:= (if read C1 on Q1 then Q2) [(-a [C1|W] Q1) (+a W Q2)])

(:= a1 {
  #(initial q0)
  #(accept q2)
  #(if read 0 on q0 then q0)
  #(if read 0 on q0 then q1)
  #(if read 1 on q0 then q0)
  #(if read 0 on q1 then q2)})

(:= kill (-a _ _))

<show exec { @(exec { @#e #a1 }) #kill }>
<show exec { @(exec { @#000 #a1 }) #kill }>
<show exec { @(exec { @#010 #a1 }) #kill }>
<show exec { @(exec { @#110 #a1 }) #kill }>
```

More examples can be found in `examples/`.

## Learn

This project is still in (chaotic) development, hence the syntax and features
are still changing frequently.

To learn more about the current implementation of stellogen:
- French guide (official): https://tsguide.refl.fr/
- English guide: https://tsguide.refl.fr/en/

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
