# Focus and Directionality in Stellogen: A Design Analysis

> **Disclaimer**: This document was written with the assistance of Claude Code and represents exploratory research and analysis. The content may contain inaccuracies or misinterpretations and should not be taken as definitive statements about the Stellogen language implementation.

**Date:** 2025-10-12
**Status:** Design Analysis
**Context:** Research on the `@` (focus) mechanism for controlling evaluation in Stellogen

---

## Abstract

This document analyzes the fundamental problem of **directionality** in Stellogen's execution model and evaluates whether the current **focus mechanism** (`@` symbol) is an intuitive, ergonomic, and philosophically consistent solution. We examine the design space of alternatives and provide recommendations based on first-principles thinking.

**Key Question:** In a language based on asynchronous, local interaction between stars, how do we achieve deterministic, effective computation without violating the philosophy of term unification?

---

## 1. The Fundamental Problem: Why Directionality Matters

### 1.1 Pure Fusion is Nondeterministic

Stellogen's core abstraction:
- **Stars** are independent agents (lists of rays with constraints)
- **Constellations** are collections of stars
- **Fusion** occurs when rays with opposite polarities unify (Robinson's resolution)
- **Computation** is the process of repeatedly fusing stars until no more interactions are possible

**The Problem:** Without additional structure, this model is:

1. **Completely symmetric** - no inherent order between stars
2. **Nondeterministic** - multiple fusion orders might be possible
3. **Potentially non-terminating** - fusion could loop infinitely
4. **Potentially explosive** - could explore exponentially many paths

**Example:** Given constellation `{A, B, C}` where all can interact:
- Fuse A+B first, then result with C?
- Fuse B+C first, then result with A?
- Fuse A with C, then result with B?
- ...

Without directionality, we get nondeterministic evaluation - antithetical to "effective computation."

### 1.2 What "Directionality" Must Achieve

A directionality mechanism must:

1. **Determinism**: Same constellation → same result (given same initial focus)
2. **Termination**: Prevent infinite loops where possible
3. **Predictability**: Users can reason about evaluation order
4. **Efficiency**: Avoid exploring all possible fusion orders
5. **Expressiveness**: Support diverse computational patterns (logic, functional, imperative)

But ideally without:
- Violating the "stars are independent agents" philosophy
- Imposing arbitrary global evaluation orders
- Making term unification play second fiddle to control flow

### 1.3 The Deeper Philosophical Tension

Stellogen's vision:
> "Compilers and interpreters no longer carry semantic authority: their role is only to check that blocks connect."

Yet **effective computation** requires some notion of order, sequence, and control. This creates a tension:
- **Pure stance**: Let term unification determine everything; embrace nondeterminism
- **Pragmatic stance**: Provide minimal control mechanisms to enable deterministic computation

The focus mechanism is Stellogen's answer to this tension.

---

## 2. The Current Solution: Focus (`@`)

### 2.1 Mechanism Overview

**Syntax:** Prefix `@` marks stars as focused.

```stellogen
{ [+a b] @[-c d] }
   ︸━━━┘  ︸━━━━┘
   action  state
```

**Semantics:** (from `src/lsc_eval.ml:48-164`)

1. **Classification**: Stars are partitioned into two categories:
   - **State stars** (marked with `@`): The targets of interaction
   - **Action stars** (unmarked): The interaction rules

2. **Duplication**:
   - States are **singular** - consumed and transformed during interaction
   - Actions are **duplicable** - can interact multiple times (in non-linear mode)

3. **Execution Loop**:
   ```
   while(states can interact):
     1. Select a state star
     2. Select a ray from that state
     3. Search for matching ray in action stars
     4. Fuse them (creating new state)
     5. Continue with updated state
   ```

4. **Directionality**: Actions interact **with** states; states are transformed **by** actions.

### 2.2 Key Design Choices

**Choice 1: Asymmetric Roles**
- States ≠ Actions
- This breaks perfect symmetry but provides directionality

**Choice 2: Duplication Control**
- Actions can be reused (non-linear) or consumed (linear with `fire`)
- States are always singular
- This prevents exponential blowup while enabling rule reuse

**Choice 3: Selection-Based**
- Execution selects rays from states
- Actions are searched for partners
- This creates a "demand-driven" feel

**Choice 4: Local Marking**
- Each star is marked individually with `@`
- No global evaluation order
- Preserves "local interaction" philosophy

### 2.3 Usage Patterns in Practice

Analyzing examples reveals clear patterns:

#### Pattern A: Rules + Query (Logic Programming)

```stellogen
(:= add {
  [(+add 0 Y Y)]
  [(-add X Y Z) (+add (s X) Y (s Z))]})

(:= query [(-add <s s 0> <s s 0> R) R])

(show (interact #add @#query))
```

**Intuition**:
- `add` defines rewrite rules (action)
- `query` is what we're computing (state)
- Focus says "compute this query using those rules"

**Natural?** YES - matches logic programming intuition.

#### Pattern B: Value + Type (Type Checking)

```stellogen
(new-declaration (:: Tested Test)
  (== @(interact @#Tested #Test) ok))

(:= 2 <+nat s s 0>)
(:: 2 nat)
```

**Intuition**:
- Value is focused (state)
- Type provides tests (action)
- "Check this value against this type"

**Natural?** YES - value is data, type is specification.

#### Pattern C: Data + Pattern (Pattern Matching)

```stellogen
(:= get_ok {
  [(-ok X) X]
  [(-error X) (+error X)]})

(show (interact #get_ok @#x))
```

**Intuition**:
- Data is focused (state)
- Pattern provides matching rules (action)
- "Match this data against these patterns"

**Natural?** YES - data vs pattern is clear.

#### Pattern D: Mixed Focus Within Constellation

```stellogen
(:= query6 {
  @[(-from 1)]      ' focused start
  [(-to 4) ok]})    ' unfocused goal
```

**Intuition**:
- Initial state is focused
- Goal/test is an action
- "Start here, reach goal"

**Natural?** SOMEWHAT - mixing states and actions in one constellation is subtle.

#### Pattern E: Ambiguous Cases

```stellogen
' Merging two lists?
(:= result (interact #list1 @#list2))
```

**Question**: Which should be focused if both are "data"?
**Answer**: Depends on which is being transformed vs which provides structure.

**Natural?** NOT ALWAYS CLEAR - when both sides are data, the asymmetry feels arbitrary.

---

## 3. Evaluating Intuitiveness and Ergonomics

### 3.1 Strengths of the Focus Mechanism

**S1. Clear Separation of Concerns**
- States = "what we're computing"
- Actions = "how we compute"
- This mirrors data/program distinction in many paradigms

**S2. Minimal Syntax**
- Just one symbol: `@`
- No complex annotations or type systems
- Easy to write and read

**S3. Flexible**
- Can focus individual stars
- Can focus entire constellations with `@{...}` or `@#identifier`
- Works with both `interact` (non-linear) and `fire` (linear)

**S4. Duplication Control**
- Solves a real problem (exponential blowup)
- Actions as reusable rules is natural
- Matches how rules work in rewriting systems

**S5. Compositional**
- Focus can be nested: `@(interact @#a #b)`
- Results can be refocused
- Works well with `process` for sequential computation

### 3.2 Weaknesses and Ambiguities

**W1. Asymmetry May Feel Arbitrary**
- When both sides are "data," which should be focused?
- Example: merging lists, composing functions, symmetric operations
- Solution: Convention or understanding that focus = "primary subject"

**W2. Not Emergent from Term Unification**
- Focus is an **external mechanism** layered on top
- It's not inherent to rays, polarities, or unification
- Violates the "everything is term interaction" philosophy

**W3. Learning Curve**
- Beginners must learn: "When do I use `@`?"
- Not obvious from first principles
- Requires understanding state/action distinction

**W4. Mixed Constellations Can Be Subtle**
- When a constellation has both `@` and non-`@` stars
- Requires understanding which stars are which roles
- Example: `query6` in prolog.sg is clever but not immediately obvious

**W5. Interaction with Polarity**
- Polarity already provides directionality (opposite polarities match)
- Focus adds a second layer of directionality
- Are these two mechanisms orthogonal or redundant?

### 3.3 Ergonomics Assessment

**Positive Developer Experience:**
- "I have data and I have rules → focus the data"
- "I'm type-checking a value → focus the value"
- "I'm pattern-matching → focus the scrutinee"

**Negative Developer Experience:**
- "Why did my computation not terminate?" (forgot to focus?)
- "Which side should I focus?" (when unclear)
- "Why is focus needed if polarity already directs interaction?"

**Overall Verdict**:
- **Good ergonomics for common patterns** (logic, typing, matching)
- **Ambiguous for symmetric operations** (composition, merging)
- **Additional concept to learn** (not derivable from simpler primitives)

---

## 4. Alternative Approaches Considered

To evaluate whether focus is the "right" solution, let's consider alternatives from first principles.

### Alternative 1: Polarity Alone

**Idea**: Use polarity (`+`/`-`) to determine directionality without `@`.

**Approach**:
- Positive stars are always "actions" (duplicable)
- Negative stars are always "states" (singular)

**Analysis**:
```stellogen
{
  [(+rule1 ...)]      ' action
  [(-query ...)]      ' state
}
```

**Pros:**
- No additional syntax
- Polarity already exists
- Very minimal

**Cons:**
- **Conflates matching with evaluation strategy**
  - Polarity is about which rays can fuse (opposite polarities)
  - Evaluation strategy is about which stars are duplicable
  - These are separate concerns!
- **Too restrictive**: What if a state needs mixed polarity rays?
- **Not compositional**: Hard to change evaluation strategy without changing term structure

**Verdict**: PHILOSOPHICALLY CLEANER but PRACTICALLY INSUFFICIENT. Polarity and duplication control are distinct concerns.

### Alternative 2: Explicit Evaluation Order

**Idea**: Make execution order explicit in the constellation structure.

**Approach A - Numbered Stars**:
```stellogen
{
  1: [star1]
  2: [star2]
  3: [star3]
}
```
Execute in numeric order.

**Approach B - Ordered Sequences**:
```stellogen
(sequence [star1] [star2] [star3])
```

**Analysis**:

**Pros:**
- Maximum control
- No ambiguity
- Explicit sequencing

**Cons:**
- **Violates "stars are independent agents"** - introduces global order
- **Constellations become sequences** - loses set-like nature
- **Verbose**: Every constellation needs ordering
- **Imperative, not declarative**: Feels like assembly language

**Verdict**: TOO RESTRICTIVE. Destroys the elegance of constellations as sets of interacting agents.

### Alternative 3: Demand-Driven (Lazy)

**Idea**: Identify "output" rays and pull computation backward.

**Approach**:
```stellogen
{
  [(-input X) ...]
  [... (+output Y)]     ' marked as output
}
```
Only evaluate what's needed to produce `output`.

**Analysis**:

**Pros:**
- Natural for functional composition
- Avoids unnecessary computation
- Familiar from lazy languages

**Cons:**
- **Requires identifying outputs** - what if multiple outputs?
- **Complex implementation**: Tracking dependencies backward
- **Less intuitive for imperative patterns**: State transformations don't fit
- **May not terminate**: Infinite lazy structures

**Verdict**: INTERESTING but DOESN'T FIT STELLOGEN'S MULTI-PARADIGM NATURE. Too functional-centric.

### Alternative 4: Resource-Aware Annotations

**Idea**: Explicitly annotate stars as linear or duplicable.

**Approach**:
```stellogen
{
  !(linear_star)      ' consumed once
  *(duplicable_rule)  ' reusable
}
```

**Analysis**:

**Pros:**
- **Orthogonal to focus**: Could combine with current system
- **Explicit resource control**: Like linear logic
- **Flexible**: Different patterns for different stars

**Cons:**
- **More annotations**: `!`, `*`, `@` become overlapping
- **Complexity**: Users must understand linear logic
- **Still needs directionality**: Doesn't solve which stars interact first

**Verdict**: ORTHOGONAL CONCERN. Stellogen already has `fire` vs `interact` for linearity. This doesn't replace focus, it complements it.

### Alternative 5: Pattern-Directed Heuristics

**Idea**: Infer evaluation strategy from constellation structure.

**Approach**:
- Stars with more negative rays are "queries/states"
- Stars with more positive rays are "rules/actions"
- Pure heuristics, no annotations

**Analysis**:

**Pros:**
- No additional syntax
- "Emergent" from structure
- Could work for simple cases

**Cons:**
- **Unreliable**: What about balanced stars?
- **Not predictable**: User can't control evaluation
- **Implicit magic**: Hard to reason about
- **Fails for symmetric cases**: Composition, merging, etc.

**Verdict**: TOO FRAGILE. Heuristics are dangerous for language semantics.

### Alternative 6: Multiple Focus Levels

**Idea**: Different kinds of focus for different evaluation strategies.

**Approach**:
```stellogen
{
  @[primary_state]      ' main focus
  *[secondary_action]   ' helper rules
  #[background_data]    ' passive data
}
```

**Analysis**:

**Pros:**
- **More expressive**: Could model complex patterns
- **Finer control**: Different interaction modes

**Cons:**
- **Complexity explosion**: Too many concepts
- **Cognitive overhead**: When to use which?
- **Not minimal**: Violates Stellogen's simplicity

**Verdict**: TOO COMPLEX. Stellogen should stay minimal.

### Alternative 7: Pure Nondeterminism

**Idea**: Embrace nondeterminism. Return **all possible results**.

**Approach**: Evaluation explores all fusion orders and returns the set of all normal forms.

**Analysis**:

**Pros:**
- **Purest to philosophy**: No control, just interaction
- **Maximally declarative**: Specify what, not how
- **Complete exploration**: No missed possibilities

**Cons:**
- **Computationally explosive**: Exponential/infinite possibilities
- **Not "effective"**: Can't build practical programs
- **Impractical**: Most computations need one result

**Verdict**: PHILOSOPHICALLY PURE but PRAGMATICALLY USELESS. Directionality is necessary for effective computation.

### Alternative 8: Stratification by Polarity Layers

**Idea**: Group stars by polarity patterns and execute in layers.

**Approach**:
```stellogen
{
  ' Layer 1: Pure positive (facts)
  [(+parent tom bob)]
  [(+parent bob ann)]

  ' Layer 2: Mixed (rules)
  [(-grandparent X Z) (-parent X Y) (+parent Y Z)]

  ' Layer 3: Pure negative (queries)
  [(-grandparent tom Z) Z]
}
```

Execute pure positive first, then mixed, then pure negative.

**Analysis**:

**Pros:**
- **Emergent from polarities**: Uses existing mechanism
- **Stratified logic**: Clean layers
- **No new syntax**: Inferred from structure

**Cons:**
- **Too rigid**: Doesn't fit all patterns
- **Still needs ordering**: Which mixed stars first?
- **Not always clear**: What about neutral rays?

**Verdict**: INTERESTING STRUCTURE but DOESN'T FULLY SOLVE THE PROBLEM.

---

## 5. Deep Dive: What Focus Really Achieves

### 5.1 The State/Action Dichotomy

The focus mechanism creates a fundamental asymmetry:

| Aspect | States (`@`) | Actions (no `@`) |
|--------|--------------|------------------|
| **Role** | Data being computed | Rules for computation |
| **Quantity** | Singular (consumed) | Duplicable (reused) |
| **Selection** | Selected first | Searched for partners |
| **Intuition** | "Subject" | "Verb" |

This is a **subject-verb** distinction:
- States are what the computation is "about"
- Actions are what "happens to" the states

### 5.2 Connection to Other Paradigms

**Logic Programming:**
- States = Queries/Goals
- Actions = Facts + Rules
- Focus = "Prove this using these"

**Functional Programming:**
- States = Arguments/Values
- Actions = Functions
- Focus = "Apply these to this"

**Rewriting Systems:**
- States = Terms to rewrite
- Actions = Rewrite rules
- Focus = "Rewrite this using these"

**Type Checking:**
- States = Values to check
- Actions = Type specifications
- Focus = "Check this against these"

The focus mechanism is **multi-paradigm** - it doesn't commit to one computational model.

### 5.3 Why Not Just Polarity?

Crucial insight: **Polarity and focus serve different purposes.**

**Polarity** answers: "Which rays can fuse?"
- `(+f X)` matches `(-f a)` ✓
- `(+f X)` matches `(+f a)` ✗

**Focus** answers: "Which stars are duplicable and which are selection targets?"
- `@[...]` is singular, selected first
- `[...]` is duplicable, searched for matches

These are **orthogonal concerns**:
- You can have `@[(+f X)]` or `[(+f X)]` - same polarity, different evaluation
- You can have `@[(-f X) (+g Y)]` - mixed polarities in one state

**Example showing orthogonality:**

```stellogen
' Same polarities, different evaluation strategy
(:= v1 (interact @[(+f a)] [(+f b)]))  ' @[(+f a)] is state
(:= v2 (interact [(+f a)] @[(+f b)]))  ' @[(+f b)] is state
```

Both have positive rays, but focus determines which is transformed.

### 5.4 The Duplication Control Problem

Without duplication control:

```stellogen
{
  @[(-f X) (result X)]     ' state
  [(+f a)]                 ' action 1
  [(+f b)]                 ' action 2
}
```

Should both actions match? If yes, we get two results:
- `{(result a), [(+f b)]}`
- `{(result b), [(+f a)]}`

Then these interact further, creating exponential branches.

**Focus + duplication solves this:**
- Actions are duplicable: both can try to match
- State is singular: only one branch continues
- Result: Nondeterminism is bounded

**This is crucial for termination and efficiency.**

---

## 6. Philosophical Alignment

### 6.1 Does Focus Violate Stellogen's Philosophy?

Stellogen's core principle:
> "Elementary interactive building blocks where both computation and meaning live in the same language."

**Argument AGAINST focus:**
- Focus is a **meta-level mechanism** external to term unification
- It imposes evaluation strategy rather than letting it emerge
- Violates purity of "stars are just stars"

**Argument FOR focus:**
- **Practical necessity**: Effective computation requires some directionality
- **Minimal intervention**: Just one symbol, doesn't change term structure
- **Preserves locality**: Each star marked individually, no global order
- **User empowerment**: Users choose evaluation strategy explicitly

**Comparison to other minimalist languages:**

| Language | Pure Ideal | Pragmatic Concession |
|----------|------------|---------------------|
| Lambda Calculus | Pure β-reduction | Call-by-value vs call-by-name |
| Prolog | Pure resolution | Cut operator `!` |
| Haskell | Pure functions | `IO` monad, strictness annotations |
| Stellogen | Pure fusion | Focus `@` for directionality |

**Verdict**: Every "pure" language makes pragmatic concessions. Focus is Stellogen's minimal concession to effective computation.

### 6.2 Is There a "More Pure" Alternative?

Could we eliminate focus entirely?

**Option A: Accept nondeterminism**
- Return all possible results
- Let users filter/choose
- **Problem**: Computationally explosive, impractical

**Option B: Use polarity alone**
- Convention: positive = action, negative = state
- **Problem**: Conflates matching with evaluation, too restrictive

**Option C: Implicit heuristics**
- Infer evaluation strategy from structure
- **Problem**: Unpredictable, unreliable, hard to reason about

**Conclusion**: No alternative is clearly "more pure" AND practical. Focus represents a reasonable balance.

---

## 7. Ergonomics: Can We Do Better?

### 7.1 Current Pain Points

**P1. When is focus placement obvious?**
- ✓ Logic programming: query focused
- ✓ Type checking: value focused
- ✓ Pattern matching: scrutinee focused
- ✗ Symmetric operations: arbitrary

**P2. Error messages when focus is wrong?**
- Non-termination: hard to debug
- Wrong results: may not be obviously wrong
- **Need**: Better error messages and guidance

**P3. Teaching focus to beginners**
- Requires understanding state/action distinction
- Not derivable from simpler concepts
- **Need**: Better tutorials and examples

### 7.2 Potential Improvements

**Improvement 1: Better Error Messages**

Currently: Program loops or gives unexpected results.

Suggested:
- "Warning: No focused stars in constellation - execution may not terminate"
- "Hint: Consider focusing the query/data/value being computed"

**Improvement 2: Linting Rules**

Detect suspicious patterns:
- Constellation with no focused stars
- Multiple focused stars that might conflict
- Focus placement that might cause non-termination

**Improvement 3: Teaching Materials**

Clear guide on:
- "What is focus?"
- "When to use focus?"
- "How to debug focus issues?"
- "Common focus patterns"

**Improvement 4: Alternative Syntax (Optional)**

If `@` is unintuitive, could introduce named roles:

```stellogen
(interact (state: #query) (rules: #add))
```

But this is more verbose and less minimal.

**Improvement 5: Type System for Focus**

Could type system track focus?
```stellogen
type focused[T]   ' a focused constellation of type T
type action[T]    ' an action constellation of type T
```

Ensures focus is used correctly at compile time.

But this adds complexity.

### 7.3 Documentation Improvements

Current docs (basics.md) say:
> "State stars are marked with `@`. They are the 'targets' for interaction."

This is correct but minimal. Suggested additions:

**Section: "Understanding Focus"**
- Why directionality is needed
- What focus controls (selection + duplication)
- Common patterns and when to use them

**Section: "Focus Intuition"**
- States = "what you're computing"
- Actions = "how you compute"
- Examples showing both sides

**Section: "Debugging Focus Issues"**
- Non-termination
- Unexpected results
- How to experiment with focus placement

---

## 8. Recommendations

Based on this analysis, here are concrete recommendations:

### Recommendation 1: Keep the Current Focus Mechanism (HIGH PRIORITY)

**Rationale:**
- No clear alternative is better
- Works well for common patterns
- Minimal and flexible
- Proven in practice (multiple examples work well)

**Evidence:**
- Examined 7 alternative approaches - none clearly superior
- Current system handles logic, functional, typing, matching patterns
- Philosophical objections don't outweigh pragmatic benefits

### Recommendation 2: Improve Documentation (HIGH PRIORITY)

**Action Items:**
1. Add "Understanding Focus" section to basics.md explaining:
   - Why directionality is needed (nondeterminism problem)
   - What focus controls (selection + duplication)
   - State vs Action intuition
   - Common patterns with examples

2. Add "Focus Patterns" guide showing:
   - Logic programming: `(interact #rules @#query)`
   - Type checking: `(interact @#value #type)`
   - Pattern matching: `(interact #patterns @#data)`
   - Sequential computation: `(process @#init #step1 #step2)`

3. Add "Debugging Focus" section covering:
   - How to diagnose non-termination
   - How to choose focus placement
   - Experimentation strategies

### Recommendation 3: Add Better Error Diagnostics (MEDIUM PRIORITY)

**Action Items:**
1. Warn when constellation has no focused stars
2. Detect obvious non-termination patterns
3. Suggest focus placement for common patterns
4. Provide hints in error messages

**Example:**
```
Warning: No focused stars in constellation at line 42
  Hint: Consider focusing the data/query/value being computed
  Example: (interact #rules @#query)
```

### Recommendation 4: Consider Naming (LOW PRIORITY)

**Current:** `@` symbol
**Alternative:** Could use `state:` and `action:` keywords

**Analysis:**
- `@` is minimal and works well once learned
- Keywords would be more explicit but verbose
- Not worth changing unless users consistently confused

**Verdict:** Keep `@` for now, monitor user feedback.

### Recommendation 5: Research "Focus Inference" (FUTURE WORK)

**Idea:** Could the system infer focus placement in simple cases?

**Heuristic:**
- If one side is clearly "data" and other is clearly "rules"
- Infer focus automatically
- Allow manual override with `@`

**Example:**
```stellogen
' Could infer that query should be focused?
(interact #add #query)  ' infer: @#query

' Manual override when unclear
(interact #list1 @#list2)
```

**Challenges:**
- Defining reliable heuristics
- Maintaining predictability
- Avoiding implicit magic

**Verdict:** Interesting but risky. Current explicit approach is safer.

### Recommendation 6: Explore Polarity Extensions (FUTURE RESEARCH)

**Idea:** Could we enrich polarity to partially address directionality?

**Possible approach:**
- `+` = positive (produces)
- `-` = negative (consumes)
- `?` = query (demands)
- `!` = answer (supplies)

This gives more granularity while staying within term structure.

**Analysis:**
- Could reduce need for focus in some cases
- But still need duplication control
- Increases complexity of polarity system

**Verdict:** Worth exploring but not replacing focus entirely.

---

## 9. Conclusion

### 9.1 Direct Answer to the Question

> "Is the focus mechanism (`@` symbol choosing states vs actions) a good, intuitive, and ergonomic way to treat directionality?"

**Answer: YES, with caveats.**

**Good:**
- ✓ Solves the directionality problem effectively
- ✓ Handles multiple computational paradigms
- ✓ Minimal syntax (one symbol)
- ✓ Proven in practice (works across diverse examples)
- ✓ No clearly superior alternative exists

**Intuitive:**
- ✓ Natural for common patterns (logic, typing, matching)
- ⚠ Ambiguous for symmetric operations
- ⚠ Requires learning state/action distinction
- ⚠ Not derivable from simpler principles

**Ergonomic:**
- ✓ Easy to write (`@` prefix)
- ✓ Compositional (can nest, focus groups)
- ⚠ Error messages need improvement
- ⚠ Teaching materials need enhancement

### 9.2 The Deeper Insight

The focus mechanism reveals a fundamental truth:

**Effective computation requires distinguishing:**
1. **What is being computed** (the subject)
2. **How it is computed** (the verb)

This distinction is universal across paradigms:
- Logic: queries vs rules
- Functional: arguments vs functions
- Rewriting: terms vs rules
- Typing: values vs types

**Focus is Stellogen's way of expressing this universal distinction while staying as close as possible to pure term unification.**

### 9.3 Philosophical Verdict

Is focus a "concession" to pragmatism or a "natural extension" of the philosophy?

**Both.**
- It IS a concession: adds mechanism beyond pure fusion
- It IS natural: minimal, local, user-controlled
- It PRESERVES core philosophy: stars are still independent, interactions are still local
- It ENABLES effective computation: makes Stellogen practical

**The alternative (pure nondeterminism) would be philosophically purer but computationally useless.**

Focus represents Stellogen finding its balance between purity and pragmatism.

---

## 10. Alternative Ideas Worth Exploring

While focus should be kept, these ideas could complement it:

### Idea 1: Focus Inference for Simple Cases

Automatically infer focus when pattern is obvious, allow manual override.

### Idea 2: Focus Annotations in Types

If Stellogen gains a richer type system, track focused vs unfocused types.

### Idea 3: Multiple Execution Modes

- `interact`: current non-linear mode
- `fire`: current linear mode
- `explore`: return all possible results (for small cases)
- `lazy`: demand-driven evaluation
- `eager`: evaluate everything immediately

Users choose based on needs.

### Idea 4: Visual Tools

IDE support for visualizing:
- Which stars are states vs actions
- Execution trace showing interactions
- Focus placement suggestions

### Idea 5: Bidirectional Focus

Currently focus is unidirectional (actions → states).
Could we support bidirectional interaction?

```stellogen
{
  @[star1] <-> @[star2]   ' both are states, interact symmetrically
}
```

Useful for symmetric operations (merging, composing).

---

## Appendix A: Focus Usage Patterns Summary

| Pattern | State (Focused) | Action (Unfocused) | Example |
|---------|----------------|-------------------|---------|
| **Logic Programming** | Query/Goal | Facts + Rules | `(interact #rules @#query)` |
| **Type Checking** | Value | Type Tests | `(interact @#value #type)` |
| **Pattern Matching** | Scrutinee | Patterns | `(interact #patterns @#data)` |
| **Rewriting** | Term | Rewrite Rules | `(interact #rules @#term)` |
| **State Machine** | Current State | Transitions | `(interact #transitions @#state)` |
| **Sequential Computation** | Accumulator | Transformations | `(process @#init #f #g #h)` |

---

## Appendix B: Implementation Notes

### Current Implementation (`src/lsc_eval.ml`)

Key functions:
- `classify`: Separates stars into actions and states (line 48-56)
- `select_star`: Chooses state star for interaction (line 139-154)
- `search_partners`: Finds matching actions (line 97-118)
- `interaction`: Performs fusion (line 62-94)
- `exec`: Main execution loop (line 156-164)

### Evaluation Algorithm

```
exec(constellation):
  (actions, states) := classify(constellation)

  loop:
    if no more interactions possible:
      return states

    select state_star from states:
      select ray from state_star:
        search for matching ray in actions:
          if match found:
            fuse -> new_star
            update states with new_star
            continue loop
```

### Linearity Control

- `interact`: Actions remain duplicable
- `fire`: Actions consumed after first match
- Orthogonal to focus but works together

---

*This analysis was conducted through systematic examination of Stellogen's implementation, examples, and deep thinking about the design space. All conclusions are based on first-principles reasoning about computation, directionality, and language design.*
