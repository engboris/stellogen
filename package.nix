{
  lib,
  buildDunePackage,

  alcotest,
  base,
  calendar,
  easy_logging,
  menhir,
  menhirLib,
  ppx_deriving,
  sedlex,
  stdio,

  js_of_ocaml,
  js_of_ocaml-ppx,

  odoc,

  withExe ? true,
  withWeb ? true,
  withDoc ? true,
}:
assert withExe || withWeb || withDoc;
buildDunePackage (finalAttrs: {
  pname = "stellogen";
  version = "0.1.0";
  duneVersion = "3";
  src =
    let
      inherit (lib) fileset;
    in
    fileset.toSource {
      root = ./.;
      fileset = fileset.unions (
        [
          ./dune-project
          ./stellogen.opam
          ./src
          ./README.md
          ./LICENSE
        ]
        ++ lib.optional withExe ./bin
        ++ lib.optional withWeb ./web
        ++ lib.optionals finalAttrs.doCheck [
          ./test
          ./examples
        ]
      );
    };

  outputs = [ "out" ] ++ lib.optional withWeb "js" ++ lib.optional (withExe || withDoc) "doc";

  OCAMLPARAM = "_,warn-error=+A";
  doCheck = withExe;

  buildFlags =
    lib.optional finalAttrs.doCheck "@runtest"
    ++ lib.optional withDoc "@doc"
    ++ lib.optional withExe "@install"
    ++ lib.optional withWeb "web/playground.bc.js";

  propagatedBuildInputs = [
    alcotest
    base
    calendar
    easy_logging
    menhirLib
    ppx_deriving
    sedlex
    stdio
  ]
  ++ lib.optionals withWeb [
    js_of_ocaml
    js_of_ocaml-ppx
  ];
  nativeBuildInputs = [
    menhir
  ]
  ++ lib.optional withWeb js_of_ocaml
  ++ lib.optional withDoc odoc;

  buildPhase = ''
    runHook preBuild
    dune build -p "$pname" $buildFlags ''${enableParallelBuilding:+-j $NIX_BUILD_CORES}
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
  ''
  # Documentation is moved from $out to $doc automatically
  + lib.optionalString withDoc ''
    mkdir -p "$out/share/doc/"
    cp -R _build/default/_doc "$out/share/doc/$pname"
  ''
  + lib.optionalString withExe ''
    dune install --prefix $out \
      --libdir "$OCAMLFIND_DESTDIR" "$pname" \
      --docdir "$out/share/doc" \
      --mandir "$out/share/man"
  ''
  + lib.optionalString withWeb ''
    mkdir -p "$js/share/web"
    cp _build/default/web/playground.bc.js "$js/share/web/playground.js"
  ''
  + ''
    runHook postInstall
  '';

  meta = {
    description = "Programming language where computation and types are built from the same mechanism: term unification";
    homepage = "https://github.com/engboris/stellogen";
    license = lib.licenses.gpl3Only;
    sourceProvenance = lib.sourceTypes.fromSource;
    maintainers = [
      lib.maintainers.magistau
    ];
  }
  // lib.optionalAttrs withExe {
    mainProgram = "sgen";
  };
})
