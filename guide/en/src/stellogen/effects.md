# Reactive effects

Stellogen uses "reactive effects" which are activated during the
interaction between two rays using special head symbols.

## Print

For printing, an interaction between two rays `%print` is needed.
The interaction generates a substitution defining the ray to be displayed:

```
run +%print(X); -%print("hello world\n").
```

This command displays `hello world` then an end of line symbol.
