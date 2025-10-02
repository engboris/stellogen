# Stellogen Tests

This directory contains Cram tests for Stellogen.

## Test Files

- `subjects.t` - Tests for basic syntax subjects in `test/subjects/`
- `examples.t` - Tests for all examples in `examples/`

## Running Tests

Run all tests:
```bash
dune test
```

Run tests and update expected outputs:
```bash
dune test --auto-promote
```

Run specific test file:
```bash
dune test test/examples.t
```

## About Cram Tests

Cram tests are simple text-based tests that show shell commands and their expected outputs:

```
  $ command
  expected output
```

When a test runs successfully without any expected output specified, it just verifies the command exits successfully (exit code 0).

## Adding New Tests

To add a new test:

1. Create a `.t` file in this directory
2. Write commands starting with `  $ ` (two spaces, dollar sign, space)
3. Run `dune test --auto-promote` to capture the output
4. Review the promoted output and commit

## Modifying Test Dependencies

Test dependencies are declared in `test/dune`. If you add new test fixtures, add them to the `deps` section.
