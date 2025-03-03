# Interfaces

It is possible to check whether a galaxy is constructed in a certain way
with fields of some specific name and type:

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
