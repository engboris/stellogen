# Termination Detection in Stellogen Programs

**Date:** October 2025
**Status:** Research Document

## Executive Summary

This document investigates approaches for detecting termination and non-termination in Stellogen programs. The core idea, inspired by term rewriting systems, is to track whether terms decrease in size after fusion operations. We explore multiple termination detection strategies, their theoretical foundations, practical implementation considerations, and limitations specific to Stellogen's unification-based interaction model.

## 1. Background: Stellogen's Execution Model

### 1.1 Fusion and Interaction

Stellogen programs execute through a process of **fusion** between polarized rays. The execution model consists of:

1. **Stars**: Collections of rays with associated constraint bans
   - **State stars**: Contain rays that seek interaction partners
   - **Action stars**: Contain rays available for fusion

2. **Interaction rounds**: The `exec` function (`src/lsc_eval.ml:156-164`) performs iterative rounds:
   - Select a polarized ray from a state star
   - Search for a compatible ray in action stars using unification (`raymatcher`)
   - If unification succeeds (returns `Some theta`), perform fusion
   - Continue until no more interactions are possible (fixed point)

3. **Fusion operation** (`src/lsc_eval.ml:14-21`):
   ```ocaml
   fusion repl1 repl2 s1 s2 bans1 bans2 theta
   ```
   - Combines content from both stars: `new1 @ new2`
   - Applies substitution `theta` from unification
   - Merges constraint bans
   - **Key observation**: Resulting star's content is combination of both inputs

### 1.2 Termination Characteristics

**Natural termination** occurs when:
- No more unifications are possible (all rays are non-polarized or incompatible)
- The system reaches a **fixed point**

**Non-termination risk** when:
- Fusion generates new rays that match with existing rays
- Creates cycles where each fusion enables another fusion
- Term sizes grow unboundedly or cycle indefinitely

**Example scenarios:**
- **Terminating**: Natural number addition where successor terms decrease to zero
- **Potentially non-terminating**: Graph traversal with cycles, where composition rules could loop forever

## 2. Term Size Measures

Multiple size measures can be applied to Stellogen terms, each capturing different aspects of term complexity.

### 2.1 Constructor Count (Syntactic Size)

**Definition**: Count all function symbols (constructors) in a term, excluding variables.

For term type `Var of idvar | Func of idfunc * term list`:

```ocaml
let rec term_size = function
  | Var _ -> 0
  | Func (_, args) -> 1 + List.fold_left (fun acc t -> acc + term_size t) 0 args
```

**Properties:**
- Simple to compute
- Measures syntactic complexity
- Examples:
  - `(s (s 0))` has size 3
  - `(add X Y)` has size 1
  - `X` has size 0

**Advantages:**
- Fast computation
- Clear intuition
- Works well for data structure transformations

**Disadvantages:**
- Doesn't account for variable instantiation
- Substitution can dramatically change size
- May miss logical complexity

### 2.2 Maximum Depth

**Definition**: Maximum nesting level of constructors.

```ocaml
let rec term_depth = function
  | Var _ -> 0
  | Func (_, args) ->
      if List.is_empty args then 1
      else 1 + List.fold_left (fun acc t -> max acc (term_depth t)) 0 args
```

**Properties:**
- Measures structural depth
- Examples:
  - `(s (s 0))` has depth 3
  - `(add X Y)` has depth 1
  - `[a, b, c]` (as nested cons) has depth 4

**Advantages:**
- Captures nesting complexity
- Less sensitive to width of terms

**Disadvantages:**
- Wide terms (many arguments) treated same as narrow
- May not detect accumulation of parallel structures

### 2.3 Star Size (Constellation Measure)

**Definition**: Measure entire stars and constellations, not just individual rays.

```ocaml
type star_measure = {
  ray_count: int;        (* number of rays in star *)
  total_term_size: int;  (* sum of all ray sizes *)
  max_ray_size: int;     (* largest ray *)
}

let star_size (star: Raw.star) =
  let ray_sizes = List.map term_size star.content in
  {
    ray_count = List.length ray_sizes;
    total_term_size = List.fold_left (+) 0 ray_sizes;
    max_ray_size = List.fold_left max 0 ray_sizes;
  }
```

**Properties:**
- Captures growth in number of rays
- Fusion combines rays: `new1 @ new2`
- Multiple rays can indicate progress or divergence

**Advantages:**
- Natural fit for Stellogen's star-based model
- Detects accumulation of multiple terms
- Can use multiset orderings

**Disadvantages:**
- More complex to implement
- Harder to establish well-founded orderings

### 2.4 Weighted Measure

**Definition**: Assign weights to different constructors based on their computational significance.

```ocaml
let constructor_weight = function
  | (_, "s")   -> 1    (* successor *)
  | (_, "0")   -> 0    (* zero base case *)
  | (_, "add") -> 2    (* recursive operation *)
  | (_, "cons") -> 1   (* list constructor *)
  | (_, "nil")  -> 0   (* list base case *)
  | _ -> 1             (* default *)

let rec weighted_size = function
  | Var _ -> 0
  | Func (f, args) ->
      constructor_weight f +
      List.fold_left (fun acc t -> acc + weighted_size t) 0 args
```

**Advantages:**
- Can prioritize important reductions
- Domain-specific tuning
- Better matches semantic significance

**Disadvantages:**
- Requires domain knowledge
- Weights are heuristic
- No universal weight assignment

## 3. Termination Detection Strategies

### 3.1 Size-Change Principle

Based on research from term rewriting systems (Lee et al., 2001; Thiemann & Giesl, 2005), the **size-change principle** states:

**Termination criterion**: A program terminates if, in every possible infinite execution path, at least one parameter decreases in size infinitely often.

**Application to Stellogen:**

1. **Track size through fusion operations**
   - Before fusion: measure sizes of both input stars
   - After fusion: measure size of resulting star
   - Record: `(size_before, size_after)`

2. **Build size-change graph**
   - Nodes: program points (constellation definitions)
   - Edges: fusion transitions with size relationships
   - Labels: ↓ (strictly decreasing), ↓= (non-increasing), ↑ (increasing)

3. **Check for decreasing paths**
   - If all infinite paths contain infinitely many ↓ edges → terminates
   - If path exists with only ↓= or ↑ edges → may not terminate

**Example implementation sketch:**

```ocaml
type size_change = Decreasing | NonIncreasing | Increasing | Unknown

let compare_sizes before after =
  if after < before then Decreasing
  else if after = before then NonIncreasing
  else if after > before then Increasing
  else Unknown

let track_fusion_step (before_state, before_action) after_result =
  let size_before = star_size before_state + star_size before_action in
  let size_after = star_size after_result in
  compare_sizes size_before.total_term_size size_after.total_term_size
```

**Challenges for Stellogen:**
- Substitutions can cause unpredictable size changes
- Multiple rays interact simultaneously
- Non-deterministic interaction order
- Size might temporarily increase before decreasing

### 3.2 Bounded Execution Monitoring

A practical approach: detect potential non-termination by monitoring resource bounds during execution.

**Implementation approach:**

```ocaml
type execution_bounds = {
  max_rounds: int;           (* maximum interaction rounds *)
  max_constellation_size: int; (* maximum total star count *)
  max_term_depth: int;       (* maximum term nesting *)
}

let exec_with_bounds bounds mcs =
  let rec loop rounds (actions, states) =
    (* Check bounds *)
    if rounds > bounds.max_rounds then
      Error (PossibleNonTermination "exceeded max rounds")
    else if List.length states > bounds.max_constellation_size then
      Error (PossibleNonTermination "constellation too large")
    else if List.exists (fun s ->
        List.exists (fun r -> term_depth r > bounds.max_term_depth) s.content
      ) states then
      Error (PossibleNonTermination "term depth exceeded")
    else
      (* Continue normal execution *)
      match select_star ~linear:false ~queue:[] actions states with
      | None, _ -> Ok states
      | Some res, new_actions -> loop (rounds + 1) (new_actions, res)
  in
  let cfg = extract_intspace mcs in
  loop 0 cfg
```

**Advantages:**
- Practical and implementable immediately
- Provides early warning
- Can be configurable per program

**Disadvantages:**
- False positives: flags slow but terminating programs
- False negatives: might not catch subtle divergence
- Requires tuning bounds

### 3.3 Cycle Detection in Interaction History

Track constellation states seen during execution to detect cycles.

**Approach:**

```ocaml
module ConstellationSet = Set.Make(struct
  type t = Marked.constellation
  let compare = compare (* using normalized form *)
end)

let exec_with_cycle_detection mcs =
  let rec loop seen_states (actions, states) =
    (* Normalize current state for comparison *)
    let normalized = Marked.normalize_all (Marked.make_state_all states) in

    if ConstellationSet.mem normalized seen_states then
      Error (CycleDetected "constellation state repeated")
    else
      let new_seen = ConstellationSet.add normalized seen_states in
      match select_star ~linear:false ~queue:[] actions states with
      | None, _ -> Ok states
      | Some res, new_actions -> loop new_seen (new_actions, res)
  in
  let cfg = extract_intspace mcs in
  loop ConstellationSet.empty cfg
```

**Advantages:**
- Definitively detects cycles
- No false positives for cyclic non-termination

**Disadvantages:**
- Memory intensive (stores all states)
- Doesn't detect non-terminating divergence (unbounded growth)
- Constellation comparison is expensive
- Variable renaming makes comparison difficult

### 3.4 Well-Founded Orderings with Multisets

Use multiset orderings from term rewriting literature (Dershowitz & Manna, 1979).

**Multiset ordering** `>_mul`:
- Given ordering `>` on terms
- Multiset M1 `>_mul` M2 if M1 can be obtained from M2 by replacing elements with smaller ones
- Well-founded if base ordering is well-founded

**Application:**
- Represent star content as multiset of rays
- Define ordering on rays (e.g., by term size)
- Track whether star multisets decrease through fusion

```ocaml
(* Simplified example *)
let ray_ordering r1 r2 =
  term_size r1 > term_size r2

let multiset_decreasing ms1 ms2 =
  (* Check if ms1 >_mul ms2 using ray_ordering *)
  (* Implementation requires multiset comparison algorithm *)
  ...
```

**Advantages:**
- Theoretically sound
- Handles multiple rays naturally
- Well-established in term rewriting

**Disadvantages:**
- Complex to implement correctly
- Expensive computation
- Requires well-founded base ordering
- May be too conservative (rejects terminating programs)

### 3.5 Dependency Pair Analysis

Adapted from dependency pair framework for term rewriting (Arts & Giesl, 2000).

**Core idea:**
- Identify "recursive" fusion patterns (constellations that interact with themselves)
- Build dependency graph showing which constellations can trigger which others
- Analyze cycles in dependency graph with decreasing measures

**Steps:**
1. Extract dependency pairs from constellation definitions
2. Build dependency graph
3. For each cycle, check if a termination proof exists (e.g., size decrease)

**For Stellogen:**
- Constellation definitions are like rewrite rules
- Fusion corresponds to rule application
- Recursive patterns occur when constellation interacts with instances of itself

**Challenges:**
- Stellogen's dynamic interaction makes static analysis difficult
- Unification-based matching is more flexible than pattern matching
- Would require significant analysis infrastructure

## 4. Practical Implementation Recommendations

### 4.1 Incremental Approach

Start with simple, practical measures:

**Phase 1: Warning system (immediate)**
- Implement bounded execution monitoring
- Configurable limits: rounds, constellation size, term depth
- Emit warnings when limits approached
- Continue execution (don't halt)

**Phase 2: Optional strict mode**
- Add flag `--termination-check` to enable strict checking
- Halt execution if bounds exceeded
- Useful for testing and debugging

**Phase 3: Size tracking instrumentation**
- Add optional instrumentation to track size changes
- Output: `fusion i: size before=X, size after=Y, change=Z`
- Helps users understand their programs
- No automatic decisions

**Phase 4: Advanced analysis (future)**
- Implement size-change analysis
- Dependency pair framework
- Integration with type system

### 4.2 Recommended Size Measure

For initial implementation, use **combined measure**:

```ocaml
type fusion_metrics = {
  star_count: int;           (* number of stars in constellation *)
  total_constructors: int;   (* sum of constructor counts *)
  max_depth: int;           (* maximum term depth *)
}

let measure_constellation (stars: Raw.constellation) =
  let star_count = List.length stars in
  let all_rays = List.concat_map (fun s -> s.content) stars in
  let constructor_counts = List.map term_size all_rays in
  let depths = List.map term_depth all_rays in
  {
    star_count;
    total_constructors = List.fold_left (+) 0 constructor_counts;
    max_depth = List.fold_left max 0 depths;
  }
```

**Use all three components:**
- Star count: detects accumulation
- Constructor count: tracks syntactic growth
- Max depth: catches deep nesting

### 4.3 Configuration

Add to program or command-line:

```stellogen
' Set termination bounds
(:= termination-config {
  (max-rounds 10000)
  (max-constellation-size 1000)
  (max-term-depth 100)
  (warn-on-approach true)
})
```

Or CLI flags:
```bash
sgen run --max-rounds 10000 --max-depth 100 program.sg
```

## 5. Limitations and Challenges

### 5.1 Fundamental Undecidability

**Rice's Theorem**: Any non-trivial semantic property of programs is undecidable.

For Stellogen:
- Perfect termination detection is impossible
- Can only provide conservative approximations or runtime bounds

### 5.2 Substitution Effects

**Problem**: Unification substitutions can cause unpredictable size changes.

Example:
```
Before fusion:
  Ray 1: (+add X Y)           size=1
  Ray 2: (-add (s (s 0)) Z)   size=3

After unification with θ = {X ↦ (s (s 0))}:
  Result: (+add (s (s 0)) Y)  size=3
```

The substitution instantiates `X`, increasing size. This is normal and desired behavior, not necessarily a sign of non-termination.

**Mitigation:**
- Track size of instantiated terms separately
- Consider measure that accounts for variable instantiation potential
- Use weighted measures that discount variable costs

### 5.3 Non-deterministic Interaction Order

The `select_star` and `select_ray` functions choose which rays interact, but order is implementation-dependent. Different orders can lead to:
- Different term sizes at intermediate steps
- Different number of rounds
- Potentially different termination behavior (though confluence suggests same final result)

**Implication**: Size measurements depend on execution strategy, making static analysis harder.

### 5.4 Focus and Process Constructs

Stellogen has higher-level constructs:
- `Focus (@e)`: Evaluates expression first
- `Process`: Chains constellations

These complicate termination analysis:
- Need to analyze composition of constellations
- Focus evaluation might itself not terminate
- Process chaining creates execution phases

**Approach**: Analyze each component separately, then compose results.

### 5.5 Circular Definitions

Stellogen allows definitions like:
```stellogen
(:= loop [(-loop X) (+loop X)])
```

This creates potential for infinite cycles. Detection requires:
- Tracking which identifiers are referenced
- Building call graph
- Detecting strongly connected components

### 5.6 Bans and Constraints

Stellogen's ban system (`|| (!= X Y)`) adds constraints that prevent certain fusions. This affects termination:
- Bans might prevent infinite loops (positive effect)
- Or they might prevent necessary reductions (negative effect)

Analysis must incorporate ban checking into size-change tracking.

## 6. Related Work and Theoretical Foundations

### 6.1 Term Rewriting Systems

**Key papers:**
- **Dershowitz (1979)**: Recursive path ordering, foundational well-founded ordering for terms
- **Lee, Jones, Ben-Amram (2001)**: Size-change principle for first-order functional programs
- **Thiemann & Giesl (2005)**: Size-change termination for term rewriting

**Relevance**: Stellogen's fusion resembles term rewriting with unification. Techniques from this field directly apply.

### 6.2 Logic Programming Termination

**Approaches:**
- **Level mapping**: Assign natural numbers to predicates, require decrease in recursive calls
- **Acceptability**: Variant of level mapping with semantic checks
- **Polytool**: Automated termination analyzer for Prolog

**Relevance**: Stellogen shares unification and backtracking-like behavior with logic programming. Level mapping could inspire star-to-number mappings.

### 6.3 Interaction Nets

**Lafont (1990)**: Original interaction nets paper
- Guaranteed strong normalization for certain classes
- Relies on specific constraints (e.g., no duplicate wires)
- Stellogen is more permissive

**Comparison**: Stellogen's polarity-based fusion is inspired by interaction nets but doesn't enforce their strict constraints, making termination analysis harder but the language more expressive.

### 6.4 Graph Rewriting

**Plump (1999)**: Termination of graph rewriting
- Uses graph measures (nodes, edges)
- Defines well-founded orderings on graphs

**Relevance**: Stars and constellations can be viewed as hypergraphs. Graph rewriting termination techniques might apply.

### 6.5 Well-Founded Recursion

**Principle**: Functions terminate if they recurse on structurally smaller arguments according to a well-founded relation.

**Well-founded relation**: `>` where no infinite descending chains exist: ¬∃ (x₀ > x₁ > x₂ > ...)

**Examples:**
- Natural numbers with `>`
- Finite trees with subterm ordering
- Lexicographic combinations of well-founded orders

**Application**: Define well-founded ordering on Stellogen terms/stars, prove fusion decreases according to this ordering.

## 7. Experiments and Validation

### 7.1 Test Suite

Create test programs spanning:

1. **Definitely terminating:**
   - `nat.sg` examples (addition, multiplication)
   - Finite state automata (`automata.sg`)
   - Fixed-size data structure transformations

2. **Potentially non-terminating:**
   - Circular graph traversal
   - Recursive definitions without base cases
   - Self-referential constellations

3. **Complex but terminating:**
   - Lambda calculus reduction (`lambda.sg`)
   - Logic programming with backtracking (`prolog.sg`)

### 7.2 Metrics to Collect

For each test program:
- Number of interaction rounds
- Size metrics at each round (constructors, depth, star count)
- Size change trend (increasing/decreasing/stable)
- Whether bounds are exceeded
- Final termination status

### 7.3 Validation Methodology

1. **Manual verification**: Prove termination mathematically for each test
2. **Compare predictions**: Do heuristics correctly identify termination/non-termination?
3. **Tune bounds**: Find bounds that minimize false positives/negatives
4. **Performance**: Measure overhead of termination checking

## 8. Future Directions

### 8.1 Type-Based Termination

Integrate termination checking with Stellogen's type system:
- Types carry size information
- Type checking ensures decreasing sizes
- Similar to sized types in Agda or Coq

Example:
```stellogen
(spec nat-sized {
  [(-nat 0) (size 0)]
  [(-nat (s N)) (size (+ 1 (size N)))]})
```

### 8.2 User Annotations

Allow programmers to specify termination measures:

```stellogen
(:= add {
  @(decreases (size X))
  [(+add 0 Y Y)]
  [(-add X Y Z) (+add (s X) Y (s Z))]})
```

Compiler verifies annotation is correct.

### 8.3 Abstract Interpretation

Use abstract interpretation techniques:
- Abstract domain: size intervals, shapes
- Abstract execution: over-approximate possible sizes
- If abstract execution terminates with bounded size, concrete execution terminates

### 8.4 SMT-Based Verification

Encode termination conditions as SMT problems:
- Represent fusion operations symbolically
- Generate verification conditions for size decrease
- Use Z3 or similar solver to verify

### 8.5 Machine Learning Assistance

Train ML models to predict termination:
- Features: constellation structure, size metrics, interaction patterns
- Labels: known terminating/non-terminating programs
- Use predictions to guide bounds or prioritize analysis

## 9. Conclusion

Termination detection for Stellogen programs is challenging but tractable with the right combination of approaches:

**Short-term (practical):**
- Implement bounded execution monitoring with configurable limits
- Track and report size metrics during execution
- Provide warnings for potential non-termination

**Medium-term (analytical):**
- Implement size-change analysis for fusion operations
- Build dependency graphs for constellation interactions
- Develop heuristics based on term size decrease patterns

**Long-term (theoretical):**
- Integrate with type system for static guarantees
- Develop user annotation system for termination proofs
- Explore advanced techniques (abstract interpretation, SMT)

**Key insight:** Term size after fusion is a useful heuristic, but must be combined with other measures (star count, depth, execution bounds) and contextualized by Stellogen's unification-based semantics. No single measure is sufficient, but a multi-faceted approach can provide valuable feedback to users and catch many non-termination cases in practice.

The recommended first implementation is bounded execution monitoring with size tracking instrumentation, providing immediate practical value while laying groundwork for more sophisticated analysis.

## 10. References

- Arts, T., & Giesl, J. (2000). Termination of term rewriting using dependency pairs. *Theoretical Computer Science*, 236(1-2), 133-178.

- Dershowitz, N., & Manna, Z. (1979). Proving termination with multiset orderings. *Communications of the ACM*, 22(8), 465-476.

- Lafont, Y. (1990). Interaction nets. *Proceedings of the 17th ACM SIGPLAN-SIGACT symposium on Principles of programming languages*, 95-108.

- Lee, C. S., Jones, N. D., & Ben-Amram, A. M. (2001). The size-change principle for program termination. *ACM SIGPLAN Notices*, 36(3), 81-92.

- Plump, D. (1999). Termination of graph rewriting is undecidable. *Fundamenta Informaticae*, 33(2), 201-209.

- Thiemann, R., & Giesl, J. (2005). The size-change principle and dependency pairs for termination of term rewriting. *Applicable Algebra in Engineering, Communication and Computing*, 16(4), 229-270.

- Salvador Lucas. (2024). Termination of Generalized Term Rewriting Systems. *FSCD 2024*, LIPIcs Volume 299.

## Appendix A: Implementation Sketch

### A.1 Size Measurement Module

```ocaml
(* src/termination.ml *)
open Base
open Lsc_ast
open Lsc_ast.StellarRays

(* Term size measures *)
let rec term_constructor_count = function
  | Var _ -> 0
  | Func (_, args) ->
      1 + List.fold_left ~f:(fun acc t -> acc + term_constructor_count t) ~init:0 args

let rec term_depth = function
  | Var _ -> 0
  | Func (_, args) when List.is_empty args -> 1
  | Func (_, args) ->
      1 + List.fold_left ~f:(fun acc t -> max acc (term_depth t)) ~init:0 args

(* Star and constellation measures *)
type metrics = {
  star_count: int;
  total_constructors: int;
  max_depth: int;
  max_ray_count: int;
}

let measure_constellation (stars: Raw.constellation) =
  let star_count = List.length stars in
  let all_rays = List.concat_map ~f:(fun s -> s.Raw.content) stars in
  let ray_counts_per_star = List.map ~f:(fun s -> List.length s.Raw.content) stars in
  let constructor_counts = List.map ~f:term_constructor_count all_rays in
  let depths = List.map ~f:term_depth all_rays in
  {
    star_count;
    total_constructors = List.fold_left ~f:(+) ~init:0 constructor_counts;
    max_depth = List.fold_left ~f:max ~init:0 depths;
    max_ray_count = List.fold_left ~f:max ~init:0 ray_counts_per_star;
  }

(* Comparison *)
type size_change = Decreasing | NonIncreasing | Increasing | Stable

let compare_metrics m1 m2 =
  let decreases =
    m2.total_constructors < m1.total_constructors ||
    m2.max_depth < m1.max_depth ||
    m2.star_count < m1.star_count
  in
  let increases =
    m2.total_constructors > m1.total_constructors ||
    m2.max_depth > m1.max_depth ||
    m2.star_count > m1.star_count
  in
  if decreases && not increases then Decreasing
  else if not decreases && not increases then Stable
  else if increases && not decreases then Increasing
  else NonIncreasing

(* Bounds configuration *)
type bounds = {
  max_rounds: int;
  max_constellation_size: int;
  max_term_depth: int;
  warn_threshold: float; (* warn when approaching limit, e.g., 0.8 *)
}

let default_bounds = {
  max_rounds = 10000;
  max_constellation_size = 1000;
  max_term_depth = 100;
  warn_threshold = 0.8;
}

type termination_error =
  | ExceededMaxRounds of int
  | ExceededConstellationSize of int * int
  | ExceededTermDepth of int * int

let check_bounds bounds metrics round_count =
  if round_count > bounds.max_rounds then
    Some (ExceededMaxRounds round_count)
  else if metrics.star_count > bounds.max_constellation_size then
    Some (ExceededConstellationSize (metrics.star_count, bounds.max_constellation_size))
  else if metrics.max_depth > bounds.max_term_depth then
    Some (ExceededTermDepth (metrics.max_depth, bounds.max_term_depth))
  else
    None

let should_warn bounds metrics round_count =
  let threshold = bounds.warn_threshold in
  Float.of_int round_count > Float.of_int bounds.max_rounds *. threshold ||
  Float.of_int metrics.star_count > Float.of_int bounds.max_constellation_size *. threshold ||
  Float.of_int metrics.max_depth > Float.of_int bounds.max_term_depth *. threshold
```

### A.2 Instrumented Execution

```ocaml
(* Modified exec function with termination checking *)
let exec_with_termination_check
    ?(linear = false)
    ?(bounds = default_bounds)
    ?(instrument = false)
    mcs : (constellation, termination_error) Result.t =

  let rec loop round_count (actions, states) =
    (* Measure current state *)
    let metrics = measure_constellation states in

    (* Check bounds *)
    match check_bounds bounds metrics round_count with
    | Some err -> Error err
    | None ->
        (* Optional warning *)
        if instrument && should_warn bounds metrics round_count then
          Printf.eprintf "Warning: approaching termination bounds at round %d\n" round_count;

        (* Optional instrumentation output *)
        if instrument then
          Printf.eprintf "Round %d: stars=%d, constructors=%d, depth=%d\n"
            round_count metrics.star_count metrics.total_constructors metrics.max_depth;

        (* Continue normal execution *)
        match select_star ~linear ~queue:[] actions states with
        | None, _ ->
            if instrument then
              Printf.eprintf "Terminated successfully after %d rounds\n" round_count;
            Ok states
        | Some res, new_actions ->
            loop (round_count + 1) (new_actions, res)
  in

  let cfg = extract_intspace mcs in
  loop 0 cfg
```

### A.3 CLI Integration

```ocaml
(* In bin/sgen.ml *)
let run_with_options filename opts =
  let bounds = {
    max_rounds = Option.value opts.max_rounds ~default:10000;
    max_constellation_size = Option.value opts.max_size ~default:1000;
    max_term_depth = Option.value opts.max_depth ~default:100;
    warn_threshold = 0.8;
  } in

  let program = parse_file filename in
  match eval_program_with_bounds program bounds opts.instrument with
  | Ok env -> print_endline "Program executed successfully"
  | Error (TerminationError err) ->
      Printf.eprintf "Potential non-termination detected: %s\n"
        (string_of_termination_error err)
  | Error other_err -> handle_other_error other_err
```

This implementation provides a foundation for practical termination detection in Stellogen while remaining extensible for more sophisticated techniques in the future.
