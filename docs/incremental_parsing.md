# Incremental Parsing with Menhir in Stellogen

> **Disclaimer**: This document was written with the assistance of Claude Code and represents exploratory research and analysis. The content may contain inaccuracies or misinterpretations and should not be taken as definitive statements about the Stellogen language implementation.

This document explains the incremental parser in Stellogen, which is built on Menhir's incremental parsing capabilities.

## Overview

**As of the latest version, the main Stellogen parser uses Menhir's incremental API by default.** The traditional parser in `Sgen_parsing.parse_with_error` has been replaced with an incremental implementation.

The incremental parser allows you to:
- Parse input step-by-step (token by token)
- Inspect parser state during parsing
- Handle errors more gracefully
- Implement features like syntax highlighting, error recovery, or incremental compilation

All existing code continues to work without changes - the switch from traditional to incremental parsing is transparent to users of the parser.

## Setup

The parser is already configured to generate the incremental API. The key configuration in `src/dune` is:

```lisp
(menhir
 (modules parser)
 (flags --table --dump --explain))
```

The `--table` flag enables the incremental API.

## API Overview

### Checkpoint Type

The core type is `Parser.MenhirInterpreter.checkpoint`, which represents the parser state. It has the following constructors:

- **`InputNeeded env`**: Parser needs another token
- **`Shifting (env1, env2, flag)`**: Parser is performing a shift operation
- **`AboutToReduce (env, production)`**: Parser is about to reduce by a production rule
- **`HandlingError env`**: Parser encountered a syntax error
- **`Accepted result`**: Parsing succeeded with the given result
- **`Rejected`**: Parsing failed completely

### Main Functions

- **`Parser.Incremental.expr_file pos`**: Create initial checkpoint for parsing
- **`Parser.MenhirInterpreter.offer checkpoint (token, start_pos, end_pos)`**: Supply a token to the parser
- **`Parser.MenhirInterpreter.resume checkpoint`**: Continue parsing after a Shifting or AboutToReduce state
- **`Parser.MenhirInterpreter.top env`**: Get the top element from the parser stack (useful for error reporting)

## Usage Examples

### Example 1: Standard Usage

The parser is used automatically throughout Stellogen:

```ocaml
(* Parse a file *)
let ic = Stdlib.open_in "examples/nat.sg" in
let lexbuf = Sedlexing.Utf8.from_channel ic in
let exprs = Sgen_parsing.parse_with_error "examples/nat.sg" lexbuf in
Stdlib.close_in ic

(* Parse a string *)
let lexbuf = Sedlexing.Utf8.from_string "(:= x 42)" in
let exprs = Sgen_parsing.parse_with_error "<string>" lexbuf
```

### Example 2: Custom Parser Loop with Direct Checkpoint Access

For maximum control, interact directly with the Menhir API:

```ocaml
let parse_custom filename lexbuf =
  Parser_context.current_filename := filename;

  (* Create token supplier *)
  let lexer_supplier () =
    let token = Lexer.read lexbuf in
    let start_pos, end_pos = Sedlexing.lexing_positions lexbuf in
    (token, start_pos, end_pos)
  in

  (* Start parsing *)
  let initial = Parser.Incremental.expr_file Lexing.dummy_pos in

  (* Drive the parser *)
  let rec loop checkpoint =
    match checkpoint with
    | Parser.MenhirInterpreter.InputNeeded _env ->
        let token, start_pos, end_pos = lexer_supplier () in
        loop (Parser.MenhirInterpreter.offer checkpoint (token, start_pos, end_pos))

    | Parser.MenhirInterpreter.Shifting _
    | Parser.MenhirInterpreter.AboutToReduce _ ->
        loop (Parser.MenhirInterpreter.resume checkpoint)

    | Parser.MenhirInterpreter.Accepted result ->
        result

    | Parser.MenhirInterpreter.HandlingError env ->
        (* Extract position information for error reporting *)
        let pos = match Parser.MenhirInterpreter.top env with
          | Some (Parser.MenhirInterpreter.Element (_, _, start_pos, _)) -> start_pos
          | None -> Lexing.dummy_pos
        in
        failwith (Printf.sprintf "Parse error at %s:%d"
          pos.Lexing.pos_fname pos.Lexing.pos_lnum)

    | Parser.MenhirInterpreter.Rejected ->
        failwith "Parse rejected"
  in
  loop initial
```

## Use Cases

### 1. Interactive REPL

Incremental parsing is perfect for REPLs where you want to:
- Parse partial input as the user types
- Provide immediate feedback on syntax errors
- Handle incomplete expressions gracefully

### 2. Syntax Highlighting

You can use the parser state to:
- Identify token types and their roles in the parse tree
- Highlight matching delimiters
- Show syntax errors in real-time

### 3. Error Recovery

**Stellogen implements comprehensive error recovery** using the incremental API:

- **Collect multiple errors** in one pass (up to 20 by default)
- **Accurate error positions** via `Parser.MenhirInterpreter.positions env`
- **Context-aware hints** to help fix common mistakes
- **Smart recovery strategies** that skip tokens and attempt to continue parsing
- **Source context display** showing the exact location of errors

See `docs/error_recovery.md` for full details on error recovery implementation and behavior.

### 4. Incremental Compilation

For large codebases:
- Parse changed sections only
- Cache parse results for unchanged code
- Speed up compilation by avoiding full re-parses

## Architecture

### Main Parser (in `sgen_parsing.ml`)

The main parser `Sgen_parsing.parse_with_error` now uses the incremental API internally:

```ocaml
let parse_with_error filename lexbuf =
  (* Create token supplier *)
  let lexer_supplier () =
    let token = read lexbuf in
    let start_pos, end_pos = Sedlexing.lexing_positions lexbuf in
    (token, start_pos, end_pos)
  in

  (* Start incremental parsing *)
  let initial_checkpoint = Parser.Incremental.expr_file Lexing.dummy_pos in

  (* Drive the parser through all states *)
  let rec drive checkpoint = ... in
  drive initial_checkpoint
```

**Benefits of this approach:**
- Full control over parsing process
- Access to parser state at each step
- Better error recovery possibilities
- Enables advanced IDE features
- Transparent to existing code

## Implementation Details

The incremental parser is implemented in `src/sgen_parsing.ml`:

- Main `parse_with_error` function uses Menhir's incremental API
- Handles all parsing for the entire system
- **Error handling leverages parser state**: Uses `Parser.MenhirInterpreter.positions env` to get accurate error positions instead of relying on global mutable state
- Transparent to users - drop-in replacement for the traditional parser

### Error Handling Benefits

The incremental parser improves error reporting by:
1. Using `Parser.MenhirInterpreter.positions env` to extract the exact position where parsing failed
2. Accessing the parser's internal state during `HandlingError` checkpoint
3. Providing more accurate error locations without relying on lexer globals

## Performance Considerations

- The incremental API has minimal overhead compared to the traditional parser
- For typical Stellogen files, the performance is virtually identical
- The `--table` backend used for incremental parsing is well-optimized
- Benefits (better error handling, state inspection) outweigh any minor overhead

## Further Reading

- [Menhir Manual](https://gallium.inria.fr/~fpottier/menhir/manual.html) - Official documentation
- [MenhirLib API](https://ocaml.org/p/menhirLib/latest/doc/MenhirLib/IncrementalEngine/module-type-INCREMENTAL_ENGINE/index.html) - API reference
- `src/parser.mly` - Parser grammar definition
- `src/sgen_parsing.ml` - Incremental parser implementation

## Testing

All Stellogen tests now use the incremental parser automatically:

```bash
# Run all tests
dune test

# Run examples (all use incremental parser)
dune exec sgen run -- examples/nat.sg

# Or in utop:
#require "stellogen";;
open Stellogen;;
let lexbuf = Sedlexing.Utf8.from_string "(:= x 42)" in
Sgen_parsing.parse_with_error "<test>" lexbuf;;
```
