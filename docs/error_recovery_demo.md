# Error Recovery Demonstration

This document demonstrates Stellogen's error recovery capabilities.

## Example 1: Single Error with Hint

**Input** (`single_error.sg`):
```stellogen
(:= x 42))
```

**Output**:
```
error: no opening delimiter for ')'
  --> single_error.sg:1:9

    1 | (:= x 42))
      |          ^

  hint: remove this delimiter or add a matching opening delimiter

found 1 error(s)
```

## Example 2: Unclosed Delimiter

**Input** (`unclosed.sg`):
```stellogen
(:= x (add 1 2
```

**Output**:
```
error: unclosed delimiter '('
  --> unclosed.sg:2:1

  hint: add the missing closing delimiter

found 1 error(s)
```

## Example 3: Multiple Independent Errors

**Input** (`multiple_errors.sg`):
```stellogen
(:= good1 42)
(:= bad1 x))
(:= good2 100)
```

**Output**:
```
error: no opening delimiter for ')'
  --> multiple_errors.sg:2:12

    2 | (:= bad1 x))
      |            ^

  hint: remove this delimiter or add a matching opening delimiter

error: unexpected symbol ':='
  --> multiple_errors.sg:3:2

    3 | (:= good2 100)
      |  ^

  hint: check if this symbol is in the right place

found 2 error(s)
```

*Note: The second error is a cascade error caused by the parser's recovery attempt*

## Example 4: Valid Code Still Parses

**Input** (`valid.sg`):
```stellogen
(:= add {
  [(+add 0 Y Y)]
  [(-add X Y Z) (+add (s X) Y (s Z))]})

(:= query [(-add <s s 0> <s s 0> R) R])
```

**Output**:
```
(Successfully parses with no errors)
```

## Benefits Demonstrated

1. **Multiple Errors at Once** - No need for fix-compile-fix cycles
2. **Helpful Hints** - Context-aware suggestions
3. **Accurate Positions** - Exact line/column from parser state
4. **Source Context** - Shows problematic code with visual pointer
5. **Error Count** - Summary at the end

## Known Limitations

- **Cascading Errors**: Recovery may generate follow-up errors
- **EOF Limits**: Cannot recover past end-of-file with unclosed delimiters
- **Context Dependent**: Some errors are harder to recover from than others

## Implementation

See:
- `docs/error_recovery.md` - Full documentation
- `src/parse_error.ml` - Error recovery logic
- `src/sgen_parsing.ml` - Parser integration
