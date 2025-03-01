# Reactive effects

Stellogen uses "reactive effects" which are activated during the
interaction between two rays using special head symbols.

## Print

For printing, an interaction between two rays `%print` is needed.
The interaction generates a substitution defining the ray to be displayed:

```
+%print(X); -%print("hello world\n").
```

This command displays `hello world` then an end of line symbol.

## Running a constellation

When constellations produce an effect, a `run` command is available
to execute them:

```
run +%print(X); -%print("hello world\n").
```
