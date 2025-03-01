# Commands

## Comments

Comments begin with `'` and are written between `'''` for multi-line comments.
They are ignored during execution.

```
'this is a comment

'''
this is a
multiline comment
'''
```

## Display

To display constellations, you can use the command `show` followed by a
constellation:

```
show +a; -a b.
```

The `show` command does not execute constellation. If you want to actually
execute the constellation and display its result, use the `show-exec` command:

```
show-exec +a; -a b.
```

## Execution trace

It is possible to follow step by step the execution of a constellation:

```
ineq = +f(a); +f(b); @-f(X) -f(Y) r(X Y) | X!=Y.
'trace ineq.
```
