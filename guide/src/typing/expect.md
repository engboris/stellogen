# Expectations

It is possible to verify whether a constellation is equal to another one
with an expectation test:

```
x :=: +f(X).
```

In particular, passing the test of some specification such as:

```
spec t = galaxy
  test1 = +f(X).
  test2 = +g(X).
end

g :: t.
```

can be reformulated in an equivalent way like this:

```
t1 :=: ok.
t1 = #g #t->test1.
t2 :=: ok.
t2 = #g #t->test2.
```
