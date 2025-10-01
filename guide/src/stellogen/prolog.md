# Logic programming

Constellations are sort of logic programs as in Prolog. They are all-purpose
materials.

In logic programming, rays are seen as predicates, properties or relations.

```
'a is the child of b
childOf(a b).
```

Positive rays are outputs/conclusions and negative rays are inputs/hypotheses.
With rays, it is possible to create facts (truth of a knowledge base):

```
'knowledge base
+childOf(a b).
+childOf(a c).
+childOf(c d).
```

but also inference rules:

```
-childOf(X Y) -childOf(Y Z) +grandParentOf(Z X).
```

Facts and inference rules form action stars which will interact with
*query* stars which allows to aks questions like how one queries a database:

```
-childOf(X b) res(X).
```

It returns a result telling who are the children of `b`.

Unlike dedicated languages like Prolog, in Stellogen you have to organize
en trigger interactions:

```
knowledge =
  +childOf(a b);
  +childOf(a c);
  +childOf(c d);
  -childOf(X Y) -childOf(Y Z) +grandParentOf(Z X).

query = -childOf(X b) res(X).

show-exec #knowledge @#query.
```
