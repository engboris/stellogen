# Term Unification

## Syntax

In unification theory, we write terms. These are either:

- variables (starting with an uppercase letter, such as `X`, `Y`, or `Var`);
- functions in the form `f(t1, ..., tn)` where `f` is a function symbol
(starting with a lowercase letter or a digit) and the expressions `t1`, ...,
`tn` are other terms.

All identifiers (whether for variables or function symbols) can include the
symbols `_` and `?` (but not at the beginning).
For example : `is_empty?` and `X_1`.

> **Examples of terms.** `X`, `f(X)`, `h(a, X)`, `parent(X)`, `add(X, Y, Z)`.

It is also possible to omit the comma separating a function's arguments when
its absence causes no ambiguity. For instance, `h(a X)` can be written instead
of `h(a, X)`.

## Principle

In unification theory, two terms are said to be unifiable when there exists a
substitution of variables that makes them identical. For example, `f(X)` and
`f(h(Y))` are unifiable with the substitution `{X:=h(Y)}` replacing `X` with
`h(Y)`.

The substitutions of interest are the most general ones. We could consider the
substitution `{X:=h(c(a)); Y:=c(a)}`, which is equally valid but unnecessarily
specific.

Another way to look at this is to think of it as connecting terms to check if
they are compatible or "fit" together:

- A variable `X` connects to anything that does not contain `X` as a subterm;
otherwise, there would be a circular dependency, such as between `X` and `f(X)`;
- A function `f(t1, ..., tn)` is compatible with `f(u1, ..., un)` where `ti` is
compatible with `ui` for every `i`.

- `f(X)` and `f(h(a))` are compatible with `{X:=h(a)}`;
- `f(X)` and `X` are incompatible;
- `f(X)` and `g(X)` are incompatible;
- `f(h(X))` and `f(h(a))` are compatible with {X:=a}.
