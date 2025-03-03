# Interfaces

Il est possible de vérifier si une galaxie est formé d'une certaine
manière avec des champs possédant un certain nom et étant d'un certain type :

```
interface nat_pair
  n :: nat.
  m :: nat.
end

g_pair :: nat_pair.
g_pair = galaxy
  n = +nat(0).
  m = +nat(0).
end
```
