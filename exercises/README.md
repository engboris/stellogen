# Stellogen Exercises

Learn Stellogen by replacing `#your_answer` holes to make each program compile without errors.

## Exercises

| File | Topic | Concepts |
|------|-------|----------|
| `00-unification.sg` | Unification | Rays, polarity, fusion, `exec` |
| `01-paths.sg` | Interaction paths | Building constellations to complete interaction chains |
| `02-registers.sg` | Registers | `process`, state updates, duplication, swapping |
| `03-boolean.sg` | Boolean logic | Defining operations, composing constellations, queries |

## Running

```bash
# Run an exercise (will show errors for unfilled holes)
dune exec sgen run -- exercises/00-unification.sg

# Run a solution to check expected output
dune exec sgen run -- exercises/solutions/00-unification.sg
```

## Solutions

Complete solutions are in the `solutions/` directory.
