# Import Mechanisms in Stellogen: Analysis and Improvements

> **Disclaimer**: This document was written with the assistance of Claude Code and represents exploratory research and analysis. The content may contain inaccuracies or misinterpretations and should not be taken as definitive statements about the Stellogen language implementation.

**Status:** Research Document
**Date:** 2025-10-11
**Purpose:** Analyze the current file import mechanism and propose improvements for importing macros, particularly for creating a "MilkyWay" standard library

---

## Table of Contents

1. [Current State](#current-state)
2. [The Macro Import Problem](#the-macro-import-problem)
3. [Design Considerations](#design-considerations)
4. [Proposed Solutions](#proposed-solutions)
5. [Recommendation](#recommendation)
6. [Implementation Roadmap](#implementation-roadmap)
7. [References](#references)

---

## Current State

### How Imports Work

Stellogen supports file imports through the `use` expression:

```stellogen
(use "examples/automata.sg")
```

**Implementation:** `src/sgen_eval.ml:256-274`

When a `use` declaration is evaluated:

1. **File reading**: The file is opened and lexed
2. **Parsing**: Expressions are parsed into an AST
3. **Preprocessing**: Macros are expanded (with empty macro environment!)
4. **Conversion**: Expressions are converted to declarations
5. **Evaluation**: Declarations are evaluated, building a new runtime environment
6. **Return**: The new environment is returned

```ocaml
| Use path -> (
  (* ... read file into lexbuf ... *)
  let expr = Sgen_parsing.parse_with_error filename lexbuf in
  let preprocessed = Expr.preprocess expr in
  match Expr.program_of_expr preprocessed with
  | Ok program ->
      let* new_env = eval_program program in
      Ok new_env
  | Error expr_err -> Error (ExprError (expr_err, None)) )
```

### The Preprocessing Pipeline

**Implementation:** `src/expr.ml:302`

```ocaml
let preprocess e = e |> List.map ~f:expand_macro |> unfold_decl_def []
                                                                      ^^
                                                      Empty macro environment!
```

The preprocessing phase consists of two steps:

1. **Syntactic expansion** (`expand_macro`): Desugars syntax like `[1|Tail]`, `<f a b>`, `"string"` into core forms
2. **Macro expansion** (`unfold_decl_def`): Processes `macro` forms and expands macro calls

### How Macros Work

**Implementation:** `src/expr.ml:105-138`

The `unfold_decl_def` function:

```ocaml
let unfold_decl_def (macro_env : (string * (string list * expr list)) list) exprs =
  let rec process_expr (env, acc) = function
    (* Macro definition *)
    | List (Symbol "macro" :: List (Symbol macro_name :: args) :: body) ->
      let var_args = List.map args ~f:(function | Var x -> x | _ -> failwith ...) in
      ((macro_name, (var_args, body)) :: env, acc)

    (* Macro call *)
    | List (Symbol macro_name :: call_args) as expr -> (
      match List.Assoc.find env macro_name ~equal:String.equal with
      | Some (formal_params, body) ->
          (* Expand macro by substituting arguments *)
          let expanded = List.map body ~f:apply_substitution |> List.rev in
          (env, expanded @ acc)
      | None -> (env, expr :: acc) )
    (* ... *)
  in
  List.fold_left exprs ~init:(macro_env, []) ~f:process_expr |> snd |> List.rev
```

**Key observations:**

- Macros are stored in a local environment during preprocessing: `(string * (string list * expr list)) list`
- When a macro is defined, it's added to this local environment
- When a macro is called, its body is expanded with arguments substituted
- After preprocessing completes, the macro environment is **discarded**
- Only the **expanded expressions** proceed to evaluation

### The Runtime Environment

**Implementation:** `src/sgen_ast.ml:36`

```ocaml
type env = { objs : (ident * sgen_expr) list }

let initial_env = { objs = [] }
```

The runtime environment stores **identifiers** (terms) mapped to **expressions** (constellations). It does NOT store macros.

---

## Import Mechanisms in Other Languages

### Overview

Before designing a solution for Stellogen, it's valuable to examine how other languages—particularly those where macros are central—handle imports. This section explores different approaches to module systems, with special attention to macro importation and the trade-offs between file path-based and module name-based imports.

---

### Macro-Centric Languages

#### Scheme and Racket

**Scheme** (particularly R6RS and R7RS) and **Racket** are pioneering languages where **macros are first-class citizens**. Their module systems are designed from the ground up to handle macro imports correctly.

##### R6RS Scheme Library System

**Syntax:**
```scheme
; Defining a library
(library (my-lib types)
  (export spec :: nat binary)  ; Export macros and definitions
  (import (rnrs))

  ; Define macros
  (define-syntax spec
    (syntax-rules ()
      [(spec name body)
       (define name body)]))

  (define-syntax ::
    (syntax-rules ()
      [(:: value type)
       (check-type value type)]))

  ; Define values
  (define nat ...)
  (define binary ...))
```

**Importing the library:**
```scheme
(import (my-lib types))

; Macros are available immediately
(spec point (lambda (x y) (list x y)))
(:: my-value nat)
```

**Key features:**

1. **Phase separation**: Macros exist at **compile-time** (expansion phase), while regular definitions exist at **runtime**
2. **Automatic phase handling**: The module system tracks which phase bindings belong to
3. **Explicit exports**: Libraries declare what they export (macros and values)
4. **Hygiene**: Macros are hygienic by default, preventing variable capture

**How it works:**

```
Import Resolution Pipeline:
1. Parse: (import (my-lib types))
2. Locate: Find library file via search path
3. Load: Read and parse the library
4. Expand: Expand macros in the library itself
5. Separate phases:
   - Compile-time bindings → expansion environment
   - Runtime bindings → runtime environment
6. Export: Make declared exports available
7. Import: Bind exports into importing module
```

The crucial insight: **Macros are preserved across module boundaries** because the module system distinguishes between compile-time and runtime bindings.

##### Racket Module System

**Racket** extends Scheme with an even more sophisticated module system.

**Syntax:**
```racket
; my-types.rkt
#lang racket

(provide spec ::)  ; Export macros

(define-syntax spec
  (syntax-rules ()
    [(spec name body)
     (define name body)]))

(define-syntax ::
  (syntax-rules ()
    [(:: value type)
     (check-type value type)]))
```

**Importing:**
```racket
#lang racket

(require "my-types.rkt")  ; File path import
; OR
(require my-lib/types)    ; Module name import

(spec nat ...)
(:: value nat)
```

**Advanced features:**

1. **Phase levels**: Racket supports multiple phase levels (phase 0 = runtime, phase 1 = compile-time, phase 2 = compile-compile-time, etc.)

```racket
(require (for-syntax racket/base))  ; Import for phase 1
(require (for-meta 2 racket/base))  ; Import for phase 2
```

2. **Submodules**: Modules can contain other modules

```racket
(module* test racket
  (require rackunit)
  (check-equal? (add 1 2) 3))
```

3. **Renaming and prefixing**:

```racket
(require (rename-in "my-types.rkt" [spec type-spec]))
(require (prefix-in types: "my-types.rkt"))
; Now use: types:spec
```

4. **Contracts**: Can attach contracts to exports

```racket
(provide (contract-out
  [add (-> number? number? number?)]))
```

**Why Racket's approach works for macros:**

- **Separate compilation**: Each module is compiled independently, but macro definitions are preserved in compiled form
- **Phase distinction**: The system knows which bindings are needed at which phase
- **Explicit requires**: Users explicitly import what they need at each phase

##### Common Lisp Package System

**Common Lisp** uses a **package system** rather than modules, but it handles macros effectively.

**Syntax:**
```lisp
; Define a package
(defpackage :my-types
  (:use :common-lisp)
  (:export :spec ::: :nat :binary))

(in-package :my-types)

; Define macros
(defmacro spec (name body)
  `(defparameter ,name ,body))

(defmacro :: (value type)
  `(check-type ,value ,type))

; Define values
(defparameter nat ...)
```

**Importing:**
```lisp
; Use the package
(use-package :my-types)

; Or import specific symbols
(import '(my-types:spec my-types:::))

; Or use qualified names
(my-types:spec nat ...)
```

**Key features:**

1. **Symbol-based**: Packages control symbol visibility
2. **No phase separation**: Macros and functions are both just symbols in the package
3. **Dynamic**: Packages can be modified at runtime
4. **Namespace management**: Prevents name conflicts

**Why it works for macros:**

- **Macros are expanded before compilation**: The compiler sees macro definitions in the package
- **Symbols are first-class**: Importing a symbol imports whatever it's bound to (macro, function, variable)
- **Separate compilation tracks dependencies**: ASDF (Common Lisp's build system) ensures macros are loaded before code that uses them

##### OCaml's PPX System (Preprocessor Extension Points)

While not a "macro-centric" language in the Lisp sense, **OCaml**'s PPX system provides compile-time code transformation.

**Syntax:**
```ocaml
(* deriving.ml - A PPX rewriter *)
let expand_deriving = ...

let () =
  Ppxlib.Driver.register_transformation
    ~extensions:[deriving_extension]
    "deriving"
```

**Usage:**
```ocaml
(* my_program.ml *)
type point = {x: int; y: int} [@@deriving show, eq]

(* The PPX rewriter generates:
   - show_point : point -> string
   - equal_point : point -> point -> bool
*)
```

**Import model:**

- PPX rewriters are **separate programs** invoked during compilation
- Specified in build configuration (dune files), not in source code
- No import statement needed—transformations are applied automatically if registered

**Why it works:**

- **Explicit compilation pipeline**: Build system ensures PPX runs before type checking
- **Separate programs**: No need to track macro environments—just transform ASTs

---

### File Path vs Module Name Imports

Programming languages generally use one of two approaches for specifying imports:

1. **File path imports**: Direct reference to a file location
2. **Module name imports**: Abstract reference to a module, resolved via search paths

#### File Path Imports

**Definition:** Import statements directly specify the **file system path** to the module.

**Examples:**

```c
// C
#include "my-lib/utils.h"      // Relative path
#include "/usr/local/lib/utils.h"  // Absolute path
```

```javascript
// JavaScript (CommonJS/ES modules)
const utils = require('./my-lib/utils.js');
import { helper } from '../utils/helper.js';
```

```python
# Python (relative imports)
from .my_lib import utils
from ..parent_module import helper
```

```stellogen
; Stellogen (current)
(use "examples/nat.sg")
(use "lib/prelude.sg")
```

**Characteristics:**

| Aspect | Description |
|--------|-------------|
| **Explicitness** | Clear exactly which file is being imported |
| **Simplicity** | No complex resolution logic needed |
| **Refactoring** | Moving files requires updating all import paths |
| **Portability** | Paths may be platform-specific (`/` vs `\`) |
| **Versioning** | Difficult to support multiple versions of same library |
| **Discoverability** | Hard to know what's available without filesystem exploration |

**Advantages:**

1. **No ambiguity**: The imported file is explicitly specified
2. **No configuration**: No need for search paths or configuration files
3. **Simple implementation**: Just read the file at the specified path
4. **Local reasoning**: Easy to see dependencies by looking at file paths
5. **No global namespace**: No risk of name collisions in module space

**Disadvantages:**

1. **Brittle to reorganization**: Moving files breaks imports
2. **Verbose**: Long relative paths can be unwieldy (`../../../lib/utils`)
3. **Platform-specific**: Path separators differ (Windows vs Unix)
4. **No abstraction**: Can't easily swap implementations
5. **Duplication**: Same library in multiple locations = duplicate imports

**Use cases:**

- Small projects with stable structure
- Build-time transformations (C includes, Stellogen `use`)
- When you want explicit control over which file is loaded

---

#### Module Name Imports

**Definition:** Import statements specify an **abstract module name**, which is resolved to a file path via a **resolution algorithm**.

**Examples:**

```python
# Python
import numpy
from django.http import HttpResponse
```

```javascript
// JavaScript (Node.js)
const express = require('express');
import React from 'react';
```

```racket
; Racket
(require racket/base)
(require data/queue)
```

```java
// Java
import java.util.List;
import com.mycompany.myapp.Utils;
```

**Characteristics:**

| Aspect | Description |
|--------|-------------|
| **Abstraction** | Module names are independent of file locations |
| **Flexibility** | Files can move without breaking imports |
| **Configuration** | Requires search paths or package registries |
| **Versioning** | Can support multiple versions via resolution |
| **Discoverability** | Package managers can list available modules |
| **Complexity** | Resolution algorithm can be complex |

**Advantages:**

1. **Refactoring-friendly**: Moving files doesn't break imports (if module names stay the same)
2. **Concise**: Short, readable names (`numpy` not `../../venv/lib/python3.9/site-packages/numpy/__init__.py`)
3. **Abstraction**: Module names are logical, not tied to filesystem layout
4. **Versioning**: Can specify version requirements (`require "mylib" >= 2.0`)
5. **Centralized configuration**: Search paths configured once, used everywhere

**Disadvantages:**

1. **Indirection**: Not immediately clear where a module lives
2. **Configuration complexity**: Requires setting up search paths, package managers, etc.
3. **Name conflicts**: Two packages can have the same module name
4. **Debugging difficulty**: Resolution failures can be hard to diagnose
5. **Implementation complexity**: Resolver must search multiple locations

**Use cases:**

- Large projects with deep directory structures
- Projects using third-party libraries (installed via package managers)
- When you want to decouple code structure from filesystem layout
- Production languages with ecosystem support

---

### Import Resolution Mechanisms

When using **module name imports**, the language runtime or compiler must **resolve** the abstract module name to a concrete file path. This is called **import resolution** or **module resolution**.

#### Basic Resolution Algorithm

**Pseudocode:**

```
function resolve_module(module_name, current_file, search_paths):
  1. Check if module_name is a built-in module
     → If yes, return built-in module

  2. Check if module_name is relative (starts with ./ or ../)
     → If yes, resolve relative to current_file's directory

  3. For each path in search_paths:
     candidate = path / module_name
     if exists(candidate):
       return candidate

  4. Check package cache (if using package manager)
     → If found, return cached location

  5. Error: Module not found
```

#### Python's Import Resolution

**Resolution order:**

1. **sys.modules**: Check if already imported (cache)
2. **Built-in modules**: Check `sys.builtin_module_names`
3. **sys.path**: Search directories in order:
   - Current directory (or script's directory)
   - `PYTHONPATH` environment variable directories
   - Installation-dependent default paths (e.g., `/usr/lib/python3.9/site-packages`)

**Example:**

```python
import numpy

# Resolution:
# 1. Check sys.modules['numpy'] → Not found (first import)
# 2. Not a built-in module
# 3. Search sys.path:
#    - ./numpy → Not found
#    - /usr/lib/python3.9/site-packages/numpy → Found!
# 4. Load /usr/lib/python3.9/site-packages/numpy/__init__.py
```

**Package imports:**

```python
from my_package.submodule import function

# Resolution:
# 1. Find my_package (using sys.path)
# 2. Look for my_package/__init__.py
# 3. Look for my_package/submodule.py or my_package/submodule/__init__.py
# 4. Extract 'function' from that module
```

#### Node.js/JavaScript Module Resolution

**Algorithm** (for `require('module_name')`):

1. **Core modules**: If `module_name` is a core module (e.g., `fs`, `http`), return it
2. **Relative/absolute path**: If starts with `/`, `./`, or `../`, treat as file path
3. **node_modules resolution**:
   - Start from current directory
   - Look in `./node_modules/module_name`
   - If not found, go to parent directory and look in `../node_modules/module_name`
   - Repeat until reaching filesystem root
4. **File extensions**: Try appending `.js`, `.json`, `.node`
5. **Directory imports**: If module_name is a directory, look for:
   - `package.json` with `"main"` field
   - `index.js`

**Example:**

```javascript
// In /home/user/project/src/app.js
const express = require('express');

// Resolution:
// 1. Not a core module
// 2. Not a path (doesn't start with /, ./, ../)
// 3. Search node_modules:
//    - /home/user/project/src/node_modules/express → Not found
//    - /home/user/project/node_modules/express → Found!
// 4. Read /home/user/project/node_modules/express/package.json
//    → "main": "lib/express.js"
// 5. Load /home/user/project/node_modules/express/lib/express.js
```

#### Racket's Module Resolution

**Syntax:**

```racket
(require module-path)
```

**Module path forms:**

1. **Relative paths**: `"file.rkt"`, `"../lib/utils.rkt"`
2. **Collection-based**: `racket/base`, `data/queue`
   - Collections are searched in Racket's installation directory and user-specific directories
3. **Planet packages** (legacy): `(planet user/package:version)`
4. **Package catalog**: Packages installed via `raco pkg install`

**Resolution algorithm:**

```
1. If module-path is a string (file path):
   - Relative to current file
   - Return that file

2. If module-path is a symbol or identifier (e.g., racket/base):
   - Split by / to get collection and module
   - Search collection paths:
     a. Racket installation directory
     b. User-specific directory (~/.racket)
     c. Current directory
   - Find <collection>/<module>.rkt

3. If module-path is a (planet ...) form:
   - Download package from PLaneT server
   - Install to local cache
   - Return cached location

4. If not found:
   - Error: module not found
```

**Example:**

```racket
(require racket/list)

; Resolution:
; 1. Not a file path (no quotes)
; 2. Collection-based path: collection = "racket", module = "list"
; 3. Search collection paths:
;    - /usr/local/racket/collects/racket/list.rkt → Found!
; 4. Load and compile
```

#### Java's Classpath Resolution

**Syntax:**

```java
import com.mycompany.myapp.Utils;
```

**Resolution:**

1. **Convert package name to path**: `com.mycompany.myapp.Utils` → `com/mycompany/myapp/Utils.class`
2. **Search classpath** (list of directories and JAR files):
   - For each classpath entry:
     - If directory: Look for `entry/com/mycompany/myapp/Utils.class`
     - If JAR file: Look inside JAR for `com/mycompany/myapp/Utils.class`
3. **Return first match**

**Classpath configuration:**

```bash
# Command line
java -classpath /path/to/classes:/path/to/lib.jar MyApp

# Environment variable
export CLASSPATH=/path/to/classes:/path/to/lib.jar
```

#### OCaml/Dune Resolution

**OCaml** with **Dune** build system:

**Syntax:**

```ocaml
(* In a dune file *)
(library
 (name my_lib)
 (libraries base stdio))
```

**Resolution:**

1. **Library names**: Specified in `dune` files
2. **Search scope**:
   - Current workspace (all libraries defined in dune files)
   - Installed libraries (via `opam`, OCaml's package manager)
3. **Compilation order**: Dune computes dependency graph and compiles in order

**No import statements in source**: Dependencies declared in build files, not source files.

---

### Comparison Summary

#### Resolution Complexity

| Language | Resolution Complexity | Configuration |
|----------|----------------------|---------------|
| **C/C++** | Low (file paths + include paths) | Compiler flags (`-I`) |
| **JavaScript (Node.js)** | Medium (node_modules traversal) | package.json + node_modules |
| **Python** | Medium (sys.path search) | PYTHONPATH + pip |
| **Racket** | Medium-High (collections + packages) | raco pkg + config |
| **Java** | Medium (classpath search) | CLASSPATH or build tool (Maven, Gradle) |
| **OCaml/Dune** | Medium (workspace + opam) | dune files + opam |

#### Trade-offs

| Approach | Best For | Avoid When |
|----------|----------|------------|
| **File paths** | Small projects, scripts, build-time preprocessing | Large projects, external dependencies |
| **Module names + simple resolution** | Medium projects, standard libraries | Complex dependency management |
| **Module names + package manager** | Large projects, ecosystem libraries | Maximum simplicity needed |

---

### Implications for Stellogen

Given Stellogen's philosophy and current state:

#### Current Approach

- **File path imports**: `(use "examples/nat.sg")`
- **Minimal**: No resolution logic, no configuration
- **Aligned with minimalism**: Simple to implement and understand

#### Challenges

- **Macro import problem**: Macros are discarded after preprocessing
- **Code duplication**: Same macros repeated across files
- **No standard library**: Can't easily share common utilities

#### Design Considerations

1. **Stay minimal**: Avoid complex resolution if possible
2. **File paths are fine**: Stellogen is a research language, not a production ecosystem
3. **Focus on macro problem**: The real issue is preserving macros across imports, not resolution
4. **Optional convenience**: Could add simple module name support later if needed

#### Potential Hybrid Approach

**Basic (Phase 1):**
- Keep file path imports: `(import-macros "lib/prelude.sg")`
- Add optional prelude flag: `sgen run --prelude lib/prelude.sg my_program.sg`

**Advanced (Phase 2, optional):**
- Add simple module name resolution:
  ```stellogen
  (import-macros prelude)  ; Resolves to lib/prelude.sg via search path
  ```
- Configure search paths via environment variable or config file:
  ```bash
  export STELLOGEN_PATH=./lib:./vendor:/usr/local/lib/stellogen
  ```

**Resolution algorithm (if implemented):**

```ocaml
let resolve_module module_name current_file =
  (* 1. Check if it's a file path (contains / or .) *)
  if String.contains module_name '/' || String.contains module_name '.' then
    resolve_file_path module_name current_file
  else
    (* 2. Search STELLOGEN_PATH *)
    let search_paths = get_search_paths () in
    let candidates = List.map search_paths ~f:(fun path ->
      path ^ "/" ^ module_name ^ ".sg") in
    List.find candidates ~f:Sys.file_exists
```

**Benefit:** Keeps simplicity while allowing future extensibility.

---

### Key Insights from Other Languages

1. **Phase separation is crucial**: Scheme/Racket succeed because they distinguish compile-time (macros) from runtime (values)

2. **Macros must be preserved**: Unlike runtime definitions, macros need to be available during preprocessing of importing files

3. **File paths are fine for small languages**: Not every language needs a complex module system—C's `#include` worked for decades

4. **Separate preprocessing from evaluation**: Stellogen's current architecture is sound; it just needs to thread macro environments through imports

5. **Don't over-engineer**: Stellogen is a research language, not a production system—simple solutions are better

---

## The Macro Import Problem

### The Duplication Issue

The same macro definitions appear at the beginning of **12+ example files**:

```stellogen
(macro (spec X Y) (:= X Y))
(macro (:: Tested Test)
  (== @(interact @#Tested #Test) ok))
```

**Files with duplicated macros:**
- `examples/nat.sg`
- `examples/smll.sg`
- `examples/sumtypes.sg`
- `examples/npda.sg`
- `examples/mll.sg`
- `examples/syntax.sg`
- `examples/automata.sg`
- `examples/binary4.sg`
- `examples/linear_lambda.sg`
- And more...

### Why Imports Don't Work for Macros

The problem occurs because of the **separation between preprocessing and evaluation**:

```
File A:                          File B (imports A):
┌─────────────────┐              ┌─────────────────┐
│ Define macros   │              │ (use "a.sg")    │
│ Use macros      │              │ Try to use A's  │
│                 │              │ macros...       │
└────────┬────────┘              └────────┬────────┘
         │                                │
         ▼                                ▼
    Preprocessing                   Preprocessing
    (macro_env = [])                (macro_env = [])
         │                                │
    - Collect macros                 - Parse use declaration
    - Expand macros                  - No macros available!
    - Discard macro_env              - Can't expand A's macros
         │                                │
         ▼                                ▼
    Evaluation                       Evaluation
    (env contains defs)              - Load A, get A's defs
         │                           - But A's macros were
         │                             discarded during A's
         │                             preprocessing!
         ▼                                │
    Return env                           ▼
    (no macros!)                    Error or duplication
```

**Root cause:** Each file is preprocessed independently with an empty macro environment, and macro definitions are not preserved in the runtime environment.

### Concrete Example

Suppose we want to create `lib/prelude.sg`:

```stellogen
' lib/prelude.sg - Common macros
(macro (spec X Y) (:= X Y))
(macro (:: Tested Test)
  (== @(interact @#Tested #Test) ok))
```

And use it in `my_program.sg`:

```stellogen
' my_program.sg
(use "lib/prelude.sg")

' Try to use the macros
(spec nat {
  [(-nat 0) ok]
  [(-nat (s N)) (+nat N)]})

(:: 0 nat)  ' This won't work!
```

**What happens:**

1. `lib/prelude.sg` is preprocessed, macros are defined and then discarded
2. `lib/prelude.sg` is evaluated, runtime definitions are stored (but there are none in this case)
3. `my_program.sg` tries to use `spec` and `::` macros
4. **Error:** These macros are not available in `my_program.sg`'s preprocessing phase

---

## Design Considerations

When designing a solution, we must align with Stellogen's core philosophy:

### 1. Minimalism

Stellogen is intentionally minimal. From the README:

> It offers elementary interactive building blocks where both computation and meaning live in the same language.

**Implication:** Avoid adding complex module systems, namespaces, or heavyweight import mechanisms. Keep it simple.

### 2. Logic-Agnostic Nature

> The semantic power (and the responsibility that comes with it) belongs entirely to the user.

**Implication:** Don't impose a rigid module structure. Allow flexibility in how code is organized and reused.

### 3. Metaprogramming Spirit

Influenced by Scheme/Racket's metaprogramming:

> from **Scheme/Racket** for the spirit of metaprogramming

**Implication:** Macros should be first-class citizens or close to it. Their import mechanism should feel natural to the language.

### 4. Practical Needs

The language is evolving, and real programs need to reuse code:

> This project is still in development, hence the syntax and features are still changing frequently.

**Implication:** A solution should be practical and solve the immediate need (MilkyWay standard library) without over-engineering.

### 5. Clean Separation of Concerns

The current architecture has a clean separation between:
- **Preprocessing:** Syntactic transformations (macros, desugaring)
- **Evaluation:** Semantic operations (interaction, unification)

**Implication:** Preserve this separation if possible. Mixing them could complicate the implementation.

---

## Proposed Solutions

### Solution 1: Thread Macro Environment Through Imports

**Idea:** Modify the import mechanism to collect and propagate macro environments.

**Changes needed:**

1. Modify `preprocess` to return both expanded expressions AND macro environment:
   ```ocaml
   let preprocess e : expr list * macro_env =
     let expanded = List.map ~f:expand_macro e in
     let macro_env, result = unfold_decl_def [] expanded in
     (result, macro_env)
   ```

2. Thread macro environment through `eval_program`:
   ```ocaml
   type env = {
     objs : (ident * sgen_expr) list;
     macros : (string * (string list * expr list)) list
   }
   ```

3. When processing `Use` declarations, merge macro environments

4. Modify file processing to use inherited macro environment during preprocessing

**Pros:**
- Clean separation: macros remain preprocessing-time constructs
- Imported macros are available in importing files
- Explicit propagation of macro definitions

**Cons:**
- Significant refactoring required across multiple modules
- Macro environment must be threaded through the entire evaluation pipeline
- Complicates the current clean separation

**Complexity:** High

---

### Solution 2: Make Macros Runtime Constructs

**Idea:** Store macros in the runtime environment and apply expansion during evaluation, not preprocessing.

**Changes needed:**

1. Add a new declaration type:
   ```ocaml
   type declaration =
     | Def of ident * sgen_expr
     | MacroDef of string * string list * expr list
     | (* ... existing ... *)
   ```

2. Store macros in runtime environment:
   ```ocaml
   type env = {
     objs : (ident * sgen_expr) list;
     macros : (string * (string list * expr list)) list
   }
   ```

3. Apply macro expansion during evaluation or as a separate pass

**Pros:**
- Natural integration with import system
- Macros become first-class like definitions
- Imported files export their macros automatically

**Cons:**
- Fundamentally changes the compilation model
- Macros are no longer purely compile-time
- Potential performance implications (repeated expansion)
- Blurs the clean preprocessing/evaluation separation

**Complexity:** High

**Philosophical concern:** Mixing compile-time and runtime concerns may go against the clean separation principle.

---

### Solution 3: Two-Phase Import (Separate Macro Imports)

**Idea:** Introduce a separate `use-macros` declaration for importing macros.

**Syntax:**

```stellogen
' Import macros only
(use-macros "lib/prelude.sg")

' Import runtime definitions only
(use "lib/nat.sg")

' Or import both
(use-macros "lib/prelude.sg")
(use "lib/prelude.sg")
```

**Changes needed:**

1. Add `UseMacros` declaration type:
   ```ocaml
   type declaration =
     | (* ... existing ... *)
     | UseMacros of ident
   ```

2. Modify preprocessing to handle `UseMacros` specially:
   - Before `unfold_decl_def`, scan for `UseMacros` declarations
   - Load those files and extract their macro definitions
   - Build initial macro environment
   - Then proceed with `unfold_decl_def` using this environment

3. Keep `Use` for runtime definitions only

**Pros:**
- Explicit and clear: users know what they're importing
- Backward compatible: existing `use` still works
- Minimal runtime impact: macros remain preprocessing-time
- Simple to understand and implement

**Cons:**
- Two different import mechanisms (cognitive overhead)
- Requires duplication if you want both macros and definitions
- Still requires threading macro environment to some degree

**Complexity:** Medium

**Example:**

```stellogen
' lib/prelude.sg
(macro (spec X Y) (:= X Y))
(macro (:: Tested Test)
  (== @(interact @#Tested #Test) ok))

' my_program.sg
(use-macros "lib/prelude.sg")

(spec nat {
  [(-nat 0) ok]
  [(-nat (s N)) (+nat N)]})

(:: 0 nat)  ' Works!
```

---

### Solution 4: Preprocessing Directive for Macro Imports

**Idea:** Add a special preprocessing directive that loads macros before the main preprocessing pass.

**Syntax:**

```stellogen
(import-macros "lib/prelude.sg")

' Rest of the file...
```

**Changes needed:**

1. Parse files in two phases:
   - **Phase 1:** Scan for `import-macros` directives
   - Load imported files and extract macro definitions
   - Build initial macro environment
   - **Phase 2:** Preprocess with this macro environment

2. `import-macros` is NOT a regular declaration—it's a preprocessing directive

3. Keep the rest of the pipeline unchanged

**Pros:**
- Clean separation: preprocessing is still distinct from evaluation
- Minimal changes to evaluation pipeline
- Natural fit with the existing architecture
- Only affects preprocessing, not runtime

**Cons:**
- Introduces a new concept (preprocessing directives vs declarations)
- Requires two-pass parsing
- Need to handle cycles (A imports B, B imports A)

**Complexity:** Medium

**Example:**

```stellogen
' lib/prelude.sg
(macro (spec X Y) (:= X Y))
(macro (:: Tested Test)
  (== @(interact @#Tested #Test) ok))

' my_program.sg
(import-macros "lib/prelude.sg")

(spec nat {
  [(-nat 0) ok]
  [(-nat (s N)) (+nat N)]})

(:: 0 nat)  ' Works!
```

---

### Solution 5: Standard Prelude File

**Idea:** Provide a special file (e.g., `lib/prelude.sg`) that's automatically loaded before every program, or allow a command-line flag to specify a prelude.

**Syntax:**

```bash
# Automatically load prelude
sgen run --prelude lib/prelude.sg my_program.sg

# Or configure a default prelude
sgen config set prelude lib/prelude.sg
```

**Changes needed:**

1. Add CLI option for prelude file
2. Before preprocessing any file, load and process the prelude:
   - Extract macro definitions
   - Build initial macro environment
   - Use this environment for all subsequent preprocessing

3. Optionally, support a `.stellogenrc` config file

**Pros:**
- Simple for the common case: one standard library
- No language changes required
- Easy to implement
- Users can choose their prelude or none

**Cons:**
- Doesn't solve the general import problem
- Less flexible: single global prelude
- Implicit behavior (magic prelude) may be confusing
- Doesn't support multiple libraries well

**Complexity:** Low

**Example usage:**

```bash
# Create prelude
echo '(macro (spec X Y) (:= X Y))' > prelude.sg
echo '(macro (:: Tested Test) (== @(interact @#Tested #Test) ok))' >> prelude.sg

# Use it
sgen run --prelude prelude.sg my_program.sg
```

---

## Recommendation

### Recommended Approach: Solution 4 (Preprocessing Directive) + Solution 5 (Optional Prelude)

**Rationale:**

1. **Aligns with Stellogen's philosophy:**
   - Minimal language changes
   - Preserves clean preprocessing/evaluation separation
   - Keeps macros as compile-time constructs
   - Flexible and user-driven

2. **Solves the immediate need:**
   - Enables creating a "MilkyWay" standard library
   - Allows importing specific macro libraries
   - No code duplication

3. **Practical implementation:**
   - Medium complexity (manageable)
   - Doesn't require major refactoring
   - Can be added incrementally

4. **User experience:**
   - Clear and explicit: `(import-macros "file.sg")`
   - Optional convenience: `--prelude` flag for common cases
   - Flexible: users can organize libraries as needed

### Combined Approach

**For general use:**

```stellogen
' my_program.sg
(import-macros "lib/types.sg")
(import-macros "lib/lists.sg")

' Now use macros from both libraries
(spec nat {...})
(:: value nat)
```

**For the common case (MilkyWay standard library):**

```bash
# Set up MilkyWay as default prelude
sgen run --prelude lib/milkyway.sg my_program.sg

# Or configure it once
sgen config set prelude lib/milkyway.sg
```

```stellogen
' my_program.sg
' MilkyWay macros are automatically available!

(spec nat {...})
(:: value nat)
```

### Why Not the Other Solutions?

- **Solution 1 (Thread macro env):** Too much refactoring, complicates the architecture
- **Solution 2 (Runtime macros):** Fundamentally changes the compilation model, blurs concerns
- **Solution 3 (Two-phase import):** Redundant with Solution 4, requires both `use-macros` and `use` for full imports

---

## Implementation Roadmap

### Phase 1: Core Macro Import (Solution 4)

**Goal:** Enable `(import-macros "file.sg")` directive

**Steps:**

1. **Add preprocessing directive parsing**
   - Modify parser to recognize `import-macros` as a special form
   - Distinguish it from regular declarations

2. **Implement two-phase preprocessing**
   ```ocaml
   (* Phase 1: Collect imported macros *)
   let rec collect_macro_imports expr_list : string list = ...
   let load_macro_file filename : (string * (string list * expr list)) list = ...

   (* Phase 2: Preprocess with macro environment *)
   let preprocess_with_imports e : expr list =
     let import_files = collect_macro_imports e in
     let macro_env = List.concat_map import_files ~f:load_macro_file in
     e |> List.map ~f:expand_macro |> unfold_decl_def macro_env
   ```

3. **Handle cycles and errors**
   - Detect circular imports
   - Provide clear error messages for missing files
   - Handle macro name conflicts (later import wins? error? warning?)

4. **Update `preprocess` function**
   ```ocaml
   (* Old *)
   let preprocess e = e |> List.map ~f:expand_macro |> unfold_decl_def []

   (* New *)
   let preprocess e = preprocess_with_imports e
   ```

5. **Test with examples**
   - Create `lib/prelude.sg` with common macros
   - Update example files to use `import-macros`
   - Verify no regressions

**Files to modify:**
- `src/expr.ml` - Add `preprocess_with_imports`, `collect_macro_imports`
- `src/sgen_parsing.ml` - Recognize `import-macros` (or handle as special case)

**Estimated effort:** 2-3 days

---

### Phase 2: Optional Prelude (Solution 5)

**Goal:** Support `--prelude` flag for automatic macro loading

**Steps:**

1. **Add CLI flag**
   ```ocaml
   (* bin/sgen.ml *)
   let prelude_flag =
     Arg.(value & opt (some string) None & info ["prelude"]
          ~doc:"Prelude file to load before processing")
   ```

2. **Load prelude macros before main file**
   ```ocaml
   let run_with_prelude prelude_file input_file =
     let macro_env =
       match prelude_file with
       | None -> []
       | Some file -> load_macro_file file
     in
     (* Process input_file with macro_env *)
   ```

3. **Optional: Config file support**
   - Create `.stellogenrc` format
   - Load config on startup
   - Allow setting default prelude

4. **Create MilkyWay standard library**
   - `lib/milkyway.sg` with common macros
   - Document available macros
   - Add examples

**Files to modify:**
- `bin/sgen.ml` - Add CLI flag and config loading
- Create `lib/milkyway.sg`
- Update documentation

**Estimated effort:** 1-2 days

---

### Phase 3: MilkyWay Standard Library

**Goal:** Create a comprehensive standard library

**Contents:**

```stellogen
' lib/milkyway.sg - Stellogen Standard Library

''' Type system macros '''
(macro (spec X Y) (:= X Y))
(macro (:: Tested Test)
  (== @(interact @#Tested #Test) ok))
(macro (::lin Tested Test)
  (== @(fire @#Tested #Test) ok))

''' Common type definitions '''
(spec nat {...})
(spec binary {...})
(spec list {...})

''' Utility macros '''
(macro (alias X Y) (:= X Y))
(macro (type X Y) (spec X Y))

''' Testing macros '''
(macro (test Name Body)
  (== Body ok Name))

''' Documentation helpers '''
(macro (doc _ Body) Body)
```

**Organization:**

```
lib/
├── milkyway.sg         # Main standard library (imports all)
├── types.sg            # Type system macros
├── data.sg             # Data structure definitions
├── logic.sg            # Logic programming utilities
├── testing.sg          # Testing framework
└── docs/
    └── milkyway.md     # Documentation
```

**Estimated effort:** 3-5 days for initial version

---

### Total Timeline

- **Phase 1:** 2-3 days (core functionality)
- **Phase 2:** 1-2 days (convenience features)
- **Phase 3:** 3-5 days (standard library)

**Total:** ~1-2 weeks for complete implementation

---

## References

### Source Files

- `src/expr.ml` - Expression representation and macro expansion
  - Lines 71-96: `expand_macro` (syntactic sugar expansion)
  - Lines 98-103: `replace_id` (variable substitution)
  - Lines 105-138: `unfold_decl_def` (macro definition and expansion)
  - Line 302: `preprocess` (preprocessing pipeline)

- `src/sgen_eval.ml` - Expression evaluation and import handling
  - Lines 12-27: `find_with_solution` (identifier lookup with unification)
  - Lines 173-223: `eval_sgen_expr` (expression evaluation)
  - Lines 232-274: `eval_decl` (declaration evaluation)
  - Lines 256-274: `Use` declaration handler (file import)

- `src/sgen_ast.ml` - AST definitions
  - Lines 17-24: `sgen_expr` type
  - Line 36: `env` type (runtime environment)
  - Lines 40-45: `declaration` type

- `bin/sgen.ml` - CLI entry point

### Example Files with Macro Duplication

- `examples/nat.sg`
- `examples/automata.sg`
- `examples/smll.sg`
- `examples/mll.sg`
- `examples/sumtypes.sg`
- `examples/npda.sg`
- `examples/binary4.sg`
- `examples/linear_lambda.sg`
- `examples/syntax.sg`

### Related Documentation

- `README.md` - Project philosophy and overview
- `CLAUDE.md` - Project guide
- `docs/basics.md` - Language fundamentals

---

## Open Questions

1. **Macro name conflicts:** What happens if two imported files define the same macro?
   - Option A: Error (safe but restrictive)
   - Option B: Later import wins (flexible but potentially confusing)
   - Option C: Warning + later import wins (balanced)

2. **Import paths:** Should we support relative vs. absolute paths?
   - Current `use` supports both: `"examples/file.sg"` and potentially `"file"`
   - Should `import-macros` follow the same convention?

3. **Visibility:** Should imported macros be re-exported?
   - If A imports B's macros, and C imports A, should C see B's macros?
   - Current recommendation: No (explicit is better)

4. **Performance:** Should we cache parsed macro files?
   - Multiple files might import the same macro library
   - Caching could avoid repeated parsing
   - Premature optimization?

5. **Syntax:** Should `import-macros` use a different syntax?
   - Current: `(import-macros "file.sg")`
   - Alternative: `(use-macros "file.sg")`
   - Alternative: `(require "file.sg" :macros)`

---

## Conclusion

The current import mechanism in Stellogen successfully handles runtime definitions but lacks support for importing macros. This creates code duplication across example files and prevents the creation of a reusable standard library.

The recommended solution—combining preprocessing directives for explicit macro imports with an optional prelude system—addresses this limitation while maintaining Stellogen's minimalist philosophy and clean architectural separation.

This approach enables the creation of a "MilkyWay" standard library, reduces code duplication, and provides a foundation for better code organization as Stellogen continues to evolve.

**Next steps:** Implement Phase 1 (core macro import functionality), then gather user feedback before proceeding with Phase 2 and Phase 3.
