# Stellogen Web Playground

A browser-based playground for experimenting with Stellogen code, compiled to JavaScript using js_of_ocaml.

## Features

- **No installation required** - runs entirely in the browser
- **Instant feedback** - see results immediately
- **Example programs** - learn from built-in examples
- **Keyboard shortcuts** - Ctrl/Cmd+Enter to run code
- **Clean interface** - dark theme, syntax-aware editor

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

## Deployment

The web playground is entirely static (client-side only), so it can be deployed to any static hosting service:

- **GitHub Pages**: Push `web_deploy/` contents to gh-pages branch
- **Netlify**: Drag-and-drop the `web_deploy/` folder
- **Vercel**: Deploy the `web_deploy/` directory
- **Any web server**: Copy files to your public directory

### GitHub Pages Example

```bash
# Build
dune build web/playground.bc.js

# Copy to deploy folder
mkdir -p docs
cp _build/default/web/playground.bc.js docs/playground.js
cp web/index.html docs/

# Commit and push
git add docs/
git commit -m "Update web playground"
git push

# Enable GitHub Pages to serve from /docs directory in repository settings
```

## Architecture

```
web/
├── playground.ml      # OCaml entry point with js_of_ocaml exports
├── index.html         # Web UI (editor + output panel)
├── dune              # Build configuration
└── README.md         # This file

src/
├── web_interface.ml  # String-based API for browser
├── sgen_parsing.ml   # Parser with string input support
└── ...               # Core Stellogen implementation
```

### How It Works

1. **OCaml to JavaScript**: `playground.ml` is compiled to JavaScript using js_of_ocaml
2. **API Export**: The `Stellogen.run()` function is exported to JavaScript
3. **Web UI**: `index.html` provides the editor and calls `Stellogen.run()`
4. **String-based**: All parsing and evaluation works on strings (no file I/O)
5. **Output Capture**: Results are captured to a buffer instead of stdout

## Limitations

### Not Supported in Web Playground

- **File imports**: `(use "file.sg")` and `(use-macros "file.sg")` don't work
  - Reason: No filesystem in browser
  - Workaround: Copy/paste code directly into the editor

- **External libraries**: Can't load external .sg files
  - Workaround: Include all code in the editor

### Supported Features

✅ All core Stellogen features:
- Definitions (`:=`)
- Macros (`macro`)
- Show output (`show`)
- Assertions (`==`, `~=`)
- Constellations, rays, stars
- Interactions (`interact`, `fire`)
- Process chaining (`process`)
- Focus (`@`), calls (`#`)

## File Size Optimization

The generated JavaScript can be large (~5-10 MB). To optimize:

### 1. Use js_of_ocaml optimization flags

```bash
# Edit web/dune to add optimization
(executable
 (name playground)
 (modes js)
 (libraries stellogen js_of_ocaml)
 (preprocess (pps js_of_ocaml-ppx))
 (js_of_ocaml (flags (:standard --opt 3 --disable genprim))))
```

### 2. Enable gzip compression

Most web servers automatically compress .js files, reducing size by ~70%.

### 3. Split loading (advanced)

For very large files, consider:
- Lazy loading the compiler on first run
- Web Workers for compilation
- IndexedDB caching

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

## Links

- [Stellogen Repository](https://github.com/engboris/stellogen)
- [js_of_ocaml Documentation](https://ocsigen.org/js_of_ocaml/)
- [Report Issues](https://github.com/engboris/stellogen/issues)
