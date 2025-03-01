# Galaxies

Constellations can be represented by labelling sub-constellations.
This is what we call *galaxies*.

Galaxies are defined with blocks `galaxy ... end` containing a series of labels
`label =` followed by the associated galaxy:

```
g = galaxy
  test1 = +f(a) ok.
  test2 = +f(b) ok.
end
```

Fields of a galaxy are then accessed with `->`:

```
show #g->test1.
show #g->test2.
```

> This resembles the concept of a record in programming, except that when
> galaxies are used, they are represented by their underlying constellation (by
> forgetting the labels).
