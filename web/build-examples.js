#!/usr/bin/env node

/**
 * Build script to extract Stellogen examples from /examples directory
 * and generate a JavaScript file for the web playground.
 */

const fs = require('fs');
const path = require('path');

// Configuration: map example keys to their source files
const EXAMPLE_MAPPING = {
  hello: 'hello.sg',
  prolog: 'prolog.sg',
  macros: 'macro_demo.sg',
  nat: 'nat.sg',
  automata: 'automata.sg',
  stackmachine: 'npda.sg',
  turing: 'turing.sg',
  stack: 'stack.sg'
};

// Path configuration
const EXAMPLES_DIR = path.join(__dirname, '..', 'examples');
const OUTPUT_FILE = path.join(__dirname, 'examples.js');

/**
 * Process example file content for the playground
 * - Replace (use-macros "milkyway/prelude.sg") with inline macro definitions
 * - Adjust any other syntax needed for standalone execution
 */
function processExampleContent(content, filename) {
  // For files that use prelude macros, inline them
  if (content.includes('(use-macros "milkyway/prelude.sg")')) {
    const preludeMacros = `' Prelude macros (normally imported)
(macro (spec X Y) (:= X Y))
(macro (:: Tested Test)
  (== @(exec @#Tested #Test) ok))`;

    content = content.replace('(use-macros "milkyway/prelude.sg")', preludeMacros);
  }

  // Specific fixes for known issues
  if (filename === 'prolog.sg') {
    // Change 'exec' to 'interact' in the graph traversal example (line 48)
    content = content.replace(
      '<show exec (process',
      '<show interact (process'
    );
  }

  if (filename === 'stack.sg') {
    // Change 'exec' to 'interact' in stack example
    content = content.replace(
      '<show exec (process',
      '<show interact (process'
    );
  }

  if (filename === 'hello.sg') {
    // Add a welcome comment
    content = `' Hello World\n${content}`;
  }

  return content.trim();
}

/**
 * Main build function
 */
function buildExamples() {
  console.log('Building examples for Stellogen playground...\n');

  const examples = {};
  let successCount = 0;
  let errorCount = 0;

  // Process each example in the mapping
  for (const [key, filename] of Object.entries(EXAMPLE_MAPPING)) {
    const filepath = path.join(EXAMPLES_DIR, filename);

    try {
      if (!fs.existsSync(filepath)) {
        console.error(`❌ File not found: ${filename}`);
        errorCount++;
        continue;
      }

      const content = fs.readFileSync(filepath, 'utf-8');
      const processed = processExampleContent(content, filename);
      examples[key] = processed;

      console.log(`✓ Processed: ${filename} -> ${key}`);
      successCount++;
    } catch (error) {
      console.error(`❌ Error processing ${filename}:`, error.message);
      errorCount++;
    }
  }

  // Generate the JavaScript file
  const output = `// Auto-generated file - DO NOT EDIT
// Generated from examples/*.sg files
// Run './web/build.sh' or 'node web/build-examples.js' to regenerate

const examples = ${JSON.stringify(examples, null, 2)};

// Export for use in playground
if (typeof module !== 'undefined' && module.exports) {
  module.exports = examples;
}
`;

  fs.writeFileSync(OUTPUT_FILE, output, 'utf-8');

  console.log(`\n✓ Generated: ${OUTPUT_FILE}`);
  console.log(`\nSummary: ${successCount} successful, ${errorCount} errors`);

  if (errorCount > 0) {
    process.exit(1);
  }
}

// Run the build
buildExamples();
