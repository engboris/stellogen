# Galaxies

Les constellations peuvent être représentées en donnant un nom à des
sous-constellation les composant. On appelle cela des *galaxies*.

On définit les galaxies avec des blocs `galaxy ... end` contenant une
série d'étiquettes `label =` suivit de la galaxie associée :

```
g = galaxy
  test1 = +f(a) ok.
  test2 = +f(b) ok.
end
```

On accède ensuite aux champs d'une galaxie avec `->` :

```
show #g->test1.
show #g->test2.
```

> Cela ressemble au concept de record (enregistrement) en programmation sauf
> que lorsque les galaxies sont utilisées, elles sont représentées par leur
> constellation sous-jacente (par oubli d'étiquettes).
