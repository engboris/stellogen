# Stellogen - Project Guide for Claude Code

## Overview

Stellogen is an experimental, **logic-agnostic** programming language based on **term unification**. It explores a radically different approach to programming where both computation and meaning are built from the same raw material, without primitive types or fixed logical rules imposed from above.

**Status:** Research project / proof of concept / esoteric language (not production-ready)

## Core Philosophy

Unlike traditional typed languages where types constrain and shape program design, Stellogen offers elementary interactive building blocks where computation and meaning coexist in the same language. The compiler/interpreter's role is reduced to checking that blocks connect - semantic power and responsibility belong entirely to the user.

## Key Concepts

### Term Unification
- The fundamental mechanism for both computation and typing
- Terms can be:
  - **Variables**: Uppercase start (e.g., `X`, `Y`, `Result`)
  - **Functions**: Lowercase or special symbol start (e.g., `(f X)`, `(add X Y)`)
- Unification finds substitutions that make two terms identical

### Rays and Polarity
- Computation happens through **rays** with polarity:
  - `+` positive polarity
  - `-` negative polarity
  - neutral (no prefix)
- **Fusion**: Term interaction mechanism
- Example: `(+add 0 Y Y)` and `(-add X Y Z)` can fuse during interaction

### Constellations
- Elementary computational blocks (analogous to logic clauses or functions)
- Defined using `{...}` with multiple rays/clauses
- Example:
  ```
  (:= add {
    [(+add 0 Y Y)]
    [(-add X Y Z) (+add (s X) Y (s Z))]})
  ```

### Stars and Interaction
- Stars are terms that can interact via `interact`
- `@` prefix: evaluates before interaction
- `#` prefix: reference to a defined term

## Syntax Elements

### Comments
- Single-line: `' comment text`
- Multi-line: `''' comment text '''`

### Syntactic Sugar
- **Stack notation**: `<f a b c>` equivalent to `(f (a (b c)))`
- **Cons lists**: `[1|Tail]` for list construction
- **Groups**: `{...}` for constellations
- **Process chaining**: `(process X {Y Z})` chains constellations

### Declarations
- **Definition**: `(:= name value)`
- **Macro**: `(macro (pattern) (expansion))`
- **Show**: `(show expr)` - display result
- **Expect**: Assertion/testing mechanism

### Syntax Reference
**See `examples/syntax.sg`** for comprehensive examples of all syntactic features including:
- Rays, stars, and constellations
- Focus (`@`) and identifiers (`#`)
- String literals, cons lists, and stack notation
- Linear (`fire`) vs non-linear (`interact`) execution
- Inequality constraints (`|| (!= X Y)`)
- Process chaining
- Fields and field access
- Nested structures
- File imports with `(use "path")`

### Type System (Unconventional)
Types are defined as **sets of interactive tests**:
```
(spec binary {
  [(-i []) ok]          ' returns [ok] on empty list
  [(-i [0|X]) (+i X)]   ' matches on [0] and checks the tail
  [(-i [1|X]) (+i X)]}) ' matches on [1] and checks the tail
```

Type checking: `(:: value type)` triggers interaction and expects `ok`

## Project Structure

```
stellogen/
├── src/              # OCaml source code
│   ├── sgen_ast.ml      # AST definitions
│   ├── sgen_eval.ml     # Evaluator
│   ├── sgen_parsing.ml  # Parser
│   ├── unification.ml   # Unification engine
│   ├── lexer.ml         # Lexer
│   ├── lsc_*.ml         # LSC (constellation) components
│   └── expr*.ml         # Expression handling
├── bin/              # Executable entry points
│   └── sgen.ml          # Main CLI
├── test/             # Test suite
├── examples/         # Example programs (.sg files)
│   ├── nat.sg           # Natural numbers
│   ├── prolog.sg        # Logic programming examples
│   ├── automata.sg      # Finite state machines
│   ├── lambda.sg        # Lambda calculus
│   └── ...
├── exercises/        # Learning exercises
└── nvim/             # Neovim integration
```

## Multi-Paradigm Support

| Paradigm        | Stellogen Equivalent                                  |
|-----------------|-------------------------------------------------------|
| Logic           | Constellations (elementary blocks)                    |
| Functional      | Layered constellations enforcing interaction order    |
| Imperative      | Iterative recipes for building constellations         |
| Object-oriented | Structured constellations                             |

## Building & Running

### Build from Sources (Dune)
```bash
# Install dependencies
opam install . --deps-only --with-test

# Build
dune build

# Executables in: _build/default/bin/
```

### Build with Nix
```bash
nix develop
dune build
```

### Running Programs
```bash
# Using built executable
./sgen.exe run <inputfile>

# Using Dune
dune exec sgen run -- <inputfile>

# Help
./sgen.exe --help
```

## File Extensions
- `.sg` - Stellogen source files
- `.mml` - Alternative extension (legacy?)

## Example: Natural Number Addition

```stellogen
' Define addition constellation
(:= add {
  [(+add 0 Y Y)]
  [(-add X Y Z) (+add (s X) Y (s Z))]})

' Query: 2 + 2 = R
(:= query [(-add <s s 0> <s s 0> R) R])

' Execute interaction
(show (interact #add @#query))
```

## Example: Type Definition

```stellogen
' Macro for type specification
(macro (spec X Y) (:= X Y))

' Macro for type assertion
(macro (:: Tested Test)
  (== @(interact @#Tested #Test) ok))

' Define nat type as interactive tests
(spec nat {
  [(-nat 0) ok]
  [(-nat (s N)) (+nat N)]})

' Define and check values
(:= 0 (+nat 0))
(:: 0 nat)  ' succeeds
```

## Dependencies (OCaml)
- `base` - Standard library alternative
- `menhir` - Parser generator
- `sedlex` - Unicode-friendly lexer
- `ppx_deriving` - Code generation
- `alcotest` - Testing framework

## Key Implementation Files

- `src/sgen_ast.ml` - Core AST types: `sgen_expr`, `declaration`, `program`
- `src/unification.ml` - Term unification algorithm
- `src/sgen_eval.ml` - Expression evaluator and interaction engine
- `src/lsc_ast.ml` - Low-level constellation representation
- `bin/sgen.ml` - CLI entry point

## Testing

Run tests with:
```bash
dune test
```

## Influences & Related Work

- **Prolog/Datalog**: Unification and logic programming
- **Smalltalk**: Minimalism and message-passing
- **Rocq/Coq**: Proof-as-program paradigm
- **Scheme/Racket**: Metaprogramming spirit
- **Shen**: Optional type systems philosophy
- **Girard's Transcendental Syntax**: Theoretical foundation

## Learning Resources

- **Wiki**: https://github.com/engboris/stellogen/wiki/Basics-of-Stellogen
- **Examples**: See `examples/` directory for practical demonstrations
- **README**: Project overview and philosophy

## Working with this Codebase

### When modifying:
1. The language is **experimental** - syntax and semantics change frequently
2. Understand term unification before touching `unification.ml`
3. AST changes require updates to parser, evaluator, and pretty-printer
4. Test with existing examples in `examples/` after changes
5. **Always run `dune fmt` after finishing code modifications** to ensure consistent formatting

### Important concepts for contributors:
- **Polarity** drives interaction - positive/negative rays fuse
- **Constellations** are the core computational unit
- **Stars** are terms prepared for interaction
- The evaluator orchestrates term interactions, not traditional evaluation

### Debugging tips:
- Use `(show ...)` to inspect intermediate results
- Examine `examples/*.sg` for canonical usage patterns
- Parser errors: check parenthesis balance and syntax sugar
- Unification failures: verify term structure and polarity

## License

GPL-3.0-only

## Maintainers

- Author: Boris Eng
- Maintainer: Pablo Donato

---

*Last updated: 2025-10*
*For current implementation details, always refer to the wiki and source code as the language evolves rapidly.*
