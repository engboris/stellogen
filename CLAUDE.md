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
(def x [(+f X) X])
(def y [(-f a)])

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

### 9. Then - Staged Execution
`(then c1 c2 ...)` is a **built-in**: execute `c1`, feed the result
as state to `c2`, and so on - useful for building pipelines.
It is a left fold over execution: `(then a b)` = `@(exec b @a)`.
No import needed:
```stellogen
(def c (then
  (+n0 0)                 ' base constellation
  [(-n0 X) (+n1 (s X))]   ' interacts with previous result
  [(-n1 X) (+n2 (s X))])) ' interacts with previous result
(show #c)                 ' (+n2 (s (s 0)))
```
`then` is only special as the head of an expression; it remains usable as
an ordinary symbol inside terms (e.g. `#(if read 0 on q0 then q1)`).

### 10. Key Operators
- **Definition**: `(def name value)` - bind name to value
- **Spec**: `(spec name value)` - built-in synonym of `def` (marks intent: the thing defined is a test suite/type)
- **Call**: `#name` - retrieve definition
- **Focus**: `@expr` - mark as state/evaluate
- **Show**: `(show expr)` - display result
- **Expect**: `(== expr1 expr2)` - assert syntactic equality
- **Match**: `(~= ray1 ray2)` - check if rays are compatible
- **Forall**: `(forall Galaxy X body)` - evaluate `body` once per member of a galaxy, binding each to `X` (used to run every test of a type)
- **Then**: `(then c1 c2 ...)` - staged execution (built-in, see above)
- **Macro**: `(macro pattern expansion)` - syntactic preprocessing; **fixed arity only** (no `...` variadic patterns; a name may have several patterns of different arities)
- **Import**: `(use "path")` imports definitions; `(use-macros "path")` imports macros. Relative paths resolve **relative to the importing file**, not the working directory.

## Syntax Elements

### Comments
- Single-line: `' comment text`
- Multi-line: `''' comment text '''`

### Syntactic Sugar
- **Cons lists**: `[a b c]` in **term position** is `(%cons a (%cons b (%cons c %nil)))`; `[1|Tail]` for head/tail construction
- **Brackets are resolved by position**: `[...]` at constellation level is a **star**; `[...]` inside a term is a **list**
- **Groups**: `{...}` for constellations
- **Stacking**: there is NO `<f a b>` angle-bracket sugar and NO `stack` macro; write nested terms directly: `(s (s 0))`
- **Staged execution**: `(then c1 c2 ...)` — a built-in, see above

### Declarations
- **Definition**: `(def name value)`
- **Macro**: `(macro (pattern) (expansion))`
- **Show**: `(show expr)` - display result
- **Expect**: `(== expr1 expr2)` - assertion/testing (checks equality)
- **Match**: `(~= c1 c2)` - checks unifiability of constellations

### Syntax Reference
**See `examples/syntax.sg`** for comprehensive examples of all syntactic features including:
- Rays, stars, and constellations
- Focus (`@`) and identifiers (`#`)
- String literals and cons lists
- Linear (`fire`) vs non-linear (`exec`) execution
- Inequality constraints (`|| (!= X Y)`)
- Staged execution with `then` (built-in)
- Fields and field access
- Nested structures
- File imports with `(use "path")` / `(use-macros "path")`
- Expect (`==`) for equality assertions
- Match (`~=`) for unifiability checks
- Parametric definitions `(def (f a b) ...)` and calls `#(f a b)`

### Type System (Unconventional)
Types are defined as **sets of interactive tests**. Type checking =
interaction between the tested constellation and each test, whose result
is judged by a base observation (`==`).

Simple version (type = ONE test constellation):
```stellogen
' Define nat type as a test constellation
(def nat {
  [(-nat 0) ok]                ' Base case: 0 is a nat
  [(-nat (s N)) (+nat N)]})    ' Recursive: (s N) is nat if N is nat

' Macro for type checking: success = residue is exactly `ok`
(macro (:: Tested Test)
  (== @(exec @#Tested #Test) ok))

' Use the type
(def two (+nat (s (s 0))))
(:: two nat)  ' Type check passes - interaction yields ok
```

The real prelude (`examples/milkyway/prelude.sg`) is more general: a type
may be a **galaxy** of several tests, and the tested must pass **each test
separately** (in its own interaction space). That is what `forall` is for:
```stellogen
(macro (:: Tested Test)
  (forall Test T
    (== @(exec @#Tested #T) ok)))
```

The success convention is deliberately user-defined: different practices
judge differently (e.g. `examples/proofnets/mll.sg` defines `::lin` using
linear `fire` instead of `exec`). The fixed, trusted part is only the base
observations `==`/`~=`; every checking macro must bottom out in them.

### Common Patterns for Writing Stellogen

#### Pattern 1: Relational/Logic Programming (saturation-style, NOT Prolog)
```stellogen
' Facts (positive rays)
(def facts {
  [(+parent tom bob)]
  [(+parent bob ann)]})

' Rule: POSITIVE head (conclusion), NEGATIVE premises
(def rules {
  [(+grandparent X Z) (-parent X Y) (-parent Y Z)]})

' Query (negative ray with focus)
(show (exec { #facts #rules } @[(-grandparent tom Z) (result Z)]))
' => (result ann)
```

**Key**: Facts are `+`; rule heads are `+` and rule premises are `-`;
queries are `-` with `@`. A rule head must be positive so the negative
query can fuse with it — a rule written with a negative head can never
answer a negative query.

**Warning**: putting a positive premise in a rule (e.g.
`[(+grandparent X Z) (-parent X Y) (+parent Y Z)]`) lets rule copies feed
each other and typically **diverges** under `exec`. Keep exactly one
positive ray (the conclusion) per rule.

Simple joins don't need a rule at all — put several negative rays in the
query star:
```stellogen
(show (exec #facts @[(-parent tom Y) (-parent Y Z) (grandchild Z)]))
' => (grandchild ann)
```

Execution is **saturation** (all consequences at once, Datalog-like), not
Prolog's ordered depth-first search: no clause order, no cut, and failed
branches leave stuck residue stars instead of silently backtracking.

#### Pattern 2: Database Queries
```stellogen
' Database (facts)
(def employees {
  [(+employee alice engineering)]
  [(+employee bob sales)]})

' Query constellation (focused state)
(def query {
  @[(-employee Name engineering) (result Name)]})

' Execute
(show (exec #query #employees))
```

**Key**: Query stars must be `@`-focused to be targets

#### Pattern 3: Recursive Computation
```stellogen
' Addition on natural numbers
(def add {
  [(+add 0 Y Y)]                           ' Base case
  [(-add X Y Z) (+add (s X) Y (s Z))]})    ' Recursive case

' Query
(def query @[(-add (s (s 0)) (s (s 0)) R) R])

(show (exec #add #query))
```

**Key**: Mix positive base cases with negative-to-positive recursive rules

#### Pattern 4: Using then for Pipelines
```stellogen
(def c (then                ' then is a built-in, no import needed
  (+n0 0)                 ' base constellation (becomes the state)
  [(-n0 X) (+n1 (s X))]   ' step 1: consumes the previous result
  [(-n1 X) (+n2 (s X))])) ' step 2: consumes step 1's result
(show #c)                 ' => (+n2 (s (s 0)))
```
Each step is executed with the accumulated result focused as state:
`(then A B)` desugars to `@(exec B @A)`, chained left-associatively.

#### Pattern 5: Inequality Constraints
```stellogen
' Find different pairs
(def data {
  [(+item a)]
  [(+item b)]
  @[(-item X) (-item Y) (pair X Y) || (!= X Y)]})

(show (exec #data))
```

**Key**: Use `|| (!= X Y)` after star to prevent X and Y from unifying to same value

## Project Structure

```
stellogen/
├── src/                      # OCaml source code
│   ├── core/                 # Fundamental types and algorithms
│   │   ├── unification.ml       # Generic unification algorithm
│   │   ├── constellation.ml     # Rays, stars, constellations (core AST)
│   │   ├── expression.ml        # Expression types and macro expansion
│   │   ├── expression_error.ml  # Expression error types
│   │   └── syntax.ml            # High-level Stellogen AST
│   ├── parsing/              # Lexing, parsing, preprocessing
│   │   ├── parse_error.ml       # Parse error handling
│   │   └── stellogen_parsing.ml # Parser integration and imports
│   ├── eval/                 # Evaluation and execution
│   │   ├── evaluator.ml         # Main expression evaluator
│   │   ├── executor.ml          # Star fusion execution engine
│   │   └── constellation_eval.ml # Constellation evaluation helpers
│   ├── output/               # Display and visualization
│   │   ├── terminal.ml          # Terminal formatting and error display
│   │   ├── pretty.ml            # Pretty-printing for constellations
│   │   └── tracer.ml            # Execution trace visualization
│   ├── web/                  # Web-specific code
│   │   └── web_interface.ml     # Web playground interface
│   ├── lexer.ml              # Sedlex-based lexer
│   ├── parser.mly            # Menhir parser
│   └── parser_context.ml     # Parser state
├── bin/                      # Executable entry points
│   └── sgen.ml                  # Main CLI
├── test/                     # Test suite (cram tests)
├── examples/                 # Example programs (.sg files)
│   ├── hello.sg                 # Hello world
│   ├── naive_nat.sg             # Natural numbers
│   ├── syntax.sg                # Canonical syntax reference
│   ├── milkyway/                # The prelude (the :: type-assertion macro)
│   ├── lambda/                  # Lambda calculus examples
│   ├── prolog/                  # Logic programming examples
│   ├── proofnets/               # MLL proof nets (correctness as tests)
│   ├── states/                  # State machine examples
│   └── ...
├── exercises/                # Learning exercises (with solutions/)
├── ai/                       # AI-assisted research notes (strategy docs)
├── BASICS.md                 # Fundamental mechanics reference
├── web/                      # Web playground
└── nvim/                     # Neovim integration
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
./_build/default/bin/sgen.exe run <inputfile>

# Using Dune
dune exec sgen run -- <inputfile>

# Other subcommands
sgen preprocess <file>   # show code after macro expansion
sgen trace <file>        # run with interactive execution trace

# Help
sgen --help
```

**Tip**: when running with a timeout (programs can diverge), invoke the
built binary directly — `timeout -s KILL 10 ./_build/default/bin/sgen.exe
run file.sg` — because `dune exec` wraps the process and defeats `timeout`.

## File Extensions
- `.sg` - Stellogen source files

## Example: Natural Number Addition

```stellogen
' Define addition constellation
(def add {
  [(+add 0 Y Y)]
  [(-add X Y Z) (+add (s X) Y (s Z))]})

' Query: 2 + 2 = R
(def query [(-add (s (s 0)) (s (s 0)) R) R])

' Execute interaction
(show (exec #add @#query))   ' => (s (s (s (s 0))))
```

## Example: Type Definition

```stellogen
' spec is a built-in synonym of def (marks intent)

' Macro for type assertion
(macro (:: Tested Test)
  (== @(exec @#Tested #Test) ok))

' Define nat type as interactive tests
(spec nat {
  [(-nat 0) ok]
  [(-nat (s N)) (+nat N)]})

' Define and check values
(def 0 (+nat 0))
(:: 0 nat)  ' succeeds
```

## Dependencies (OCaml)
- `base` - Standard library alternative
- `menhir` - Parser generator
- `sedlex` - Unicode-friendly lexer
- `ppx_deriving` - Code generation
- `alcotest` - Testing framework

## Key Implementation Files

- `src/core/unification.ml` - Generic term unification algorithm (functor)
- `src/core/constellation.ml` - Core types: polarity, rays, stars, constellations, `Marked` module
- `src/core/syntax.ml` - High-level AST: `sgen_expr`, `program`, `env`, `err`
- `src/core/expression.ml` - Expression preprocessing and macro expansion
- `src/eval/evaluator.ml` - Main expression evaluator and interaction engine
- `src/eval/executor.ml` - Star fusion execution (queue-based algorithm)
- `src/output/pretty.ml` - Pretty-printing for terms and constellations
- `bin/sgen.ml` - CLI entry point

### Module Name Reference

| Module | Purpose |
|--------|---------|
| `Constellation` | Core types (rays, stars, constellations) |
| `Syntax` | High-level AST and error types |
| `Expression` | Macro expansion and preprocessing |
| `Evaluator` | Program evaluation |
| `Executor` | Star fusion engine |
| `Pretty` | Pretty-printing |
| `Tracer` | Execution tracing |
| `Stellogen_parsing` | Parser integration |

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
2. Understand term unification before touching `core/unification.ml`
3. AST changes require updates to parser, evaluator (`eval/evaluator.ml`), and pretty-printer (`output/pretty.ml`)
4. Test with existing examples in `examples/` after changes
5. **Always run `dune fmt` after finishing code modifications** to ensure consistent formatting
6. Key modules have `.mli` interfaces - update both implementation and interface when changing public APIs

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
(def query [(-employee Name Dept)])
(exec #query #employees)  ' Returns {} - no state to interact with!

' CORRECT - query is focused
(def query @[(-employee Name Dept)])
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
(def name value) ' Define
#name           ' Call/reference
@#name          ' Call and focus

' Execution
(exec c1 c2)    ' Non-linear execution
(fire c1 c2)    ' Linear execution
(then c1 c2)    ' Staged execution (built-in): @(exec c2 @c1)

' Utilities
(show expr)     ' Display result
(== e1 e2)      ' Assert equality
(~= r1 r2)      ' Check ray compatibility
(forall G X e)  ' Evaluate e for each member of galaxy G bound to X

' Imports
(use "path")        ' Import definitions (path relative to this file)
(use-macros "path") ' Import macros

' Syntactic Sugar
[a b c]         ' In TERM position: list (%cons a (%cons b (%cons c %nil)))
                ' At constellation level: a star of three rays!
                ' No stacking sugar: write (s (s 0)) directly
{ a b c }       ' Group: (%group a b c)

' Macros
(macro pattern expansion)
```

### Mental Model
```
FACTS (data)     = Positive rays (+)
QUERIES (goals)  = Negative rays (-) with @focus
RULES            = Stars with a POSITIVE head (conclusion)
                   and NEGATIVE premises
EXECUTION        = Saturation via star fusion
```

### Typical Program Structure
```stellogen
' 1. Define facts/data (positive)
(def facts {
  [(+parent tom bob)]
  [(+parent bob ann)]})

' 2. Define rules (positive conclusion, negative premises)
(def rules {
  [(+grandparent X Z) (-parent X Y) (-parent Y Z)]})

' 3. Execute against a focused query (negative)
(show (exec { #facts #rules } @[(-grandparent tom Z) (result Z)]))
' => (result ann)
```

---

*Last updated: 2026-07-06 — all code examples in this file are verified to run against the current implementation.*
*For current implementation details, always refer to `BASICS.md`, the wiki, and source code as the language evolves rapidly.*
