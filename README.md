# Stellogen

**Note: this project is an experimental proof of concept, not a fully
designed or specified programming language. It is better understood as a
research project or an esoteric language.**

Stellogen is a *logic-agnostic* programming language based on term unification.
It has been designed from concepts of Girard's transcendental syntax.

## Key characteristics

- dynamically/statically **typed** but without primitive types nor type systems,
by using very flexible assert-like expressions defining *sets of tests* to pass;
- everything is based on **term unification**.

It is multi-paradigm:
- _logic programs_ called "constellations" are the elementary bricks of
computation and typing;
- _functional programs_ correspond to logic programs enforcing an order of
interaction;
- _imperative programs_ are iterative recipes constructing constellations;
- _objects_ are ways to structure constellations.

## Influences

It draws (or try to draw) inspiration from:
- Prolog/Datalog (for unification-based computation and constraint solving);
- Smalltalk (for message-passing, object-oriented paradigm and minimalism);
- Coq (for proof-as-program paradigm and iterative programming with tactics);
- Scheme/Racket (for minimalism and metaprogramming);
- Haskell/Ruby/Lua (for syntax);
- Shen (for its optional type systems).

## Syntax samples

Finite state machine

```
spec binary =
  -i(e) ok;
  -i(0:X) +i(X);
  -i(1:X) +i(X).

e :: binary.
e = +i(e).

000 :: binary.
000 = +i(0:0:0:e).

010 :: binary.
010 = +i(0:1:0:e).

110 :: binary.
110 = +i(1:1:0:e).

a1 = galaxy
  initial =
    -i(W) +a(W q0).
  final =
    -a(e q2) accept.
  transitions =
    -a(0:W q0) +a(W q0);
    -a(0:W q0) +a(W q1);
    -a(1:W q0) +a(W q0);
    -a(0:W q1) +a(W q2).
end

show process #e.   #a1. %kill. end
show process #000. #a1. %kill. end
show process #010. #a1. %kill. end
show process #110. #a1. %kill. end
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
./sgen.exe <inputfile>
```

or if you use Dune:

```
dune exec sgen -- <inputfile>
```
