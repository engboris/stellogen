# Quick Installation Guide for Stellogen Extension

## For WindSurf Users

### Method 1: Automatic Installation (Easiest)

1. Open a terminal in the `vscode-extension` directory
2. Run:
   ```bash
   ./install.sh
   ```
3. **Restart WindSurf** (this is important!)
4. Open any `.sg` file and verify "Stellogen" appears in the language selector

### Method 2: Manual Installation

```bash
cp -r vscode-extension ~/.windsurf/extensions/stellogen-language-0.1.0
```

Then restart WindSurf.

## Verification

After restarting WindSurf:

1. Open a `.sg` file (e.g., `examples/nat.sg`)
2. Look at the bottom-right corner of the editor
3. You should see "Stellogen" as the language mode
4. Syntax highlighting should be active with:
   - Keywords in color (like `show`, `eval`, `interact`)
   - Comments in gray/green
   - Operators highlighted
   - Strings in quotes colored

## Troubleshooting

### Extension not showing up?

1. **Make sure you restarted WindSurf completely** (not just reloaded the window)
2. Check that the extension is in the right location:
   ```bash
   ls ~/.windsurf/extensions/stellogen-language-0.1.0
   ```
   You should see: `package.json`, `language-configuration.json`, `stellogen.tmLanguage.json`, etc.

3. Try opening the Extensions view in WindSurf (Cmd+Shift+X) and search for "Stellogen"

### Syntax highlighting not working?

1. Open a `.sg` file
2. Click on the language mode in the bottom-right corner
3. Search for "Stellogen" and select it manually
4. If it's not in the list, the extension didn't install correctly - try reinstalling

### Still having issues?

Run the install script with verbose output:
```bash
bash -x ./install.sh
```

This will show you exactly what's happening during installation.

## Uninstallation

To remove the extension:

```bash
rm -rf ~/.windsurf/extensions/stellogen-language-0.1.0
```

Then restart WindSurf.
