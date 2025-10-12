# Lexing and Parsing in Stellogen: A Self-Hosting Analysis

> **Disclaimer**: This document was written with the assistance of Claude Code and represents exploratory research and analysis. The content may contain inaccuracies or misinterpretations and should not be taken as definitive statements about the Stellogen language implementation.

## Abstract

This report analyzes the feasibility and implications of implementing lexers and parsers directly in Stellogen, without relying on external libraries like sedlex and menhir. Given Stellogen's elegant representation of finite automata (FSM) and pushdown automata (PDA) through constellations, this exploration addresses whether the language could bootstrap its own syntactic analysis tools and what theoretical and practical insights emerge from such an approach.

## 1. Introduction

### 1.1 Motivation

Stellogen currently uses:
- **sedlex** for lexical analysis (tokenization)
- **menhir** for syntactic analysis (parsing)

Both are mature, battle-tested OCaml libraries that generate efficient code. However, Stellogen's core philosophy raises an intriguing question: if the language can elegantly express automata (as demonstrated in `examples/automata.sg` and `examples/npda.sg`), could it express its own lexer and parser?

This question touches on several deep themes:
1. **Self-hosting**: Languages that can implement their own compilers
2. **Meta-circularity**: Using a language to define itself
3. **Bootstrapping**: The technical and philosophical challenges of self-definition
4. **Unification as computation**: Pushing term unification to its limits

### 1.2 Current Implementation Overview

The Stellogen toolchain's front-end consists of:

**Lexer** (`src/lexer.ml`):
- Uses sedlex's regexp-based pattern matching
- Produces tokens: `VAR`, `SYM`, `STRING`, `LPAR`, `RPAR`, etc.
- Handles delimiter matching, string literals, comments
- Tracks position information for error reporting

**Parser** (`src/parser.mly`):
- Uses menhir's LR parser generator
- Defines grammar in declarative form
- Supports incremental parsing (see `docs/incremental_parsing.md`)
- Provides error recovery and accurate position tracking

## 2. Theoretical Foundation

### 2.1 Automata Theory Recap

**Finite State Machines (FSM)**:
- Accept regular languages
- No memory beyond current state
- Perfect for lexical analysis (token recognition)
- Regexp matching is FSM computation

**Pushdown Automata (PDA)**:
- Accept context-free languages
- Have a stack for memory
- Natural model for parsing nested structures
- Equivalent to context-free grammars

### 2.2 Stellogen's Automata Representation

Stellogen represents automata with remarkable elegance through **constellations** - sets of interactive rays that unify through pattern matching.

#### Example: Finite State Automaton (from `examples/automata.sg`)

```stellogen
(:= (initial Q) [(-i W) (+a W Q)])
(:= (accept Q) [(-a [] Q) accept])
(:= (if read C1 on Q1 then Q2) [(-a [C1|W] Q1) (+a W Q2)])

' Automaton accepting words ending with 00
(:= a1 {
  #(initial q0)
  #(accept q2)
  #(if read 0 on q0 then q0)
  #(if read 0 on q0 then q1)
  #(if read 1 on q0 then q0)
  #(if read 0 on q1 then q2)})
```

**Key observations**:
1. States are terms: `q0`, `q1`, `q2`
2. Transitions are rays: patterns that unify when conditions match
3. Input is consumed via list pattern matching: `[C1|W]`
4. Non-determinism is natural: multiple rays can match

#### Example: Pushdown Automaton (from `examples/npda.sg`)

```stellogen
(:= (initial Q) [(-i W) (+a W [] Q)])
(:= (accept Q) [(-a [] [] Q) accept])
(:= (if read C1 on Q1 then Q2 and push C2)
    [(-a [C1|W] S Q1) (+a W [C2|S] Q2)])
(:= (if read C1 with C2 on Q1 then Q2)
    [(-a [C1|W] [C2|S] Q1) (+a W S Q2)])

' Palindrome recognizer
(:= a1 {
  #(initial q0)
  #(accept q0)
  #(if read 0 on q0 then q0 and push 0)
  #(if read 1 on q0 then q0 and push 1)
  #(if on q0 then q1)  ' epsilon transition
  #(if read 0 with 0 on q1 then q1)
  #(if read 1 with 1 on q1 then q1)})
```

**Key observations**:
1. Stack is represented as a list: `[C2|S]`
2. Push: cons onto stack list
3. Pop: pattern match on stack head
4. Epsilon transitions: rays without input consumption

### 2.3 From Automata to Lexing/Parsing

**Lexing**: FSM that recognizes token patterns
- Input: character stream
- Output: token stream
- Each token class = one FSM (or one large combined FSM)

**Parsing**: PDA that recognizes grammatical structure
- Input: token stream
- Output: parse tree (or AST)
- Grammar rules → PDA transitions
- Stack tracks parsing context

## 3. Lexing in Stellogen

### 3.1 Conceptual Design

A Stellogen lexer would be a **constellation of FSMs**, one per token type:

```stellogen
' Token type: identifier (letter followed by alphanumerics)
(:= lex-identifier {
  [(-lex [letter|Cs] []) (+lex Cs [(token identifier [letter])])]
  [(-lex [letter|Cs] [(token identifier Acc)])
   (+lex Cs [(token identifier [letter|Acc])])]
  [(-lex [alnum|Cs] [(token identifier Acc)])
   (+lex Cs [(token identifier [alnum|Acc])])]
  [(-lex Cs [(token identifier Acc)])
   (emit (token identifier (reverse Acc))) (+lex Cs [])]})

' Token type: number
(:= lex-number {
  [(-lex [digit|Cs] []) (+lex Cs [(token number [digit])])]
  [(-lex [digit|Cs] [(token number Acc)])
   (+lex Cs [(token number [digit|Acc])])]
  [(-lex Cs [(token number Acc)])
   (emit (token number (reverse Acc))) (+lex Cs [])]})

' Main lexer: combines all token recognizers
(:= lexer {
  #lex-identifier
  #lex-number
  #lex-whitespace
  #lex-operators
  ...
})
```

### 3.2 Character Handling

**Challenge**: Stellogen needs robust character/string operations.

Current approach in `src/lexer.ml`:
```ocaml
match%sedlex lexbuf with
| ( Compl (Chars "'\" \t\n\r()<>[]{}|@#"),
    Star (Compl (Chars " \t\n\r()<>[]{}|")) ) -> ...
```

Stellogen equivalent needs:
- Character classification predicates: `(is-letter C)`, `(is-digit C)`, etc.
- Character comparison: built-in or defined
- String-to-list conversion for input processing

**Possible solution**: Define character classes as constellations:

```stellogen
(spec letter {
  [(-is a) ok] [(-is b) ok] ... [(-is z) ok]
  [(-is A) ok] [(-is B) ok] ... [(-is Z) ok]})

(spec digit {
  [(-is 0) ok] [(-is 1) ok] ... [(-is 9) ok]})
```

### 3.3 Advantages of Stellogen Lexers

1. **Declarative token definitions**: Grammar-like syntax for token patterns
2. **No code generation**: Direct execution via interaction
3. **Extensibility**: Add token types by adding rays
4. **Meta-circular evaluation**: Lexer is data in the language
5. **Interactive debugging**: Can inspect lexer state during tokenization
6. **Unification power**: Complex patterns naturally expressed

### 3.4 Challenges

1. **Performance**: Unification overhead vs. compiled regex
   - sedlex generates efficient OCaml code
   - Stellogen interpreter may be slower by orders of magnitude
   - Could be mitigated by JIT compilation or specialized optimizations

2. **Position tracking**: Current lexer maintains detailed position info
   - Line numbers, column numbers, byte offsets
   - Crucial for error messages
   - Would need threading through constellation interactions

3. **Lookahead**: Some tokens require lookahead
   - e.g., `--` could be decrement or start of comment
   - FSM handles this naturally, but encoding may be verbose

4. **String literals**: Handling escape sequences, Unicode
   - Current implementation uses recursive state machine
   - Would need careful ray design

5. **Error recovery**: Current lexer has sophisticated error handling
   - Delimiter matching (parentheses, brackets, etc.)
   - Helpful error messages
   - Recovery strategies

6. **Bootstrapping paradox**: Need lexer to parse lexer definition
   - Chicken-and-egg problem
   - Solutions: minimal OCaml lexer, or meta-language approach

### 3.5 Example: Simplified Stellogen Lexer Sketch

```stellogen
' Input: string converted to character list
' Output: token list

' Helper: skip whitespace
(:= skip-ws {
  [(-lex [] Toks) (emit (reverse Toks))]
  [(-lex [space|Cs] Toks) (+lex Cs Toks)]
  [(-lex [tab|Cs] Toks) (+lex Cs Toks)]
  [(-lex [newline|Cs] Toks) (+lex Cs Toks)]
  [(-lex Cs Toks) (+try-token Cs Toks)]})

' Try to match a token
(:= try-token {
  ' Match opening paren
  [(-try-token [(|Cs] Toks) (+lex Cs [LPAR|Toks])]

  ' Match closing paren
  [(-try-token [)|Cs] Toks) (+lex Cs [RPAR|Toks])]

  ' Match variable (uppercase start)
  [(-try-token [C|Cs] Toks)
   (+uppercase C)
   (+lex-var Cs [C] Toks)]

  ' Match symbol (lowercase start)
  [(-try-token [C|Cs] Toks)
   (+lowercase C)
   (+lex-sym Cs [C] Toks)]

  ' Error case
  [(-try-token [C|_] _)
   (error (unexpected-char C))]})

' Continue matching variable
(:= lex-var {
  [(-lex-var [C|Cs] Acc Toks)
   (+alnum C)
   (+lex-var Cs [C|Acc] Toks)]
  [(-lex-var Cs Acc Toks)
   (+lex Cs [(VAR (reverse Acc))|Toks])]})

' Main entry point
(:= tokenize (+lex Input []))
```

## 4. Parsing in Stellogen

### 4.1 Conceptual Design

A Stellogen parser would be a **PDA encoded as a constellation**:

```stellogen
' Grammar:
'   E -> E + T | T
'   T -> T * F | F
'   F -> ( E ) | num

' Parsing constellation
(:= parser {
  ' Shift rules
  [(-parse [num|Ts] S) (+parse Ts [(num N)|S])]
  [(-parse [LPAR|Ts] S) (+parse Ts [LPAR|S])]

  ' Reduce: F -> num
  [(-parse Ts [num|S]) (+parse Ts [(F num)|S])]

  ' Reduce: F -> ( E )
  [(-parse Ts [(F E) LPAR|S]) (+parse Ts [(F (paren E))|S])]

  ' Reduce: T -> F
  [(-parse Ts [(F X)|S]) (+parse Ts [(T X)|S])]

  ' Reduce: T -> T * F
  [(-parse Ts [(F Y) MULT (T X)|S])
   (+parse Ts [(T (mul X Y))|S])]

  ' Reduce: E -> T
  [(-parse Ts [(T X)|S]) (+parse Ts [(E X)|S])]

  ' Reduce: E -> E + T
  [(-parse Ts [(T Y) PLUS (E X)|S])
   (+parse Ts [(E (add X Y))|S])]

  ' Accept
  [(-parse [] [(E X)]) (accept X)]})
```

### 4.2 Shift-Reduce Parsing

Stellogen naturally expresses shift-reduce parsing:
- **Shift**: Add token to stack (simple pattern match)
- **Reduce**: Pattern match on stack top, replace with non-terminal
- **Stack**: Represented as Stellogen list
- **Conflict resolution**: Ray ordering or explicit predicates

### 4.3 Advantages of Stellogen Parsers

1. **Direct grammar encoding**: Production rules → rays
2. **No external generator**: Self-contained in language
3. **Transparency**: Parser is inspectable program, not generated code
4. **Custom actions**: Semantic actions are just Stellogen expressions
5. **Incremental evaluation**: Natural support for partial parsing
6. **Error recovery**: Full control over error handling strategies
7. **Grammar experimentation**: No compile step for grammar changes

### 4.4 Challenges

1. **Efficiency**: Generated parsers are highly optimized
   - menhir produces table-driven LR parsers
   - Constant-time shift/reduce decisions
   - Stellogen interpretation likely much slower

2. **Grammar analysis**: No automatic conflict detection
   - menhir warns about shift/reduce, reduce/reduce conflicts
   - Stellogen user must manually ensure determinism
   - Could implement analysis tools in Stellogen itself (meta!)

3. **Ambiguity**: Handling ambiguous grammars
   - menhir has precedence/associativity declarations
   - Stellogen would need explicit strategies

4. **Large grammars**: Stellogen's grammar is non-trivial
   - Many production rules → many rays
   - Readability and maintainability concerns
   - Performance with hundreds of rays?

5. **Error messages**: Position tracking through parse stack
   - Current parser uses menhir's position tracking
   - Would need explicit position threading

6. **AST construction**: Building structured output
   - Current parser produces `Expr.Raw.t`
   - Need systematic way to build AST during reduction

### 4.5 Example: Stellogen Parser Sketch

```stellogen
' Simple expression parser with operator precedence

' Helper: precedence comparison
(:= (prec Op1 > Op2) ...)

' Main parsing constellation
(:= parse {
  ' Initialize
  [(-parse Tokens) (+shift Tokens [])]

  ' Shift token onto stack
  [(-shift [T|Ts] S) (+reduce [T|Ts] [T|S])]

  ' Reduce: number -> expr
  [(-reduce Ts [(num N)|S])
   (+reduce Ts [(expr (num-lit N))|S])]

  ' Reduce: ( expr ) -> expr
  [(-reduce Ts [(expr E) rparen lparen|S])
   (+reduce Ts [(expr (paren E))|S])]

  ' Reduce: expr op expr (with precedence)
  [(-reduce Ts [(expr E2) (op O) (expr E1)|S])
   (+should-reduce O Ts)  ' check precedence/associativity
   (+reduce Ts [(expr (binop O E1 E2))|S])]

  ' Continue shifting when no reductions apply
  [(-reduce [T|Ts] S) (+shift Ts [T|S])]

  ' Accept final expression
  [(-reduce [] [(expr E)]) (accept E)]

  ' Error cases
  [(-shift [] S) (error (unexpected-eof S))]
  [(-reduce Ts S) (error (parse-error Ts S))]})
```

## 5. Comparison with Current Implementation

### 5.1 Feature Comparison Table

| Feature | Current (sedlex/menhir) | Stellogen |
|---------|-------------------------|-----------|
| **Performance** | Excellent (compiled) | Likely slower (interpreted) |
| **Error reporting** | Excellent (position tracking) | Requires careful design |
| **Tooling** | Mature libraries | None yet |
| **Self-hosting** | No (external tools) | Yes (pure Stellogen) |
| **Debugging** | Standard OCaml tools | Interactive inspection |
| **Extensibility** | Modify files, recompile | Add rays, no recompilation |
| **Learning curve** | Need to learn menhir/sedlex | Just learn Stellogen |
| **Meta-programming** | Limited | Natural (data = code) |
| **Incremental parsing** | Supported (menhir) | Natural fit |
| **Grammar analysis** | Automatic (conflict detection) | Manual |

### 5.2 Lines of Code Estimate

**Current implementation**:
- `lexer.ml`: ~150 lines
- `parser.mly`: ~63 lines
- Total: ~213 lines (excluding generated code)

**Estimated Stellogen implementation**:
- Lexer: ~300-500 lines (more verbose pattern matching)
- Parser: ~400-600 lines (explicit stack manipulation)
- Total: ~700-1100 lines

**Why larger?**
- No regexp sugar: character-by-character processing
- Explicit state management: no hidden automaton
- Position tracking: manual threading
- Error handling: explicit recovery strategies

### 5.3 Performance Analysis

**Lexing**:
- sedlex: uses compiled OCaml with optimized state machines
- Stellogen: interpreted term unification
- **Estimated slowdown**: 10-100x

**Parsing**:
- menhir: table-driven LR(1), O(n) for grammar size
- Stellogen: pattern matching over rays
- **Estimated slowdown**: 10-100x (depending on implementation)

**Mitigation strategies**:
1. Optimize Stellogen interpreter for common patterns
2. Compile frequently-used constellations to OCaml
3. Use hybrid approach: bootstrapping only

## 6. Advantages and Opportunities

### 6.1 Theoretical Insights

1. **Unification as universal computation**: Demonstrates that term unification can express complex algorithms (lexing, parsing) traditionally done with specialized tools

2. **Automata naturalism**: FSM and PDA have *natural* representations in Stellogen, not as encodings but as first-class constructs

3. **Meta-circular evaluation**: Language can describe its own syntax, enabling powerful meta-programming

4. **Homoiconicity**: Code and data are uniformly represented as terms

### 6.2 Practical Benefits

1. **Educational value**:
   - Learn lexing/parsing by implementing them
   - Understand automata theory through direct encoding
   - No black-box tools

2. **Experimentation**:
   - Rapid prototyping of syntax changes
   - No recompilation cycle
   - Grammar as live data structure

3. **Extensibility**:
   - User-defined syntax extensions
   - Macros that modify parsing behavior
   - Dynamic grammar composition

4. **Portability**:
   - Self-contained: no external dependencies
   - Pure Stellogen, runs anywhere Stellogen runs

5. **Integration**:
   - Parser errors can be caught and handled in Stellogen
   - Custom error recovery strategies
   - Domain-specific language embedding

### 6.3 Research Directions

1. **Parsing Expression Grammars (PEG) in Stellogen**: PEGs are more modern than CFGs and handle left-recursion naturally

2. **GLR parsing**: Generalized LR handles ambiguous grammars; natural fit for non-deterministic constellations

3. **Scannerless parsing**: Combine lexing and parsing into single phase

4. **Error correction**: Not just recovery, but automatic repair using unification

5. **Syntax-directed translation**: Semantic actions during parsing

6. **Grammar inference**: Learn grammar from examples using unification

## 7. Challenges and Limitations

### 7.1 Bootstrap Problem

**Chicken-and-egg**: To write Stellogen lexer/parser in Stellogen, we need:
1. A working Stellogen system (to run the code)
2. Which requires a lexer/parser (to read the code)

**Solutions**:

1. **Gradual approach**: Keep OCaml implementation, add Stellogen version alongside
   - Use OCaml lexer/parser initially
   - Test Stellogen version in parallel
   - Switch when confident

2. **Minimal core**: Write tiny lexer/parser in OCaml that can bootstrap
   - Just enough to read constellation definitions
   - Stellogen takes over from there

3. **Meta-language**: Define syntax in declarative metalanguage
   - Stellogen interpreter reads metalanguage
   - Generates initial lexer/parser
   - Then self-hosts

### 7.2 Performance Concerns

**Real-world impact**:
- Small programs (<1000 lines): slowdown probably acceptable
- Large programs (>10000 lines): could become bottleneck
- Interactive use (REPL, IDE): latency-sensitive

**Mitigation**:
- Compile hot paths to native code
- Cache tokenization/parsing results
- Incremental parsing (only reparse changed regions)

### 7.3 Engineering Effort

**Development time**: Estimated effort to implement production-quality Stellogen lexer/parser:
- Design: 1-2 weeks
- Implementation: 4-8 weeks
- Testing: 2-4 weeks
- Documentation: 1-2 weeks
- **Total**: 2-4 months

**Comparison**: Current sedlex/menhir approach took much less time because libraries do the heavy lifting.

**Is it worth it?** Depends on goals:
- **Research/education**: Absolutely
- **Production use**: Probably not (yet)

### 7.4 Maintenance Burden

**Current approach**:
- sedlex and menhir are maintained by experts
- Bug fixes and improvements come for free
- Well-documented and tested

**Stellogen approach**:
- All maintenance falls on Stellogen developers
- Need expertise in both lexing/parsing and Stellogen
- Potential for bugs in subtle areas (Unicode, corner cases)

## 8. Hybrid Approaches

### 8.1 Dual Implementation

Maintain both:
- **Production**: OCaml (sedlex/menhir) for speed and reliability
- **Reference**: Stellogen for correctness and experimentation

Benefits:
- Fast compilation in production
- Formal specification in Stellogen
- Cross-validation between implementations
- Teaching tool

### 8.2 Compiled Constellations

Compile Stellogen constellations to efficient OCaml:
```
stellogen lexer definition → OCaml code generator → fast lexer
```

Benefits:
- Write in Stellogen (declarative, clear)
- Run as OCaml (fast, reliable)
- Best of both worlds

### 8.3 Staged Meta-Programming

Use Stellogen as a macro language over OCaml tools:
```stellogen
' High-level token specification
(deftoken IDENTIFIER
  (pattern (letter (star alnum)))
  (action (fun s -> Token.Ident s)))
```

Expands to sedlex patterns at compile time.

## 9. Implementation Roadmap

If Stellogen were to self-host its lexer/parser, here's a possible path:

### Phase 1: Proof of Concept (2-4 weeks)
- Implement simple expression lexer in Stellogen
- Implement simple expression parser in Stellogen
- Validate against test suite
- Benchmark performance

### Phase 2: Character Support (2-3 weeks)
- Add character type and operations
- Implement character classification
- Unicode support (or ASCII-only initially)
- String-to-character-list conversion

### Phase 3: Full Lexer (4-6 weeks)
- Implement all Stellogen token types
- Position tracking
- Error recovery
- String literals with escape sequences
- Comments (single-line and multi-line)

### Phase 4: Full Parser (6-8 weeks)
- Implement complete Stellogen grammar
- AST construction
- Error recovery strategies
- Position propagation
- Test against existing test suite

### Phase 5: Integration (3-4 weeks)
- Bootstrap mechanism
- Performance profiling and optimization
- Documentation
- Examples and tutorials

### Phase 6: Optimization (4-8 weeks)
- JIT compilation of hot paths
- Incremental parsing
- Parallel parsing (if applicable)
- Memory optimization

**Total estimated time**: 5-8 months for full implementation

## 10. Conclusion

### 10.1 Summary

Implementing lexers and parsers in Stellogen is:
- **Theoretically elegant**: Natural expression of automata
- **Educationally valuable**: Deep insights into language processing
- **Practically challenging**: Performance and engineering costs
- **Philosophically aligned**: Self-hosting fits Stellogen's meta-circular nature

### 10.2 Recommendations

**For research and exploration**:
- ✅ **Do it**: Valuable exercise that pushes Stellogen's boundaries
- ✅ Demonstrates unification's expressive power
- ✅ Provides reference implementation
- ✅ Enables meta-programming experiments

**For production use**:
- ⚠️ **Proceed carefully**: Consider hybrid approaches
- ⚠️ Keep OCaml implementation for performance
- ⚠️ Use Stellogen version for specification
- ⚠️ Compile Stellogen to OCaml for best of both worlds

**For the Stellogen project**:
1. Implement proof-of-concept lexer/parser
2. Document as teaching tool
3. Use for grammar specification
4. Consider compilation to OCaml eventually
5. Maintain OCaml implementation for production

### 10.3 Broader Implications

This analysis reveals that Stellogen occupies a unique position:

1. **Theoretical foundation**: Strong enough to express complex algorithms (FSM, PDA, lexing, parsing)

2. **Practical applicability**: Currently limited by performance, but not fundamentally so

3. **Meta-circular potential**: Could be fully self-hosting with engineering effort

4. **Educational mission**: Excellent vehicle for teaching formal language theory

The question "Can Stellogen implement its own lexer/parser?" has the answer: **Yes, and it would be beautiful** - but also **slow and labor-intensive**. The real value lies not in replacing the current implementation, but in demonstrating Stellogen's computational universality and providing a formal, executable specification of the language's syntax.

### 10.4 Final Thought

The most compelling argument for self-hosting Stellogen's lexer and parser is not practical but **philosophical**: a language built on the principle that "computation and meaning are the same raw material" should be able to define its own syntax within that framework. Doing so proves that term unification is not just an interesting theoretical curiosity, but a genuine foundation for all of language processing.

In Girard's terms, Stellogen would then be exhibiting true **transcendental syntax**: the syntax speaks about itself, through itself, as itself.

## References

1. Stellogen examples: `examples/automata.sg`, `examples/npda.sg`
2. Current implementation: `src/lexer.ml`, `src/parser.mly`
3. Incremental parsing: `docs/incremental_parsing.md`
4. Stellogen basics: `docs/basics.md`
5. README: `/README.md`
6. Hopcroft & Ullman, "Introduction to Automata Theory, Languages, and Computation"
7. Aho et al., "Compilers: Principles, Techniques, and Tools" (Dragon Book)
8. Menhir documentation: https://gallium.inria.fr/~fpottier/menhir/
9. Girard, J.-Y., "The Blind Spot: Lectures on Logic"

---

*Report prepared: 2025-10-12*
*Stellogen version: claude-research branch*
*Author: Claude Code (with research from Stellogen codebase)*
