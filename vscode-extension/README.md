# Stellogen Language Support for VS Code / WindSurf

This extension provides language support for Stellogen (`.sg` files) in VS Code and WindSurf.

## Features

- **Syntax Highlighting** for Stellogen keywords, operators, and constructs
- **Comment Support** - Line comments with `'` and block comments with `'''`
- **Bracket Matching** - Automatic matching for `{}`, `[]`, `()`, `<>`
- **Auto-closing Pairs** - Automatic closing of brackets and quotes
- **Smart Indentation** - Context-aware indentation

## Installation

### For WindSurf / VS Code

#### Option 1: Install from Extension Directory (Recommended)

1. Open a terminal in the `vscode-extension` directory
2. Run the installation script:
   ```bash
   ./install.sh
   ```
3. Restart WindSurf/VS Code

#### Option 2: Manual Installation

1. Copy the entire `vscode-extension` folder to your extensions directory:
   
   **For VS Code:**
   ```bash
   cp -r vscode-extension ~/.vscode/extensions/stellogen-language-0.1.0
   ```
   
   **For WindSurf:**
   ```bash
   cp -r vscode-extension ~/.windsurf/extensions/stellogen-language-0.1.0
   ```

2. Restart WindSurf/VS Code

#### Option 3: Symlink (For Development)

Create a symlink to the extension directory:

**For VS Code:**
```bash
ln -s "$(pwd)/vscode-extension" ~/.vscode/extensions/stellogen-language-0.1.0
```

**For WindSurf:**
```bash
ln -s "$(pwd)/vscode-extension" ~/.windsurf/extensions/stellogen-language-0.1.0
```

### Verify Installation

1. Open a `.sg` file
2. Check the language mode in the bottom right corner - it should show "Stellogen"
3. Verify syntax highlighting is working

## Language Features

### Syntax Highlighting

- **Keywords**: `new`, `declaration`, `eval`, `slice`, `show`, `use`, `interact`, `fire`, `process`, `spec`, `macro`
- **Operators**: `:=`, `::`, `==`, `!=`, `||`, `@`
- **Polarity Markers**: `+`, `-`
- **Variables**: Uppercase identifiers (e.g., `X`, `Y`, `Result`)
- **Identifier References**: `#identifier`, `#(complex identifier)`
- **Constants**: `ok`
- **Comments**: Single-line `'` and multi-line `'''`
- **Strings**: Double-quoted strings with escape sequences

### Auto-completion

The extension provides basic bracket and quote auto-completion.

## About Stellogen

Stellogen is a logic-agnostic programming language based on term unification. It explores a different way of thinking about programming languages: instead of relying on primitive types or fixed logical rules, it is built on the simple principle of term unification.

For more information, visit: https://github.com/engboris/stellogen

## Issues and Contributions

If you encounter any issues or have suggestions for improvements, please file an issue on the [GitHub repository](https://github.com/engboris/stellogen).
