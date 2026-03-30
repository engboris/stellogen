---
name: write-stellogen
description: Write Stellogen (.sg) programs. Triggers when asked to write, generate, or create Stellogen code, constellations, or stellar resolution programs.
allowed-tools: Read, Grep, Glob, Bash, Write, Edit
---

# Write Stellogen Code

You are writing code in **Stellogen**, an experimental language based on **stellar resolution** (term unification with polarities). Before writing any code, read the reference materials:

1. [patterns.md](patterns.md) — Core language patterns and mechanics
2. [examples.md](examples.md) — Index of canonical examples (read the actual `.sg` files it points to)

## Key Principles

1. **Everything is a term.** Variables are uppercase (`X`, `Y`), constants/functions are lowercase (`f`, `add`, `0`).
2. **Polarity drives interaction.** `+` provides, `-` requests. Two rays interact when they have opposite polarities and their terms unify.
3. **Stars are blocks of rays** in `[...]`. Variables are **local** to each star.
4. **Constellations are groups of stars** in `{...}`. They are unordered.
5. **Focus (`@`) is critical.** It marks state stars (data being transformed). Without `@`, nothing executes.
6. **`exec` is non-linear** (actions reused), **`fire` is linear** (actions consumed once).
7. **`process` chains** constellations sequentially.

## Writing Process

1. **Understand the domain** the user wants to encode
2. **Choose the right paradigm**: logic programming, state machines, proof structures, functional, etc.
3. **Consult examples.md** for the closest canonical pattern
4. **Write incrementally**: define data/facts first, then rules, then queries
5. **Use `show` and `==`** for testing/verification
6. **Use macros sparingly** — only when repetition is clear

## Common Mistakes to Avoid

- Forgetting `@` on query/state stars (results in empty `{}`)
- Assuming variables are shared between stars (they are LOCAL to each star)
- Wrong polarity direction (need `+` provider and `-` requester)
- Thinking execution is clause-based like Prolog (it is NOT — constellations are unordered, polarity and focus drive execution)

## Parameterised Definitions

Stellogen supports parameterised definitions which are powerful for readability:

```stellogen
(def (transition Q1 Symbol Q2) [(-a [Symbol|W] Q1) (+a W Q2)])
(def (accept Q) [(-a [] Q) accept])
```

These create reusable templates called with `#(transition q0 a q1)`.

## When Using the Prelude

If the program needs type checking (`::`, `spec`) or `stack`/`process` macros, start with:
```stellogen
(use-macros "milkyway/prelude.sg")
```

## Output

Write clean, commented Stellogen code. Use `'` comments to explain the structure. Group related definitions together. Test with `show` and `==` where appropriate.

If $ARGUMENTS is provided, treat it as the description of what to write.
