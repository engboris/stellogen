#!/bin/bash
# Build script for Stellogen Web Playground

set -e

echo "Building Stellogen Web Playground..."
echo

# Generate examples from source files
echo "Step 1: Generating examples from .sg files..."
node web/build-examples.js

# Build the JavaScript
echo "Step 2: Compiling OCaml to JavaScript..."
dune build web/playground.bc.js

# Create deploy directory
echo "Step 3: Creating deployment directory..."
mkdir -p web_deploy

# Copy files
echo "Step 4: Copying files..."
cp _build/default/web/playground.bc.js web_deploy/playground.js
cp web/index.html web_deploy/
cp web/examples.js web_deploy/

# Get file size
JS_SIZE=$(du -h web_deploy/playground.js | cut -f1)

echo
echo "✅ Build complete!"
echo
echo "Generated files:"
echo "  - web_deploy/playground.js ($JS_SIZE)"
echo "  - web_deploy/index.html"
echo "  - web_deploy/examples.js (auto-generated from examples/*.sg)"
echo
echo "To test locally:"
echo "  cd web_deploy && python3 -m http.server 8000"
echo "  Then open http://localhost:8000"
echo
