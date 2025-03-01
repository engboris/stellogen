# Typing

Typing in Stellogen illustrates key principles of transcendental syntax, where
types are defined as *sets of tests*, themselves constructed using
constellations. Type checking involves passing all the tests associated with a
type.

Types are represented by a galaxy, where each field corresponds to a test that
must be passed:

```
t = galaxy
  test1 = @-f(X) ok; -g(X).
  test2 = @-g(X) ok; -f(X).
end
```

It is also possible to prefix the definition with a `spec` keyword to make
explicit that it is a specification:

```
spec t = galaxy
  test1 = @-f(X) ok; -g(X).
  test2 = @-g(X) ok; -f(X).
end
```

A galaxy/constellation under test must therefore *satisfy all the tests*
defined by the galaxy above to be of type `t`.

> A type with a single test can be defined as a simple constellation.

However, we still need to define what it means to:
- be confronted with a test;
- successfully pass a test.

> In line with the Curry-Howard correspondence, types can be viewed as
formulas or specifications. This can also be extended to Thomas Seiller's
proposal of viewing algorithms as more sophisticated specifications.

## Checkers

We need to define checkers, which are "judge" galaxies that specify:

- an interaction field, necessarily containing the identifiers `#tested` and `#test`. It explains how the tested and the test interact;
- an `expect` field indicating the expected result of the interaction.

For example:

```
checker = galaxy
  interaction = #tested #test.
  expect = ok.
end
```

## Test-based typing

We can then precede definitions with a type declaration:

```
c :: t [checker].
c = +f(0) +g(0).
```

The constellation `c` successfully passes the `test1` and `test2` tests of `t`.
Thus, there is no issue. We say that `c` is of type `t` or that `c` is a proof
of the formula `t`.

However, if we had a constellation that failed the tests, such as:

```
c :: t [checker].
c = +f(0).
```

We would receive an error message indicating that a test was not passed.

Here is an example of a type with a single test for a naive representation of
natural numbers:

```
spec nat =
  -nat(0) ok;
  -nat(s(N)) +nat(N).

0 :: nat [checker].
0 = +nat(0).

1 :: nat [checker].
1 = +nat(s(0)).
```

We can also omit specifying the checker. In this case, the default checker is:

```
checker = galaxy
  interaction = #tested #test.
  expect = ok.
end
```

This allows us to write:

```
0 :: nat.
0 = +nat(0).

1 :: nat.
1 = +nat(s(0)).
```

## Plurality of types

It is possible to associate seveeral types to a same constellation:
- either by defining several type declarations;
- or by writing sequences of types (separated by commas) when a same checker
is used.

For example:

```
nat2 = -nat(X) ok.
2 :: nat [checker].
2 :: nat2.
2 = +nat(s(s(0))).
```

````
3 :: nat, nat2.
3 = +nat(s(s(s(0)))).
```

## Interface

It is possible to define interfaces describing a series of identifiers with
a corresponding type to satisfy.

```
nat_pair = interface
  n :: nat [checker].
  m :: nat [checker].
end
```

It is then possible to ask for a galaxy to satisfy that interface.

```
g_pair :: nat_pair.
g_pair = galaxy
  n = +nat(0).
  m = +nat(0).
end
```
