# Defining constellations

## Static definitions

We can name constellations that are directly written. Identifiers follow the
same rules as for ray function symbols.

```
w = { a }.
x = +a; -a b.
z = -f(X).
```

When we refer to a constellation identifier, we use the prefix `#`:

```
y = #x.
```

As for application in functional programming, union of constellations is
written with a space:

```
union1 = #x #y #z.
```

We can also add parentheses around expressions for more readability or to
avoid syntactic ambiguity:

```
union1 = (#x #y) #z.
```

However, note that unlike in functional programming there is no defined
ordering.

> Static definitions correspond to the notion of "proof-object" in Curry-Howard
> correspondence.

## Focus

We can focus all stars of a constellation by prefixing it with `@` and put
it around parentheses:

```
x = +a; -a b.
z = -f(X).
union1 = @#x #z.
```

## Inequality constraints

It is possible to add a sequence of inequality contraints between terms:

```
ineq = +f(a); +f(b); @-f(X) -f(Y) r(X Y) | X!=Y.
```

This makes invalid any interaction where `X` and `Y` are fully defined
(no variable) and instanciated to the same value.

Those inequalities can be separated by spaces or commas:

```
X!=Y X!=Z
```

or

```
X!=Y, X!=Z
```

## Pre-execution

The execution of a constellation within a block `exec ... end` also defines
a constellation:

```
exec +f(X); -f(a) end
```
