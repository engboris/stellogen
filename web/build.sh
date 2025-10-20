#!/bin/bash
# Build script for Stellogen Web Playground

set -e

echo "Building Stellogen Web Playground..."
echo

# Build the JavaScript
echo "Step 1: Compiling OCaml to JavaScript..."
dune build web/playground.bc.js

# Create deploy directory
echo "Step 2: Creating deployment directory..."
mkdir -p web_deploy

# Copy files
echo "Step 3: Copying files..."
cp _build/default/web/playground.bc.js web_deploy/playground.js
cp web/index.html web_deploy/

# Get file size
JS_SIZE=$(du -h web_deploy/playground.js | cut -f1)

echo
echo "✅ Build complete!"
echo
echo "Generated files:"
echo "  - web_deploy/playground.js ($JS_SIZE)"
echo "  - web_deploy/index.html"
echo
echo "To test locally:"
echo "  cd web_deploy && python3 -m http.server 8000"
echo "  Then open http://localhost:8000"
echo
