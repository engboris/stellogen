## Construction process

We can chain constellations with the expression `process ... end`:

```
c = process
  +n0(0).
  -n0(X) +n1(s(X)).
  -n1(X) +n2(s(X)).
end
```

This chain starts with the first constellation `+n0(0)` as a state space. The
next constellation then interacts as an action space with the previous one 
seen as a state space). Thus we
have an interaction chain with a complete focus on the previous result.

It's as if we did the following computation:

```
@+n0(0);
-n0(X) +n1(s(X)).
```

yielding

```
+n1(s(0)).
```

then

```
@+n1(s(0));
-n1(X) +n2(s(X)).
```

yielding

```
+n2(s(s(0))).
```

> This is what corresponds to tactics in proof assistants such as Coq and could
be assimilated to imperative programs which alter state representations
(memory, for example).

> Dynamical constructions correspond to the notion of "proof-process" in Boris
Eng or "proof-trace" in Pablo Donato. Proof-processes construct proof-objects
(constellations).

## Process termination

In the result of an execution, if we represent results as rays with zero
polarity, then stars containing polarized rays can be interpreted as
incomplete computations that could be discarded.

To achieve this in construction processes, we can use the special `#kill`
expression:

```
c = process
  +n0(0).
  -n0(X) +n1(s(X)).
  -n1(X) +n2(s(X)).
  -n2(X) result(X); -n2(X) +n3(X).
  #kill.
end

show-exec c.
```

We used a ray `+n3(X)` to continue computations if desired. The result is stored in `result(X)`.
However, if we want to keep only the result and eliminate any further
computation possibilities, we can use `#kill`.

## Process Cleanup

Sometimes we encounter empty stars `[]` in processes. These can be removed
using the `#clean` command:

```
show-exec process
  +f(0).
  -f(X).
  #clean.
end
```
