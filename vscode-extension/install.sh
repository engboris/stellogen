#!/bin/bash

# Installation script for Stellogen Language Extension

set -e

EXTENSION_NAME="stellogen-language-0.1.0"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo "🌟 Stellogen Language Extension Installer"
echo "=========================================="
echo ""

# Detect which editor to install for
install_for_vscode=false
install_for_windsurf=false

if [ -d "$HOME/.vscode/extensions" ]; then
    echo "✓ VS Code detected"
    install_for_vscode=true
fi

if [ -d "$HOME/.windsurf/extensions" ]; then
    echo "✓ WindSurf detected"
    install_for_windsurf=true
fi

if [ "$install_for_vscode" = false ] && [ "$install_for_windsurf" = false ]; then
    echo "❌ Neither VS Code nor WindSurf extensions directory found."
    echo ""
    echo "Please ensure one of the following directories exists:"
    echo "  - ~/.vscode/extensions (for VS Code)"
    echo "  - ~/.windsurf/extensions (for WindSurf)"
    exit 1
fi

echo ""
echo "Installing extension..."
echo ""

# Install for VS Code
if [ "$install_for_vscode" = true ]; then
    TARGET_DIR="$HOME/.vscode/extensions/$EXTENSION_NAME"
    echo "📦 Installing to VS Code: $TARGET_DIR"
    
    # Remove old version if exists
    if [ -d "$TARGET_DIR" ] || [ -L "$TARGET_DIR" ]; then
        rm -rf "$TARGET_DIR"
        echo "  Removed old version"
    fi
    
    # Copy extension
    cp -r "$SCRIPT_DIR" "$TARGET_DIR"
    echo "  ✓ Installed to VS Code"
fi

# Install for WindSurf
if [ "$install_for_windsurf" = true ]; then
    TARGET_DIR="$HOME/.windsurf/extensions/$EXTENSION_NAME"
    echo "📦 Installing to WindSurf: $TARGET_DIR"
    
    # Remove old version if exists
    if [ -d "$TARGET_DIR" ] || [ -L "$TARGET_DIR" ]; then
        rm -rf "$TARGET_DIR"
        echo "  Removed old version"
    fi
    
    # Copy extension
    cp -r "$SCRIPT_DIR" "$TARGET_DIR"
    echo "  ✓ Installed to WindSurf"
fi

echo ""
echo "✅ Installation complete!"
echo ""
echo "Next steps:"
echo "  1. Restart VS Code/WindSurf"
echo "  2. Open a .sg file"
echo "  3. Verify 'Stellogen' appears in the language mode selector"
echo ""
