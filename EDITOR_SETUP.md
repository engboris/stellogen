# Stellogen Editor Setup

This document provides a quick reference for setting up Stellogen language support in your editor.

## WindSurf / VS Code

### Installation

The extension has been **already installed** for you! Just follow these steps:

1. **Restart WindSurf completely** (close and reopen the application)
2. Open any `.sg` file
3. Check the language mode in the bottom-right corner - it should show "Stellogen"

### Reinstall if needed

If the extension isn't working:

```bash
cd vscode-extension
./install.sh
```

Then restart WindSurf.

### What You Get

- ✅ Syntax highlighting for all Stellogen constructs
- ✅ Auto-closing brackets: `{}`, `[]`, `()`, `<>`
- ✅ Comment toggling with `Cmd+/` (line comments with `'`)
- ✅ Smart indentation
- ✅ Bracket matching

### Extension Location

The extension is installed at:
- **WindSurf**: `~/.windsurf/extensions/stellogen-language-0.1.0`
- **VS Code**: `~/.vscode/extensions/stellogen-language-0.1.0`

## Neovim

Neovim configuration is available in the `nvim/` directory.

### Installation

Copy the contents to your Neovim config:

```bash
cp -r nvim/ftdetect ~/.config/nvim/
cp -r nvim/syntax ~/.config/nvim/
```

Or if you use a plugin manager, add the `nvim/` directory to your runtime path.

## Other Editors

For Sublime Text, Atom, or TextMate, see the detailed instructions in `LANGUAGE_CONFIG.md`.

## Files Overview

- `vscode-extension/` - Complete VS Code/WindSurf extension (ready to use)
- `nvim/` - Neovim syntax and filetype detection
- `language-configuration.json` - Base language configuration
- `stellogen.tmLanguage.json` - TextMate grammar for syntax highlighting
- `LANGUAGE_CONFIG.md` - Detailed documentation for all editors

## Troubleshooting

### WindSurf: Extension not showing?

1. Verify installation:
   ```bash
   ls ~/.windsurf/extensions/stellogen-language-0.1.0
   ```

2. Reinstall:
   ```bash
   cd vscode-extension && ./install.sh
   ```

3. **Restart WindSurf completely** (not just reload window)

### Syntax highlighting not working?

1. Open a `.sg` file
2. Click the language mode selector (bottom-right)
3. Type "Stellogen" and select it
4. If not found, reinstall the extension

### Need help?

Check the detailed guides:
- `vscode-extension/INSTALL_GUIDE.md` - WindSurf/VS Code installation
- `vscode-extension/README.md` - Extension features and usage
- `LANGUAGE_CONFIG.md` - Configuration for all editors
