# Incremental Parser Implementation

This document provides a quick reference for the incremental parser implementation in Stellogen.

## Overview

**The Stellogen parser now uses Menhir's incremental API by default.** The traditional parser has been completely replaced with the incremental parser in `src/sgen_parsing.ml`.

## Files Modified

- **`src/sgen_parsing.ml`** - Main parser now uses incremental API (replaced traditional parser)
- **`docs/incremental_parsing.md`** - Comprehensive documentation

## Quick Start

The parser is used automatically by all Stellogen code:

```ocaml
(* Standard usage - automatically uses incremental parser *)
let lexbuf = Sedlexing.Utf8.from_string "(:= x 42)" in
let exprs = Sgen_parsing.parse_with_error "<input>" lexbuf
```

## Key Components

### Checkpoint Type
The parser state is represented by `Parser.MenhirInterpreter.checkpoint`:
- `InputNeeded` - needs more input
- `Shifting` / `AboutToReduce` - internal states
- `Accepted result` - success
- `HandlingError` / `Rejected` - errors

### API Functions
- `Parser.Incremental.expr_file` - create initial checkpoint
- `Parser.MenhirInterpreter.offer` - supply token
- `Parser.MenhirInterpreter.resume` - continue parsing

## Configuration

Already enabled in `src/dune`:
```lisp
(menhir
 (modules parser)
 (flags --table --dump --explain))
```

The `--table` flag enables the incremental API.

## Testing

All existing tests now use the incremental parser:

```bash
# Run all tests
dune test

# Run specific example
dune exec sgen run -- examples/nat.sg
```

## Use Cases

1. **REPL** - parse partial input interactively
2. **IDE features** - syntax highlighting, error recovery
3. **Incremental compilation** - reparse only changed sections
4. **Better error messages** - access to parser state

## See Also

- `docs/incremental_parsing.md` - Full documentation
- [Menhir Manual](https://gallium.inria.fr/~fpottier/menhir/manual.html)
- `src/sgen_parsing.ml` - Incremental parser implementation
- `src/parser.mly` - Parser grammar
