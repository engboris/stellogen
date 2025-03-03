# Attentes

Il est possible de vérifier si une constellation est exactement
égale à une autre constellation avec un test d'attente :

```
x :=: +f(X).
```

En particulier, le passage des tests d'une spécification comme :

```
spec t = galaxy
  test1 = +f(X).
  test2 = +g(X).
end

g :: t.
```

peut être reformulé de façon équivalente ainsi :

```
t1 :=: ok.
t1 = #g #t->test1.
t2 :=: ok.
t2 = #g #t->test2.
```
