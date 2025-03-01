# Définir des constellations

## Définitions statiques

On peut nommer des constellations que l'on écrit directement. Les identifiants
suivent les mêmes règles que pour les symboles de fonction des rayons.

```
w = a.
x = +a; -a b.
z = { -f(X) }.
```

Lorsque l'on se réfère à un identifiant de constellation, on utilise le
préfixe `#`:

```
y = #x.
```

Comme pour l'application en programmation fonctionnelle, l'union de
constellations est notée avec un espacement :

```
union1 = #x #y #z.
```

On peut aussi ajouter des parenthèses autour des expressions pour
plus de lisibilité ou pour éviter des ambiguïtés syntaxiques :

```
union1 = (#x #y) #z.
```

Mais il faut noter que contrairement à la programmation fonctionnelle,
il n'y a pas d'ordre défini.

> Les définitions statiques correspondent à la notion "d'objet-preuve"
> dans la correspondance de Curry-Howard.

## Focus

On peut mettre le focus sur toutes les étoiles d'une constellation en
la préfixant aussi avec `@` et en l'entourant de parenthèses :

```
x = +a; -a b.
z = -f(X).
union1 = @#x #z.
```

## Contraintes d'inégalité

Il est possible d'ajouter une séquence de contraintes d'inégalités
entre des termes :

```
ineq = +f(a); +f(b); @-f(X) -f(Y) r(X Y) | X!=Y.
```

Cela rend invalide toute interaction où `X` et `Y` sont totalement définies
(absence de variables) et instanciées avec la même valeur.

Ces inégalités peuvent être séparées par des espaces ou des virgules :

```
X!=Y X!=Z
```

ou

```
X!=Y, X!=Z
```

## Pre-execution

L'exécution d'une constellation dans un bloc `exec ... end` définit aussi
une constellation :

```
exec +f(X); -f(a) end
```
