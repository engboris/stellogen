# Introduction

Welcome to the guide to the Stellogen language.

**Please note that this guide is highly experimental and subject to frequent
changes. The language it describes is equally unstable.**

I welcome any opinions, recommendations, suggestions, or simple
questions. Feel free to contact me at
[boris.eng@proton.me](mailto:boris.eng@proton.me).

Happy reading!

Translated from the French guide by:
- noncanonicAleae
- ChatGPT 4o

## How it all began

Stellogen was created from Boris Eng's research to understand Jean-Yves
Girard's transcendent syntax program.

Transcendent syntax proposes a new foundation for logic and computation,
extending the Curry-Howard correspondence. In this new framework, logical
entities such as proofs, formulas, and concepts like truth are redefined/built
from an elementary computational model called "stellar resolution," which is a
highly flexible form of logical programming language.

To experiment with these ideas, Eng developed an interpreter called the "Large
Star Collider (LSC)" to execute stellar resolution expressions. It was
initially developed in Haskell and later reimplemented in OCaml.

Later, it became apparent that a metaprogramming language was necessary to
properly work with these objects, especially for writing proofs in linear
logic (which was the original project). This led to the creation of the
Stellogen language.

Over time, Stellogen gradually diverged from transcendent syntax to develop
its own concepts.
