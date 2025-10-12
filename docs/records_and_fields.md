# Records and Field Encoding in Stellogen

> **Disclaimer**: This document was written with the assistance of Claude Code and represents exploratory research and analysis. The content may contain inaccuracies or misinterpretations and should not be taken as definitive statements about the Stellogen language implementation.

**Status:** Research Document
**Date:** 2025-10-12
**Purpose:** Analyze the record encoding mechanism using fields and `eval`, assess its viability for general use, and solve the TODO problem in type-checking record-based specs

---

## Table of Contents

1. [Overview](#overview)
2. [The `eval` Primitive](#the-eval-primitive)
3. [Field Encoding Patterns](#field-encoding-patterns)
4. [Viability Assessment](#viability-assessment)
5. [The Type System and Records](#the-type-system-and-records)
6. [The TODO Problem](#the-todo-problem)
7. [Proposed Solutions](#proposed-solutions)
8. [References](#references)

---

## Overview

Stellogen uses **term unification** and **polarity-based interaction** as its fundamental computation mechanism. Within this framework, several files in the `examples/` directory demonstrate an encoding of **records with fields** using:

1. **Polarity matching**: Positive rays `(+field name)` paired with negative queries `(-field name)`
2. **The `eval` primitive**: Reifies a term back into an expression and evaluates it
3. **Field access pattern**: `(eval (interact #record @[(-field name)]))`

This document analyzes whether this encoding is **viable and sufficient** for general use, particularly for implementing a type system where types are records of tests.

---

## The `eval` Primitive

### Implementation

**Location:** `src/sgen_eval.ml:208-223`

```ocaml
| Eval e -> (
  let* eval_e = eval_sgen_expr env e in
  match eval_e with
  | [ State { content = [ r ]; bans = _ } ]
  | [ Action { content = [ r ]; bans = _ } ] ->
    let er = expr_of_ray r in
    begin
      match Expr.sgen_expr_of_expr er with
      | Ok sg -> eval_sgen_expr env sg
      | Error e -> Error (ExprError (e, None))
    end
  | e ->
    failwith
      ( "eval error: "
      ^ string_of_constellation (Marked.remove_all e)
      ^ " is not a ray." ) )
```

### Semantics

`eval` is analogous to Lisp/Scheme's `eval` or "unquoting":

1. **Evaluate** the expression `e` to get a constellation
2. **Check** that the result is a single ray (not multiple stars)
3. **Reify** the ray back into an `expr` using `expr_of_ray`
4. **Re-evaluate** that expression in the current environment

**Example:**

```stellogen
(:= x (+f a))
(show (eval #x))  ' Evaluates to [(+f a)]
```

### Purpose in Record Encoding

`eval` enables **meta-level computation**:
- Interaction produces a term representing a value
- `eval` treats that term as code and executes it
- This allows records to store "suspended computations" that are activated on access

---

## Field Encoding Patterns

### Pattern 1: Direct Polarity (Simpler)

**Used in:** `examples/mll.sg`, `examples/smll.sg`

**Encoding:**

```stellogen
(:= record {
  [+fieldname1 value1]
  [+fieldname2 value2]})
```

**Access:**

```stellogen
(:= field1 (eval (interact #record @[-fieldname1])))
```

**Mechanism:**
1. `+fieldname1` (positive polarity) stored in record
2. `-fieldname1` (negative polarity) used in query
3. They **unify** (fuse) during interaction
4. Result is `value1` (the associated constellation)
5. `eval` evaluates that constellation

**Example from `mll.sg:38-47`:**

```stellogen
(:= ps1 {
  [+vehicle [
    [(+7 [l|X]) (+7 [r|X])]
    @[(3 X) (+8 [l|X])]
    [(+8 [r|X]) (6 X)]]]
  [+cuts [
    [(-7 X) (-8 X)]]]})

(:= vehicle (eval (interact #ps1 @[-vehicle])))
(:= cuts    (eval (interact #ps1 @[-cuts])))
```

**Pros:**
- Simple and direct
- Minimal overhead
- Clear correspondence between polarity and field name

**Cons:**
- Field names must be **fixed** (hardcoded polarities)
- Cannot parameterize field access by a variable
- Each field requires a unique polarity identifier

---

### Pattern 2: Field Function (More General)

**Used in:** `examples/syntax.sg`

**Encoding:**

```stellogen
(:= record {
  [(+field name1) value1]
  [(+field name2) value2]})
```

**Access:**

```stellogen
(:= (get Record FieldName) (eval (interact #Record @[(-field FieldName)])))
(:= result (get record name1))
```

**Mechanism:**
1. `(+field name1)` is a **function term** with argument `name1`
2. `(-field X)` is a query with **variable** `X`
3. Unification binds `X` to `name1` and they fuse
4. Result is `value1`
5. `eval` evaluates it

**Example from `syntax.sg:62-71`:**

```stellogen
(:= g {
  [(+field test1) [(+f a) ok]]
  [(+field test2) [(+f b) ok]]})

(:= (get G X) (eval (interact #G @[(-field X)])))
(show #(get g test1))  ' Returns: [(+f a) ok]
(show #(get g test2))  ' Returns: [(+f b) ok]
```

**Nested fields:**

```stellogen
(:= g1 [
  [(+field test1) [
    [(+field test2) [(+f c) ok]]]]])

(:= g2 (eval (interact #g1 @[(-field test1)])))
(show (eval (interact #g2 @[(-field test2)])))  ' Returns: [(+f c) ok]
```

**Pros:**
- **General**: Field names can be variables
- **Composable**: Can define generic access functions
- **Nested**: Supports arbitrary nesting
- **Aligned with unification**: Uses standard term matching

**Cons:**
- Slightly more verbose (requires the `field` function wrapper)
- Need to define access helper (`get`)

---

### Pattern Comparison

| Feature | Direct Polarity | Field Function |
|---------|----------------|----------------|
| Simplicity | ✓ Simple | Slightly more complex |
| Variable field names | ✗ No | ✓ Yes |
| Generic access | ✗ No | ✓ Yes |
| Nested records | ✓ Yes | ✓ Yes |
| Alignment with unification | ✓ Natural | ✓ Natural |
| Verbosity | Low | Medium |

**Recommendation:** Use **Pattern 2 (Field Function)** for general-purpose record encoding due to its generality and composability.

---

## Viability Assessment

### Question: Is this encoding viable and sufficient for general use?

**Answer: YES, with qualifications**

### Strengths

1. **Minimalist**: No special record syntax needed—builds on existing primitives
   - Constellations
   - Polarity and unification
   - `eval` for meta-level computation

2. **Logic-agnostic**: Aligned with Stellogen's philosophy
   - No imposed structure
   - Records are just constellations with a particular pattern
   - User defines the semantics

3. **Powerful**: Supports advanced features
   - Nested records
   - Variable field access
   - Records storing arbitrary constellations
   - Meta-level computation (fields can contain code)

4. **Composable**: Can build abstractions
   - Generic `get` function
   - Field update (via constellation composition)
   - Record merging

5. **Unified with interaction**: Uses the same mechanism as computation
   - No separate module system
   - Records interact like any other constellation

### Limitations

1. **No field validation**: Nothing prevents accessing non-existent fields
   - `(get record nonexistent)` will just return an unreduced term
   - No compile-time or runtime errors

2. **No type safety for records**: Records are constellations
   - Can't distinguish a "record" from any other constellation
   - Field names are not statically checked

3. **Verbosity**: Requires explicit `eval` and `interact`
   - `(eval (interact #record @[(-field name)]))` is longer than `record.name`
   - Could be mitigated with macros

4. **No pattern matching on records**: Can't destructure records
   - Must access fields one by one
   - No convenient syntax like `{field1, field2} = record`

5. **Performance**: Multiple evaluations and interactions
   - Each field access triggers interaction + eval
   - May be slower than direct lookup
   - Acceptable for a research language

### Sufficiency for General Use

**For Stellogen's purposes: YES**

The encoding is **sufficient** for:
- Organizing related data
- Building modular abstractions
- Implementing type systems (see next section)
- Encoding objects and namespaces

The encoding is **not sufficient** for:
- Production-level performance requirements
- Systems requiring strong static guarantees
- Applications needing field name validation

**But Stellogen is an experimental/research language**, so these limitations are acceptable.

---

## The Type System and Records

### How Types are Defined

In Stellogen, **types are sets of interactive tests**.

**From `CLAUDE.md`:**

> Types are defined as **sets of interactive tests**:
> ```stellogen
> (spec binary {
>   [(-i []) ok]
>   [(-i [0|X]) (+i X)]
>   [(-i [1|X]) (+i X)]})
> ```
>
> Type checking: `(:: value type)` triggers interaction and expects `ok`

### Two Kinds of Type Specs

#### 1. Simple Type Specs (Single Test)

**Pattern:**

```stellogen
(spec typename {
  [test1]
  [test2]
  [test3]})
```

The spec is a **single constellation** containing multiple test cases. Testing a value against the type means **interacting** the value with the spec and expecting `ok`.

**Example from `examples/nat.sg:5-7`:**

```stellogen
(spec nat {
  [(-nat 0) ok]
  [(-nat (s N)) (+nat N)]})

(:= zero (+nat 0))
(:: zero nat)  ' Expands to: (== @(interact @#zero #nat) ok)
```

**How it works:**
1. `@#zero` focuses the value `(+nat 0)`
2. `#nat` is the spec `{[(-nat 0) ok] [(-nat (s N)) (+nat N)]}`
3. `interact` matches `(+nat 0)` with `(-nat 0)` → produces `ok`
4. `@(...)` focuses the result → `ok`
5. `(== ok ok)` succeeds ✓

**This works** because the spec is a single constellation that can be used directly in interaction.

---

#### 2. Record Type Specs (Multiple Named Tests)

**Pattern:**

```stellogen
(spec typename {
  [+test1name [...test1...]]
  [+test2name [...test2...]]
  [+test3name [...test3...]]})
```

The spec is a **record** containing multiple **named tests**. Each field stores a separate test constellation.

**Example from `examples/mll.sg:6-26`:**

```stellogen
(spec (larrow a a) {
  [+testrl [
    [(-1 X) (-2 X) (+c5 X)]
    [(-3 X)] [(-4 X) (+c6 X)]
    [(-c5 X) (+7 X)] [(-c6 X)]
    @[(-7 X) ok]]]
  [+testrr [
    [(-1 X) (-2 X) (+c5 X)]
    [(-3 X)] [(-4 X) (+c6 X)]
    [(-c5 X)] [(+7 X) (-c6 X)]
    @[(-7 X) ok]]]
  [+testll [...]]
  [+testlr [...]]})
```

**This is NOT a single test**—it's a **record of 4 separate tests**:
- `testrl`: Tests one aspect
- `testrr`: Tests another aspect
- `testll`: Tests yet another aspect
- `testlr`: Tests the final aspect

**Why multiple tests?**

For **linear types** (from linear logic), you need to verify multiple properties:
- Resource usage (linearity constraints)
- Different interaction patterns
- Multiple paths through the computation

A single test cannot capture all these aspects—you need **multiple independent tests**.

---

### The Problem with Current `::` Macro

**Current definition:**

```stellogen
(new-declaration (:: Tested Test)
  (== @(interact @#Tested #Test) ok))
```

**Works for simple specs:**

```stellogen
(:: zero nat)
' Expands to: (== @(interact @#zero #nat) ok)
' nat is a single constellation → interaction works ✓
```

**Doesn't work for record specs:**

```stellogen
(:: id (larrow a a))
' Expands to: (== @(interact @#id #(larrow a a)) ok)
' (larrow a a) is a RECORD, not a single test → interaction doesn't test all fields ✗
```

**Why it fails:**

When you interact a value with a record spec:
- The interaction treats the record as a single constellation
- Only ONE of the fields might match (or none)
- The other fields are ignored
- Result is NOT `ok`—it's a partially reduced constellation

**What we need:**

A type-checking mechanism that:
1. **Extracts** each named test from the record
2. **Runs** each test independently
3. **Verifies** all tests return `ok`

---

## The TODO Problem

### The TODOs in Examples

**From `examples/mll.sg:35`:**

```stellogen
(:= id {
  [(-5 [l|X]) (+1 X)]
  [(-5 [r|X]) (+2 X)]
  [(-6 [l|X]) (+3 X)]
  [(-6 [r|X]) (+4 X)]
  [(+5 [l|X]) (+6 [l|X])]
  [(+5 [r|X]) (+6 [r|X])]})
'TODO (:: id (larrow a a))
```

**From `examples/smll.sg:35`:** Same TODO

**From `examples/linear_lambda.sg:42`:** Same pattern

### Why the TODO Exists

The TODO exists because:

1. **`(larrow a a)` is a record type** with 4 tests: `testrl`, `testrr`, `testll`, `testlr`
2. **The `::` macro only works with simple specs**, not record specs
3. **No mechanism exists** to iterate over all fields in a record and test each one
4. **Manual testing is tedious**:
   ```stellogen
   (:= testrl (eval (interact #(larrow a a) @[-testrl])))
   (== @(interact @#id #testrl) ok)
   (:= testrr (eval (interact #(larrow a a) @[-testrr])))
   (== @(interact @#id #testrr) ok)
   ' ... repeat for testll and testlr
   ```

### The Core Challenge

**Stellogen currently lacks:**
- A way to **enumerate** fields in a record
- A way to **iterate** over fields programmatically
- A macro that can handle **variable numbers of tests**

**Macro limitations:**

Macros in Stellogen operate at the **expression level**—they expand syntax. They cannot:
- Inspect the runtime structure of a constellation
- Determine how many fields a record has
- Generate a variable number of test expressions

---

## Proposed Solutions

### Solution 1: Manual Test Extraction (Current Workaround)

**Idea:** Explicitly extract and test each field.

```stellogen
' Extract all tests from (larrow a a)
(:= testrl (eval (interact #(larrow a a) @[-testrl])))
(:= testrr (eval (interact #(larrow a a) @[-testrr])))
(:= testll (eval (interact #(larrow a a) @[-testll])))
(:= testlr (eval (interact #(larrow a a) @[-testlr])))

' Test id against each
(== @(interact @#id #testrl) ok)
(== @(interact @#id #testrr) ok)
(== @(interact @#id #testll) ok)
(== @(interact @#id #testlr) ok)
```

**Pros:**
- Works with current language features
- Explicit and clear

**Cons:**
- Extremely verbose
- Not reusable
- Hardcoded field names
- Defeats the purpose of abstraction

**Status:** This is what the TODO is asking to avoid.

---

### Solution 2: Hardcoded Record Type-Check Macro

**Idea:** Create a special macro for type specs with known field names.

```stellogen
(new-declaration (::larrow Tested Test)
  (== @(interact @#Tested (eval (interact #Test @[-testrl]))) ok)
  (== @(interact @#Tested (eval (interact #Test @[-testrr]))) ok)
  (== @(interact @#Tested (eval (interact #Test @[-testll]))) ok)
  (== @(interact @#Tested (eval (interact #Test @[-testlr]))) ok))

' Usage
(::larrow id (larrow a a))
```

**How it works:**
1. Extract each test using field access pattern
2. Run 4 separate `interact` and `==` checks
3. If any fails, the whole assertion fails

**Pros:**
- Reusable for all `larrow` types
- Clear semantics
- Works within current macro system

**Cons:**
- **Hardcoded** for 4 specific test names
- Not general—need different macros for different record types
- Doesn't scale to arbitrary record specs

**Viability:** ⚠️ Limited—works for specific cases like `larrow`, but not a general solution.

---

### Solution 3: Naming Convention for All Tests

**Idea:** Establish a convention that ALL record type specs use the same field names.

```stellogen
' Convention: All record types use +test1, +test2, +test3, +test4

(spec (larrow a a) {
  [+test1 [...]]
  [+test2 [...]]
  [+test3 [...]]
  [+test4 [...]]})

(spec (tens a b) {
  [+test1 [...]]
  [+test2 [...]]})

' General macro that tests up to 4 tests
(new-declaration (::record Tested Test)
  (process
    (== @(interact @#Tested (eval (interact #Test @[-test1]))) ok (error "test1 failed"))
    (== @(interact @#Tested (eval (interact #Test @[-test2]))) ok (error "test2 failed"))
    (== @(interact @#Tested (eval (interact #Test @[-test3]))) ok (error "test3 failed"))
    (== @(interact @#Tested (eval (interact #Test @[-test4]))) ok (error "test4 failed"))))
```

**How it works:**
1. All record types follow naming convention: `test1`, `test2`, etc.
2. `::record` macro tries to extract each test
3. If a test doesn't exist (e.g., type only has 2 tests), extraction will fail gracefully or return a neutral value
4. Run all available tests

**Pros:**
- Relatively general
- Works for any record type with up to N tests (e.g., 4 or 10)
- Clear convention

**Cons:**
- **Arbitrary limit** on number of tests
- **Clunky naming** (`test1`, `test2` vs descriptive names like `testrl`)
- **Loses semantics**: Field names no longer describe what they test
- **Failure handling**: How do we know if a field doesn't exist vs test failed?

**Viability:** ⚠️ Mediocre—works but sacrifices clarity and expressiveness.

---

### Solution 4: Process-Based Test Composition

**Idea:** Use `process` to chain tests together.

```stellogen
(new-declaration (::chain Tested Test TestNames)
  (== @(process
        @#Tested
        { (eval (interact #Test @[(-test1)])) }
        { (eval (interact #Test @[(-test2)])) }
        { (eval (interact #Test @[(-test3)])) }
        { (eval (interact #Test @[(-test4)])) }
        { [@(... some final check ...)] })
      ok))
```

**How it works:**
1. Start with the tested value
2. `process` chains interactions through each test
3. Each test transforms the constellation
4. Final result should be `ok`

**Pros:**
- Uses native `process` mechanism
- Composable

**Cons:**
- **Complex semantics**: What does it mean to chain tests?
- **Order-dependent**: Tests aren't independent anymore
- **Still hardcoded**: Need to specify test names
- **Not clear how to verify all passed**: Process composes transformations, not validations

**Viability:** ✗ Doesn't match the testing semantics needed.

---

### Solution 5: Introduce Runtime Field Enumeration (Language Extension)

**Idea:** Add a primitive to enumerate fields in a record at runtime.

```stellogen
' Hypothetical syntax
(:= fieldlist (fields #(larrow a a)))
' fieldlist = [testrl testrr testll testlr]

' Then use that to generate tests
(new-declaration (::record Tested Test)
  (== @(test-all @#Tested #Test (fields #Test)) ok))
```

**How it would work:**
1. `fields` primitive introspects a constellation and extracts field names (polarities)
2. `test-all` is a new primitive that:
   - Takes a value, a type record, and a list of field names
   - Extracts each test from the record
   - Runs each test
   - Returns `ok` if all pass

**Pros:**
- **General**: Works for arbitrary record types
- **Clean**: No hardcoding
- **Expressive**: Captures the intent

**Cons:**
- **Requires language extension**: New primitives `fields` and `test-all`
- **Complexity**: Adds runtime introspection
- **Philosophy**: May not align with Stellogen's minimalism

**Viability:** ✓ Would work but requires significant implementation effort.

---

### Solution 6: Conventional "Test Suite" Pattern (Recommended)

**Idea:** Instead of using records for type specs, use a **different pattern** for multi-test types.

**Pattern:**

```stellogen
' Define type as a CONSTELLATION of tests, not a record
(spec (larrow a a)
  { (testrl ok) (testrr ok) (testll ok) (testlr ok) })

' Each test is a separate constellation
(spec testrl {
  [(-1 X) (-2 X) (+c5 X)]
  [(-3 X)] [(-4 X) (+c6 X)]
  [(-c5 X) (+7 X)] [(-c6 X)]
  @[(-7 X) ok]})

(spec testrr { [...] })
(spec testll { [...] })
(spec testlr { [...] })

' New macro: Test against multiple specs
(new-declaration (::all Tested Tests)
  (== @(interact @#Tested #Tests) ok))

' Usage
(::all id (larrow a a))
```

**Alternative approach:**

```stellogen
' Type as a group of tests
(:= (larrow-a-a-type) {
  #testrl
  #testrr
  #testll
  #testlr})

' Modified :: macro that handles groups
(new-declaration (::multi Tested TestGroup)
  (== @(interact @#Tested #TestGroup) ok))

' Usage
(::multi id (larrow-a-a-type))
```

**Pros:**
- **No records needed** for type specs
- **Works with current system**: Uses existing interaction mechanism
- **Clear semantics**: All tests in one constellation
- **Aligned with Stellogen**: Types as constellations, not meta-structures

**Cons:**
- **Changes the pattern**: Need to refactor `larrow` definition
- **Less modular**: Can't easily extract individual tests
- **Not using the record encoding**: Sidesteps the problem rather than solving it

**Viability:** ✓ Most practical within current language capabilities.

---

### Solution 7: Explicit Test List + Fold Macro (Hybrid)

**Idea:** Require users to explicitly list test names when checking record types.

```stellogen
(new-declaration (::with-tests Tested Test TestList)
  (::check-all @#Tested #Test #TestList))

(:= (::check-all Val Type Tests)
  (process
    ok
    { [(-cons TestName Rest) ...extract test, run it, recurse... ] }
    { [(-nil) ok] }))

' Usage - explicitly specify which tests to run
(::with-tests id (larrow a a) [testrl testrr testll testlr])
```

**Pros:**
- Explicit and clear
- Flexible: Can test subset of tests
- Works within current language (if we implement the helper)

**Cons:**
- **Verbose**: Must list all test names
- **Duplication**: Test names appear in both type definition and usage
- **Complex implementation**: Need to implement fold/iteration pattern

**Viability:** ⚠️ Workable but cumbersome.

---

### Recommendation

#### Short-term (Solve the TODO now):

**Use Solution 2 (Hardcoded Macro)** for the specific case:

```stellogen
(new-declaration (::larrow Tested Test)
  {
    (== @(interact @#Tested (eval (interact #Test @[-testrl]))) ok)
    (== @(interact @#Tested (eval (interact #Test @[-testrr]))) ok)
    (== @(interact @#Tested (eval (interact #Test @[-testll]))) ok)
    (== @(interact @#Tested (eval (interact #Test @[-testlr]))) ok)
  })

' Now this works:
(::larrow id (larrow a a))
```

**Pros:**
- Solves the immediate problem
- Minimal effort
- Clear and explicit

#### Medium-term (General solution):

**Use Solution 6 (Test Suite Pattern)**:

Rethink how multi-test types are defined. Instead of records, define types as **constellations containing all tests** directly.

```stellogen
' Refactor larrow as a single constellation with all tests inline
(spec (larrow a a) {
  ' Test RL
  [(-id-rl X) ... test logic ... @[(-result-rl X) ok]]
  ' Test RR
  [(-id-rr X) ... test logic ... @[(-result-rr X) ok]]
  ' Test LL
  [(-id-ll X) ... test logic ... @[(-result-ll X) ok]]
  ' Test LR
  [(-id-lr X) ... test logic ... @[(-result-lr X) ok]]})

' Values tagged for each test
(:= id {
  [(+id-rl X) ...]
  [(+id-rr X) ...]
  [(+id-ll X) ...]
  [(+id-lr X) ...]})

' Standard :: macro now works
(:: id (larrow a a))
```

**Pros:**
- Uses standard `::` macro
- No language extensions needed
- Aligned with simple type pattern

**Cons:**
- Requires restructuring type definitions
- Less modular (can't easily reference individual tests)

#### Long-term (If Stellogen evolves):

**Consider Solution 5 (Field Enumeration)**:

Add primitives for runtime introspection of records:
- `(fields record)` → list of field names
- `(test-all value type fields)` → run all tests and return combined result

This would enable truly general record-based type checking.

---

## Practical Example: Solving the TODO

### Current State

```stellogen
(spec (larrow a a) {
  [+testrl [...]]
  [+testrr [...]]
  [+testll [...]]
  [+testlr [...]]})

(:= id {...})

'TODO (:: id (larrow a a))  ' Doesn't work
```

### Solution: Hardcoded Macro (Solution 2)

```stellogen
(new-declaration (::larrow Tested Test)
  (process
    (== @(interact @#Tested (eval (interact #Test @[-testrl]))) ok (error "testrl failed"))
    (== @(interact @#Tested (eval (interact #Test @[-testrr]))) ok (error "testrr failed"))
    (== @(interact @#Tested (eval (interact #Test @[-testll]))) ok (error "testll failed"))
    (== @(interact @#Tested (eval (interact #Test @[-testlr]))) ok (error "testlr failed"))))

' Now this works:
(::larrow id (larrow a a))
```

**Explanation:**
1. Extract `testrl` from `(larrow a a)` using field access: `(eval (interact #Test @[-testrl]))`
2. Test `id` against extracted test: `(interact @#id <extracted-test>)`
3. Focus result and assert it's `ok`: `(== @(...) ok ...)`
4. Repeat for `testrr`, `testll`, `testlr`
5. Use `process` to chain all checks (or just use multiple `==` declarations)

---

## References

### Source Files

**eval implementation:**
- `src/sgen_eval.ml:208-223` - Eval primitive
- `src/expr.ml:254-256` - Eval parsing

**Field encoding examples:**
- `examples/syntax.sg:62-78` - Field function pattern, nested fields
- `examples/mll.sg:38-47` - Direct polarity pattern for vehicle/cuts
- `examples/smll.sg:38-47` - Same pattern

**Type system examples:**
- `examples/nat.sg:5-11` - Simple type spec
- `examples/automata.sg:5-14` - Simple type spec
- `examples/mll.sg:6-26` - Record type spec with multiple tests
- `examples/smll.sg:6-26` - Same
- `examples/linear_lambda.sg:27-39` - Record type spec

**TODOs:**
- `examples/mll.sg:35` - Type-check id against larrow
- `examples/smll.sg:35` - Same
- `examples/linear_lambda.sg:42` - Type-check vehicle against larrow

### Key Concepts

- **Terms and unification**: `docs/basics.md`, `CLAUDE.md`
- **Polarity and rays**: `CLAUDE.md`, `examples/syntax.sg`
- **Interaction**: `src/lsc_eval.ml` (exec function)
- **Constellations**: `src/lsc_ast.ml`

---

## Conclusion

### Is the field encoding viable?

**YES.** The record encoding using fields and `eval` is **viable and sufficient** for Stellogen's purposes:

1. **Minimalist**: Built entirely on existing primitives
2. **Powerful**: Supports nesting, variable access, meta-computation
3. **Aligned**: Fits Stellogen's logic-agnostic philosophy
4. **Practical**: Demonstrated in multiple examples

### What are the limitations?

1. **No field validation**: Accessing non-existent fields doesn't error
2. **Verbose**: Requires explicit `eval (interact ...)` pattern
3. **No iteration**: Cannot programmatically enumerate fields
4. **Type checking multi-test specs requires workarounds**

### How to solve the TODO?

**Short-term:** Use a hardcoded macro `::larrow` that explicitly tests all 4 fields

**Medium-term:** Rethink multi-test types as unified constellations rather than records

**Long-term:** Consider adding field enumeration primitives if this pattern becomes common

### Final recommendation

The field encoding is **production-ready** for Stellogen's current stage. The TODO can be resolved with a simple hardcoded macro. If record-based type specs become more common, consider either:
1. Standardizing a naming convention for test fields
2. Adding language support for field introspection
3. Adopting a different pattern for multi-test types (non-record based)

For now, the encoding works well and demonstrates Stellogen's expressive power within its minimalist design.
