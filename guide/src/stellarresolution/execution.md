# Execution of Constellations

## Fusion of Stars

Stars interact with each other using an operation called fusion (which can be
likened to an interaction protocol) based on the principle of *Robinson's
resolution rule*.

The fusion of two stars:

```
r r1 ... rk
```

and

```
r' r1' ... rk'
```

along their rays `r` and `r'` is defined by a new star:

```
theta(r1) ... theta(rk) theta(r1') ... theta(rk')
```

where `theta` is the most general substitution induced by `r` and `r'`.

Note that:

- `r` and `r'` are annihilated during the fusion;
- the two stars merge;
- the substitution obtained from resolving the conflict between `r` and `r'`
propagates to the adjacent rays.

> **Example:** The fusion of `X +f(X)` and `-f(a)` makes `+f(X)` and
`-f(a)` interact, propagating the substitution `{X:=a}` to the remaining
ray `X`. The result is `X{X:=a}`, i.e., `a`.

> This fusion operation corresponds to the cut rule in first-order logic (also
linked to the resolution rule). However, the context here is "alogical" (our
objects carry no logical meaning).

## Execution

Execution is somewhat akin to solving a puzzle or playing darts. You start with
a constellation made up of several stars. Choose some *initial stars*, then
create copies of other stars to interact with them through fusion. The process
continues until no further interactions are possible (saturation). The final
constellation is the result of the execution.

Formally, the constellation is split into two parts for execution:
- the *state space*, corresponding to stars which will be targets for
interaction;
- the *action space*, corresponding to stars which will interact with stars of
the state space.

This separation can be represented as follows, with the action space on the
left and state space on the right, separated by the symbol `|-`:

```
a1 ... an |- s1 ... sm
```

Execution proceeds as follows:
1. Select a ray `r` from a state star `s`;
2. Find all possible connections with rays `r'` from action stars `s`;
3. Duplicate `s` on the right for each such ray `r'` found;
4. Replace each copy of `s` with the fusion of `a` and `s`;
5. Repeat until no further interactions are possible in the state space.
stars.

## Focus

State stars are prefixed by `@`:

```
@+a b; [-c d].
```

```
+a b; [@-c d].
```

## Example

Consider the execution of the following constellation:

```
@+a(0(1(e)) q0);
-a(e q2) accept;
-a(0(W) q0) +a(W q0);
-a(0(W) q0) +a(W q1);
-a(1(W) q0) +a(W q0);
-a(0(W) q1) +a(W q2).
```

For the example, we surround the selected way between `>>` and `<<`.
We have the following step:

```
-a(e q2) accept;
-a(0(W) q0) +a(W q0);
-a(0(W) q0) +a(W q1);
-a(1(W) q0) +a(W q0);
-a(0(W) q1) +a(W q2);
@+a(0(1(e)) q0).
```

And the following separation:

```
-a(e q2) accept;
-a(0(W) q0) +a(W q0);
-a(0(W) q0) +a(W q1);
-a(1(W) q0) +a(W q0);
-a(0(W) q1) +a(W q2)
|-
+a(0(1(e)) q0)
```

Select the first ray of the first star:

```
>>-a(e q2)<< accept;
-a(0(W) q0) +a(W q0);
-a(0(W) q0) +a(W q1);
-a(1(W) q0) +a(W q0);
-a(0(W) q1) +a(W q2)
|-
+a(0(1(e)) q0)
```

It cannot be connected to `+a(0(1(e)) q0)` because its first argument `e` is
incompatible with `0(1(e))`. However, it can interact with the two next
stars (but not the last one because of an incompatibility between `q0` and
`q1`)
We do a duplication and a fusion between:

```
-a(0(W) q0) +a(W q0);
-a(0(W) q0) +a(W q1);
```

and

```
+a(0(1(e)) q0)
```

and obtain the substitution `{W:=1(e)}` then the result:

```
+a(1(e) q0);
+a(1(e) q1)
```

We obtain the following step:

```
-a(e q2) accept;
-a(0(W) q0) +a(W q0);
-a(0(W) q0) +a(W q1);
-a(1(W) q0) +a(W q0);
-a(0(W) q1) +a(W q2)
|-
+a(1(e) q0);
+a(1(e) q1)
```

The second state star `+a(1(e) q1)` cannot interact with an action star.
However, we can focus on `+a(1(e) q0)`.

```
-a(e q2) accept;
-a(0(W) q0) +a(W q0);
-a(0(W) q0) +a(W q1);
-a(1(W) q0) +a(W q0);
-a(0(W) q1) +a(W q2)
|-
>>+a(1(e) q0)<<;
+a(1(e) q1)
```

It can connect to `-a(1(W) q0)` with substitution `{W:=e}`:

```
-a(e q2) accept;
-a(0(W) q0) +a(W q0);
-a(0(W) q0) +a(W q1);
-a(1(W) q0) +a(W q0);
-a(0(W) q1) +a(W q2)
|-
+a(e q0);
+a(1(e) q1)
```

No further interaction is possible.
The result of execution is then:

```
+a(e q0);
+a(1(e) q1)
```
