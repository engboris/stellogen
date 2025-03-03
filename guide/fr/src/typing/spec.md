# Typage

Le typage dans Stellogen illustre des principes majeurs de syntaxe transcendantale
où les types sont définis comme des ensembles de *tests* eux-mêmes définis
avec des constellations. La vérification de type implique le passage de tous
les tests associés à un type.

Les types sont donnés par une galaxie où chaque champ représentent un test à faire
passer :

```
t = galaxy
  test1 = @-f(X) ok; -g(X).
  test2 = @-g(X) ok; -f(X).
end
```

On peut aussi faire précéder la définition par `spec` pour indiquer qu'il
s'agit d'une spécification :

```
spec t = galaxy
  test1 = @-f(X) ok; -g(X).
  test2 = @-g(X) ok; -f(X).
end
```

Une galaxie/constellation *testée* doit donc être confrontée à tous les tests
définis par la galaxie ci-dessous pour être de type `t`.

> Un type avec un unique test peut être défini par une simple constellation.

Il nous reste cependant à définir ce que signifient :
- être confronté à un test;
- passer un test avec succès.

> Conformément à la correspondance de Curry-Howard, les types peuvent être vus
comme des formules ou spécifications. On pourrait aussi étendre cela à la
proposition de Thomas Seiller de voir les algorithmes comme des spécifications
plus sophistiquées.

## Checkers

Il faut définir des *checkers* qui sont des galaxies "juges" définissant :
- un champ `interaction` contenant un identificateur `#tested` et `#tested`.
Ce champ explique comment faire interagir un testé et un test;
- un champ `expect` indiquant quel est le résultat attendu par l'interaction.

Par exemple :

```
checker = galaxy
  interaction = #tested #test.
  expect = ok.
end
```

## Typage par test

On peut ensuite faire précéder les définitions par une déclaration de type :

```
c :: t [checker].
c = +f(0) +g(0).
```

La constellation `c` passe bel et bien les tests `test1` et `test2` de `t`.
Il n'y a donc aucun problème. On dit donc que `c` est de type `t` ou que `c`
est une *preuve* de la formule `t`.

Cependant, si nous avions une constellation qui ne passait pas les tests, comme
:

```
c :: t [checker].
c = +f(0).
```

Nous aurions eu un message d'erreur nous indiquant qu'un test n'est pas passé.


Voici un type avec un unique test pour une représentation naïve des entiers
naturels :

```
spec nat =
  -nat(0) ok;
  -nat(s(N)) +nat(N).

0 :: nat [checker].
0 = +nat(0).

1 :: nat [checker].
1 = +nat(s(0)).
```

On peut aussi omettre de préciser le checker. Dans ce cas, le checker par
défaut est :

```
checker = galaxy
  interaction = #tested #test.
  expect = ok.
end
```

Cela nous permet d'écrire :

```
0 :: nat.
0 = +nat(0).

1 :: nat.
1 = +nat(s(0)).
```

## Pluralité des types

Il est possible d'associer plusieurs types à une constellation:
- soit en définissant plusieurs déclaration de types;
- soit en écrivant des séquences de types (séparés par des virgules) si le même
checker est utilisé.

Par exemple:

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

## Interfaces

Il est possible de définir des interfaces décrivant une liste d'identifiants
devant être d'un certain type.

```
nat_pair = interface
  n :: nat [checker].
  m :: nat [checker].
end
```

On peut ensuite demander à ce qu'une galaxie respecte cette interface.

```
g_pair :: nat_pair.
g_pair = galaxy
  n = +nat(0).
  m = +nat(0).
end
```
