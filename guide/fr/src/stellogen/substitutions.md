# Substitutions

Les substitutions sont des expressions de la forme `[... => ...]` remplaçant
une entité par une autre.

## Variables

On peut remplacer des variables par n'importe quel rayon :

```
show-exec (+f(X))[X=>Y].
show-exec (+f(X))[X=>+a(X)].
```

## Symboles de fonction

On peut remplacer les symboles de fonctions par d'autres symboles
de fonction :

```
show-exec (+f(X))[+f=>+g].
show-exec (+f(X))[+f=>f].
```

On peut aussi omettre la partie gauche ou droite de `=>` pour ajouter
ou retirer un symbole de tête :

```
show-exec (+f(X); f(X))[=>+a].
show-exec (+f(X); f(X))[=>a].
show-exec (+f(X); f(X))[+f=>].
```

## Identificateurs de constellations

```
show-exec (#1 #2)[#1=>+f(X) X][#2=>-f(a)].
```
