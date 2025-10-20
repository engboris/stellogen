# Stellogen Web Playground

A browser-based playground for experimenting with Stellogen code, compiled to JavaScript using js_of_ocaml.

## Building the Playground

### Prerequisites

Install the required OCaml packages:

```bash
opam install js_of_ocaml js_of_ocaml-compiler js_of_ocaml-ppx
```

### Build Steps

1. **Build the JavaScript file:**

```bash
# From the project root
dune build web/playground.bc.js
```

This will create:
- `_build/default/web/playground.bc.js` - The compiled JavaScript

2. **Copy files to serve:**

```bash
# Create a deploy directory
mkdir -p web_deploy
cp _build/default/web/playground.bc.js web_deploy/playground.js
cp web/index.html web_deploy/
```

3. **Serve locally (for testing):**

```bash
# Using Python
cd web_deploy
python3 -m http.server 8000

# Or using any other HTTP server
# Then open http://localhost:8000 in your browser
```

### Quick Build Script

You can also use this one-liner:

```bash
dune build web/playground.bc.js && mkdir -p web_deploy && cp _build/default/web/playground.bc.js web_deploy/playground.js && cp web/index.html web_deploy/ && echo "Build complete! Serve the web_deploy/ directory."
```

## Development

### Testing Changes

After modifying `web_interface.ml` or `playground.ml`:

```bash
# Rebuild
dune build web/playground.bc.js

# Copy to deploy folder
cp _build/default/web/playground.bc.js web_deploy/playground.js

# Reload browser (hard refresh: Ctrl+Shift+R)
```

### Debugging

Open browser developer console (F12) to see:
- JavaScript errors
- `console.log()` output (add to `playground.ml`)
- Network requests

Add debug output in `playground.ml`:

```ocaml
let run_stellogen code_js =
  Firebug.console##log (Js.string "Running code...");
  (* ... *)
```

## Browser Compatibility

Tested on:
- Chrome 90+
- Firefox 88+
- Safari 14+
- Edge 90+

Requires:
- JavaScript enabled
- ~10 MB available memory

## Contributing

To add features to the playground:

1. Modify `src/web_interface.ml` for core functionality
2. Update `web/playground.ml` for JavaScript exports
3. Enhance `web/index.html` for UI improvements
4. Test in multiple browsers
5. Update this README

## License

Same as Stellogen: GPL-3.0-only
