# Programmation logique

Les constellations sont des sortes de programmes logiques comme dans
Prolog. C'est la matière élémentaire à tout faire.

En programmation logique, on voit les rayons comme des prédicats, des
propriétés ou des relations :

```
'a is the child of b
childOf(a b).
```

Les rayons positifs sont des sorties/conclusions et les rayons négatifs
sont des entrées/hypothèses. Avec les rayons, on peut créer des faits
(vérités d'une base de connaissance) :

```
'knowledge base
+childOf(a b).
+childOf(a c).
+childOf(c d).
```

mais aussi des règles d'inférence :

```
-childOf(X Y) -childOf(Y Z) +grandParentOf(Z X).
```

Les faits et règles d'inférence vont former des étoiles d'actions qui
vont interagir avec une étoile de *requête* qui permet de poser des
questions comme on ferait une requête à une base de donnée :

```
-childOf(X b) res(X).
```

On renvoie un résultat qui nous dira qui sont les enfants de `b`.

Contrairement à des langages dédiés à ce genre d'opération comme Prolog,
dans Stellogen, il faudra organiser et déclencher des interactions :

```
knowledge =
  +childOf(a b);
  +childOf(a c);
  +childOf(c d);
  -childOf(X Y) -childOf(Y Z) +grandParentOf(Z X).

query = -childOf(X b) res(X).

show-exec #knowledge @#query.
```
