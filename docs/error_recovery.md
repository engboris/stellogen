# Error Recovery in Stellogen

Stellogen's parser uses Menhir's incremental API to provide comprehensive error recovery, allowing it to collect and report multiple parse errors in a single pass.

## Overview

Instead of stopping at the first syntax error, the Stellogen parser:

1. **Collects multiple errors** - Up to 20 errors per file (configurable)
2. **Provides context and hints** - Each error includes helpful suggestions
3. **Attempts recovery** - Tries to continue parsing after errors
4. **Reports all errors at once** - Shows all problems in one pass

## Error Information

Each parse error includes:

- **Position**: Exact line and column from parser state
- **Message**: Clear description of what went wrong
- **Hint**: Suggested fix (when applicable)
- **Source context**: Shows the offending line with a caret pointing to the error

## Error Recovery Strategies

The parser uses different recovery strategies based on context:

### 1. Extra Closing Delimiter

```stellogen
(:= x 42))
        ^
```

**Strategy**: Skip the extra delimiter and continue parsing

**Recovery**: Immediately continues from next token

### 2. Unclosed Delimiter at EOF

```stellogen
(:= x (add 1 2
              ^
```

**Strategy**: Abort (cannot recover past EOF)

**Recovery**: Reports error and stops (cannot produce meaningful output)

### 3. Unexpected Token

```stellogen
(:= x @@)
      ^
```

**Strategy**: Skip until next opening parenthesis (start of new expression)

**Recovery**: Attempts to find next top-level construct

## Error Messages

### Standard Format

```
error: <message>
  --> <filename>:<line>:<column>

   <line number> | <source line>
                 | <caret pointing to error>

  hint: <suggestion>
```

### Example

```
error: no opening delimiter for ')'
  --> test.sg:2:12

    2 | (:= bad1 x))
      |            ^

  hint: remove this delimiter or add a matching opening delimiter
```

## Limitations

### Cascading Errors

When the parser recovers from an error, it may generate additional "cascade" errors as it tries to make sense of the remaining input:

```stellogen
(:= x ))
' Primary error: extra )
' May also report: unexpected tokens afterward
```

This is a known challenge in error recovery. The parser reports all detected issues, some of which may be consequences of earlier errors.

### EOF Recovery

The parser cannot recover past end-of-file. If a delimiter is unclosed at EOF, recovery aborts:

```stellogen
(:= x (incomplete
```

**Result**: Single error about unclosed delimiter, parsing stops

## Implementation Details

### Error Collection

Located in `src/parse_error.ml`:

```ocaml
type parse_error = {
  position: Lexing.position;
  end_position: Lexing.position option;
  message: string;
  hint: string option;
  severity: [`Error | `Warning];
}
```

### Recovery Actions

```ocaml
type recovery_action =
  | Skip of int              (* Skip n tokens *)
  | SkipUntil of token       (* Skip until target token *)
  | SkipToDelimiter          (* Skip to matching nesting level *)
  | Abort                    (* Cannot recover *)
```

### Parser Integration

The incremental parser (`src/sgen_parsing.ml`) uses these recovery actions in the `HandlingError` checkpoint:

1. Extract error info from parser `env`
2. Add error to collector
3. Determine recovery strategy
4. Execute recovery (skip tokens, restart parser)
5. Continue until EOF or max errors reached

## Benefits

✅ **Better developer experience** - See all errors at once instead of fix-compile-fix cycles

✅ **Maintainability** - Leverage parser state for accurate error positions

✅ **Helpful hints** - Context-aware suggestions for common mistakes

✅ **Incremental parsing foundation** - Ready for REPL and IDE features

## Configuration

Maximum errors before giving up (default: 20):

```ocaml
let error_collector = Parse_error.create_collector ~max_errors:20 ()
```

## Testing Error Recovery

```bash
# Create a file with multiple errors
cat > test_errors.sg << 'EOF'
(:= good1 42)
(:= bad1 x))
(:= good2 100)
EOF

# See all errors at once
dune exec sgen run -- test_errors.sg
```

## Future Enhancements

Potential improvements:

1. **Smarter recovery heuristics** - Reduce cascading errors
2. **Error message customization** - Using Menhir's `.messages` files
3. **Warning suppression** - Filter known cascade errors
4. **Recovery suggestions** - Propose concrete fixes
5. **IDE integration** - Real-time error checking

## See Also

- `src/parse_error.ml` - Error data structures and recovery logic
- `src/sgen_parsing.ml` - Parser with error recovery integration
- `docs/incremental_parsing.md` - Incremental parser documentation
