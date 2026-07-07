# Canonical Stellogen Examples

Read these files for reference patterns before writing code.

## Proof Structures (MLL)

- **`examples/proofnets/mll.sg`** — Multiplicative linear logic proof-structures. Axioms as binary positive stars, cuts as binary negative stars. Tensor/par use list-based addressing (`[l|X]`, `[r|X]`). Includes cut-elimination via execution and galaxy-based type checking with `spec` and linear assertion (`fire`).
- **`examples/proofnets/fomll.sg`** — Simplified first-order MLL with only axioms (`[+a +b]`) and cuts (`[-a -b]`). Shows how cut-elimination yields graph rewiring.

## Linear Lambda Calculus

- **`examples/lambda/linear_lambda.sg`** — Lambda terms encoded as MLL proof-net-style constellations. Identity function, application (id id, id x), and linear type specification via galaxies.

## State Machines

- **`examples/states/nfa.sg`** — Non-deterministic finite automata. Uses parameterised definitions (`(def (initial Q) ...)`, `(def (accept Q) ...)`, `(def (if read C1 on Q1 then Q2) ...)`). Input words typed with `spec`. Cleanup pattern with `(def kill (-a _ _))`.
- **`examples/states/npda.sg`** — Non-deterministic pushdown automata. Extends NFA with auxiliary stack. Adds `push` and stack-matching transitions.
- **`examples/states/turing.sg`** — Full Turing machine with tape representation `(+m State LeftTape CurrentSymbol RightTape)`. Head movement via cons list manipulation. Parameterised transitions for readability.

## Prelude

- **`examples/milkyway/prelude.sg`** — Standard macros: `::` (type assertion).
