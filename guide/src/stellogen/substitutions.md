# Substitutions

Substitutions are expressions of the form `[... => ...]` replacing an entity
by another.

## Variables

Variables can be replaced by any other ray:

```
show-exec (+f(X))[X=>Y].
show-exec (+f(X))[X=>+a(X)].
```

## Function symbols

Function symbols can be replaced by other function symbols:

```
show-exec (+f(X))[+f=>+g].
show-exec (+f(X))[+f=>f].
```

We can also omit the left or right part of `=>` to add or remove a head symbol:

```
show-exec (+f(X); f(X))[=>+a].
show-exec (+f(X); f(X))[=>a].
show-exec (+f(X); f(X))[+f=>].
```

## Constellation identifiers

```
show-exec (#1 #2)[#1=>+f(X) X][#2=>-f(a)].
```
