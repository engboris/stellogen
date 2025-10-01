# Philosophy

## Mechanics of meaning

Types, specifications, algorithms, and logical formulas are **questions** that
we pose. They carry a subjective *intention*. Programs are **answers** to
these questions. They follow an objective dynamic: they can be implicit and
evolve into an irreducible explicit form (this is execution leading to a
computational result).

The big question is: how can we determine whether we are facing an answer to a question? We need a connective framework for the interaction between questions and answers.

## Iconoclasm and decentralization

Traditionally, logic and type systems define systems with:
- classes of entities (first-order individuals and relations);
- semantic rules (the compiler/interpreter is responsible for the meaning of
expressions, and the user manipulates these expressions according to this meaning);
- forbidden interactions;
- allowed interactions.

This establishes a preconceived logical framework. In particular, compilers and
interpreters hold semantic authority: they define which questions can be asked
and how to judge whether an answer is valid.

Stellogen seeks to return semantic power to the user, making them responsible
for creating meaning through elementary building blocks that compose both
programs and types/formulas/specifications. Interpreters and compilers then
take on the role of maintaining a basic core that ensures proper connectivity
between these blocks, as well as managing metaprogramming. This shifts their
role from semantic authority to protocol and administrative evaluation.

## Meaning through experience

To determine whether a program has a certain type (if an answer satisfies a
question), we proceed as follows:
- we construct a type by defining a set of tests that must be passed—these
tests are themselves programs;
- we build a "judge" that determines what it means to "pass a test";
- we connect a program to each test of the type and check whether the judge
validates all interactions.

This provides non-systemic, local guarantees, similar to "assert" statements in
programming. We could choose to organize types and constraints within
structured systems if needed.

## Order in chaos

The computational model we work with, based on elementary building blocks,
could be described as chaotic. It is possible to write unintuitive constructs
with unpredictable outcomes. In some cases, confluence does not even hold 
different execution orders lead to different results).

There are two ways to bring order to chaos:
- natural, local emergence by creating local guarantees on program fragments;
- imposing a closed system that defines restrictions/constraints in which only
certain types can be used.

Stellogen aims to leave both possibilities open. The first choice allows for
great flexibility, while the second provides efficiency and usability
advantages, along with stronger guarantees.

## Partial verification

From a programming perspective, particularly in formal methods, Stellogen is
driven by a notion of "partial" verification, in contrast to total
verification, where a program and its properties are fully modeled to obtain
formal proofs.

Stellogen focuses on expressive local constraints that could later be
integrated into a broader system.
