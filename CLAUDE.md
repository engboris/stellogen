# Stellogen - Project Guide for Claude Code

## Overview

Stellogen is an experimental, **logic-agnostic** programming language based on **term unification**. It explores a radically different approach to programming where both computation and meaning are built from the same raw material, without primitive types or fixed logical rules imposed from above.

**Status:** Research project / proof of concept / esoteric language (not production-ready)

## Core Philosophy

Unlike traditional typed languages where types constrain and shape program design, Stellogen offers elementary interactive building blocks where computation and meaning coexist in the same language. The compiler/interpreter's role is reduced to checking that blocks connect - semantic power and responsibility belong entirely to the user.

## How Stellogen Works - Essential Mechanics

### 1. Terms - Everything is a Term
A **term** is either:
- **Variable**: Starts with uppercase (e.g., `X`, `Y`, `Result`)
  - Variables are local to each star
- **Function**: Lowercase/special symbol start with arguments in parentheses
  - Examples: `(f X)`, `(add X Y)`, `(s (s 0))`
  - Constants (0-arg functions) can omit parentheses: `a`, `bob`, `0`

### 2. Unification - The Foundation
**Unification** = finding substitutions that make two terms identical
- `(f X)` ~ `(f (h a))` ⇒ succeeds with `{X := (h a)}`
- `(f X)` ~ `X` ⇒ fails (circular)
- `(f X)` ~ `(g X)` ⇒ fails (different head symbols)

### 3. Rays - Terms with Polarity
A **ray** is a term with polarity:
- `(+f X)` → **positive** polarity (provides/offers)
- `(-f X)` → **negative** polarity (requests/demands)
- `(f X)` → **neutral** (does not interact)

**Compatibility**: Two rays can interact if:
1. They have **opposite polarities** (+/-)
2. Their terms **unify**

Example: `(+f X)` and `(-f (h a))` are compatible → unify with `{X := (h a)}`

### 4. Stars - Blocks of Rays
A **star** is a block of rays in square brackets:
```stellogen
[(+f X) (-g Y) (result X Y)]  ' A star with 3 rays
(+f X)                         ' Single ray (brackets optional)
```

**Important**: Variables are **local to each star** - different stars have separate variable scopes.

### 5. Constellations - Groups of Stars
A **constellation** is a group of stars in curly braces:
```stellogen
{
  [(+add 0 Y Y)]
  [(-add X Y Z) (+add (s X) Y (s Z))]
}
```

Constellations are **unordered sets** - the order doesn't matter.

### 6. Focus - States vs Actions (CRITICAL)
**This is essential for execution to work!**

Stars are divided into two categories:
- **State stars** (marked with `@`): The data being computed/transformed
- **Action stars** (no `@`): The rules/program that transforms data

```stellogen
{
  [(+add 0 Y Y)]              ' Action star (rule)
  @[(-add 2 2 R) R]           ' State star (data/query)
}
```

**Intuition**:
- `@` marks what you're **computing** (targets for interaction)
- No `@` means **how** you compute (rules that can be reused)

You can focus entire constellations: `@{...}` focuses all stars inside.

### 7. Star Fusion - How Execution Works
**Fusion** = stars colliding along compatible rays and merging

When two stars have compatible rays (opposite polarity + unifiable):
1. The compatible rays **disappear** (consumed)
2. Their **substitution applies** to neighboring rays
3. The two stars **merge** into one

Example:
```stellogen
Star 1: [(+f X) X]
Star 2: [(-f a)]

Step 1: (+f X) and (-f a) are compatible
Step 2: Unify with {X := a}
Step 3: Rays disappear, substitution propagates
Result: [a]  ' The merged star
```

This is **Robinson's resolution** from formal logic!

### 8. Execution - exec and fire
**Execution** = stars interacting through fusion until no more interactions possible

```stellogen
(:= x [(+f X) X])
(:= y [(-f a)])

(exec @#x #y)   ' Non-linear: actions can be reused
(fire @#x #y)   ' Linear: actions used exactly once
```

**Execution process**:
1. Actions (non-`@` stars) are **duplicated** as needed
2. They **fuse** with state stars (`@`)
3. Continue until **saturation** (no more possible interactions)
4. Result is a new constellation

**`exec` vs `fire`**:
- `exec`: Non-linear - action stars can be reused multiple times
- `fire`: Linear - each action star used exactly once (resource-aware)

### 9. Process - Chaining Interactions
`(process c1 c2)` chains constellations:
- Execute `c1`, then merge result with `c2`, useful for building pipelines

### 10. Key Operators
- **Definition**: `(:= name value)` - bind name to value
- **Call**: `#name` - retrieve definition
- **Focus**: `@expr` - mark as state/evaluate
- **Show**: `(show expr)` - display result
- **Expect**: `(== expr1 expr2)` - assert syntactic equality
- **Match**: `(~= ray1 ray2)` - check if rays are compatible
- **Macro**: `(macro pattern expansion)` - syntactic preprocessing

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
- **Expect**: `(== expr1 expr2)` - assertion/testing (checks equality)
- **Match**: `(~= c1 c2)` - checks unifiability of constellations

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
- Expect (`==`) for equality assertions
- Match (`~=`) for unifiability checks

### Type System (Unconventional)
Types are defined as **sets of interactive tests**:
```stellogen
' Define nat type as a test constellation
(:= nat {
  [(-nat 0) ok]                ' Base case: 0 is a nat
  [(-nat (s N)) (+nat N)]})    ' Recursive: (s N) is nat if N is nat

' Macro for type checking
(macro (:: Tested Test)
  (== @(exec @#Tested #Test) ok))

' Use the type
(:= two (+nat (s (s 0))))
(:: two nat)  ' Type check passes - interaction yields ok
```

Type checking = interaction that must result in `ok`

### Common Patterns for Writing Stellogen

#### Pattern 1: Logic Programming (Prolog-style)
```stellogen
' Facts (positive rays)
(:= facts {
  [(+parent tom bob)]
  [(+parent bob ann)]})

' Rules (linking negative to positive)
(:= rules {
  [(-grandparent X Z) (-parent X Y) (+parent Y Z)]})

' Query (negative rays with focus)
(:= query @[(-grandparent tom Z) (result Z)])

' Execute
(show (exec { #facts #rules #query }))
```

**Key**: Facts are `+`, queries are `-` with `@`

#### Pattern 2: Database Queries
```stellogen
' Database (facts)
(:= employees {
  [(+employee alice engineering)]
  [(+employee bob sales)]})

' Query constellation (focused state)
(:= query {
  @[(-employee Name engineering) (result Name)]})

' Execute
(show (exec #query #employees))
```

**Key**: Query stars must be `@`-focused to be targets

#### Pattern 3: Recursive Computation
```stellogen
' Addition on natural numbers
(:= add {
  [(+add 0 Y Y)]                           ' Base case
  [(-add X Y Z) (+add (s X) Y (s Z))]})    ' Recursive case

' Query
(:= query @[(-add (s (s 0)) (s (s 0)) R) R])

(show (exec #add #query))
```

**Key**: Mix positive base cases with negative-to-positive recursive rules

#### Pattern 4: Using process for Pipelines
```stellogen
' Step 1: Transform A to B
(:= step1 {
  @[(-data X) (+intermediate (transform X))]})

' Step 2: Transform B to C
(:= step2 {
  [(-intermediate Y) (+result (process Y))]})

' Chain them
(show (process (exec #step1) #step2))
```

#### Pattern 5: Inequality Constraints
```stellogen
' Find different pairs
(:= data {
  [(+item a)]
  [(+item b)]
  @[(-item X) (-item Y) (pair X Y) || (!= X Y)]})

(show (exec #data))
```

**Key**: Use `|| (!= X Y)` after star to prevent X and Y from unifying to same value

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
(show (exec #add @#query))
```

## Example: Type Definition

```stellogen
' Macro for type specification
(macro (spec X Y) (:= X Y))

' Macro for type assertion
(macro (:: Tested Test)
  (== @(exec @#Tested #Test) ok))

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
- **Stars** are blocks of rays that can fuse
- **Focus (`@`)** is CRITICAL - marks state stars vs action stars
- Variables are **local to each star** - not shared between stars
- The evaluator orchestrates term interactions, not traditional evaluation
- Actions are **duplicated** during execution; states are **transformed**

### Common Mistakes When Writing Stellogen

❌ **Mistake 1**: Forgetting `@` on query/state stars
```stellogen
' WRONG - query has no @
(:= query [(-employee Name Dept)])
(exec #query #employees)  ' Returns {} - no state to interact with!

' CORRECT - query is focused
(:= query @[(-employee Name Dept)])
(exec #query #employees)  ' Works!
```

❌ **Mistake 2**: Thinking variables are shared between stars
```stellogen
' WRONG assumption: X is shared
{
  [(+f X)]      ' This X is local to this star
  [(-g X)]      ' This X is a DIFFERENT variable!
}

' CORRECT - X shared within ONE star
{
  [(+f X) (-g X)]  ' Same X - shared within this star
}
```

❌ **Mistake 3**: Wrong polarity direction
```stellogen
' WRONG - both negative
{
  [(-data X)]
  [(-result X)]   ' Nothing to provide data!
}

' CORRECT - provider (+) and requester (-)
{
  [(+data X)]     ' Provides
  @[(-data X)]    ' Requests
}
```

❌ **Mistake 4**: Expecting clause-based execution (Prolog style)
```stellogen
' Stellogen is NOT clause-based!
' Constellations are UNORDERED sets of stars
' Order doesn't determine execution flow
' Use polarity and focus instead
```

### Debugging tips:
- **Empty `{}`** result? Check if query stars have `@` focus
- **No interaction happening?** Verify polarity: need `+` and `-` to match
- **Variables not binding?** Remember: variables are local to each star
- Use `(show ...)` to inspect intermediate results
- Examine `examples/*.sg` for canonical usage patterns
- **Read `BASICS.md`** for fundamental mechanics
- Parser errors: check parenthesis balance and syntax sugar
- Unification failures: verify term structure and polarity
- **Test incrementally**: Start simple, add complexity gradually

## License

GPL-3.0-only

## Maintainers

- Author: Boris Eng
- Maintainer: Boris Eng

## Quick Reference Card

### Syntax Quick Lookup
```stellogen
' Comments
' single line
''' multi-line '''

' Terms
X Y Z           ' Variables (uppercase)
(f a b)         ' Function application
a bob 0         ' Constants

' Rays
(+f X)          ' Positive polarity (provides)
(-f X)          ' Negative polarity (requests)
(f X)           ' Neutral (no interaction)

' Stars and Constellations
[ray1 ray2]     ' Star (block of rays)
{ star1 star2 } ' Constellation (group of stars)
@[...]          ' Focused star (state)
[(+f X) || (!= X Y)]  ' Star with inequality constraint

' Definitions and Calls
(:= name value) ' Define
#name           ' Call/reference
@#name          ' Call and focus

' Execution
(exec c1 c2)    ' Non-linear execution
(fire c1 c2)    ' Linear execution
(process c1 c2) ' Chain constellations

' Utilities
(show expr)     ' Display result
(== e1 e2)      ' Assert equality
(~= r1 r2)      ' Check ray compatibility

' Syntactic Sugar
[a b c]         ' List: (%cons a (%cons b (%cons c %nil)))
<f a b>         ' Stack: (f (a b))
{ a b c }       ' Group: (%group a b c)

' Macros
(macro pattern expansion)
```

### Mental Model
```
FACTS (data)     = Positive rays (+)
QUERIES (goals)  = Negative rays (-) with @focus
RULES            = Stars linking negative to positive
EXECUTION        = Saturation via star fusion
```

### Typical Program Structure
```stellogen
' 1. Define facts/data (positive)
(:= facts { [(+fact1)] [(+fact2)] })

' 2. Define rules (negative -> positive)
(:= rules { [(-goal X) (+fact X)] })

' 3. Define query (negative, focused)
(:= query @[(-goal X) (result X)])

' 4. Execute
(show (exec { #facts #rules #query }))
```

---

*Last updated: 2025-10-24*
*For current implementation details, always refer to `BASICS.md`, the wiki, and source code as the language evolves rapidly.*
