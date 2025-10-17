# Stellogen Language Configuration

This directory contains language configuration files for Stellogen (`.sg` files) that can be used with various text editors and IDEs.

## Files

- **`language-configuration.json`**: Basic language configuration including comments, brackets, auto-closing pairs, and indentation rules
- **`stellogen.tmLanguage.json`**: TextMate grammar for syntax highlighting

## Usage

### VS Code / WindSurf (Recommended)

A complete VS Code extension is available in the `vscode-extension` directory.

#### Quick Installation

1. Navigate to the extension directory:
   ```bash
   cd vscode-extension
   ```

2. Run the installation script:
   ```bash
   ./install.sh
   ```

3. Restart VS Code/WindSurf

The script will automatically detect and install the extension for both VS Code and WindSurf if they are present on your system.

#### Manual Installation

Alternatively, copy the extension directory manually:

**For VS Code:**
```bash
cp -r vscode-extension ~/.vscode/extensions/stellogen-language-0.1.0
```

**For WindSurf:**
```bash
cp -r vscode-extension ~/.windsurf/extensions/stellogen-language-0.1.0
```

Then restart your editor.

### Other Editors

#### Sublime Text

1. Copy `stellogen.tmLanguage.json` to your Sublime Text Packages directory
2. Rename it to `Stellogen.sublime-syntax` and convert the JSON to YAML format

#### Atom

1. Create a package in `~/.atom/packages/language-stellogen`
2. Add the grammar and configuration files

#### TextMate

1. Copy `stellogen.tmLanguage.json` to your TextMate bundles directory
2. Convert to plist format if needed

## Language Features

The configuration provides:

- **Syntax Highlighting** for:
  - Comments (line `'` and block `'''`)
  - Keywords (`new`, `declaration`, `eval`, `slice`, `show`, `use`, `interact`, `fire`, `process`, `spec`, `macro`)
  - Operators (`:=`, `::`, `==`, `!=`, `||`, `@`)
  - Polarity markers (`+`, `-`)
  - Variables (uppercase identifiers)
  - Identifier references (`#identifier`)
  - Strings
  - Numbers
  - Constants (`ok`)

- **Auto-closing pairs** for:
  - Braces `{}`
  - Brackets `[]`
  - Parentheses `()`
  - Angle brackets `<>`
  - Quotes `""`

- **Comment toggling** with `'` for line comments and `'''` for block comments

- **Bracket matching** for all bracket types

- **Indentation rules** based on opening/closing brackets

## Customization

You can customize the syntax highlighting by modifying the `stellogen.tmLanguage.json` file. The file follows the TextMate grammar format.

To add new keywords, operators, or patterns, edit the corresponding sections in the `repository` object.

## Contributing

If you find issues or want to improve the language configuration, please submit a pull request or open an issue.
