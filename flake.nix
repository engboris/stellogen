{
  description = "stellogen";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    systems.url = "github:nix-systems/default";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    flake-compat = {
      url = "github:NixOS/flake-compat";
      flake = false;
    };
  };

  outputs =
    {
      flake-parts,
      systems,
      ...
    }@inputs:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = import systems;
      perSystem =
        {
          pkgs,
          lib,
          self',
          ...
        }:
        {
          packages = {
            stellogen = pkgs.ocamlPackages.callPackage ./package.nix { };

            stellogen-web = (self'.packages.stellogen.override { withExe = false; }).js;
            stellogen-minimal = self'.packages.stellogen.override {
              withWeb = false;
              withDoc = false;
            };

            docs =
              (self'.packages.stellogen.override {
                withExe = false;
                withWeb = false;
              }).doc;

            playground = pkgs.stdenvNoCC.mkDerivation {
              pname = "stellogen-playground";
              version = "0.1.0";
              src =
                let
                  inherit (lib) fileset;
                in
                fileset.toSource {
                  root = ./.;
                  fileset = fileset.unions [
                    ./examples
                    ./web/build-examples.js
                    ./web/index.html
                    ./web/worker.js
                  ];
                };
              buildPhase = ''
                runHook preBuild
                node ./web/build-examples.js
                runHook postBuild
              '';
              nativeBuildInputs = [
                pkgs.nodejs-slim
              ];
              installPhase = ''
                runHook preInstall
                mkdir -p "$out/share/web/"
                cp web/index.html web/examples.js web/worker.js "$out/share/web/"
                cp ${self'.packages.stellogen-web}/share/web/playground.js "$out/share/web/"
                runHook postInstall
              '';
            };

            default = self'.packages.stellogen;
          };

          apps = {
            playground.program = pkgs.writeShellApplication {
              name = "stellogen-playground-server";
              runtimeInputs = [ pkgs.simple-http-server ];
              text = ''
                cd ${lib.escapeShellArg self'.packages.playground}/share/web
                simple-http-server --index "$@" -- .
              '';
            };
            docs.program = pkgs.writeShellApplication {
              name = "stellogen-docs-server";
              runtimeInputs = [ pkgs.simple-http-server ];
              text = ''
                cd ${lib.escapeShellArg self'.packages.docs}/share/doc/stellogen/_html
                simple-http-server --index "$@" -- .
              '';
            };
          };

          devShells.default = pkgs.mkShell {
            packages = [
              pkgs.jq
            ]
            ++ (with pkgs.ocamlPackages; [
              ocaml
              ocamlformat
              menhir
              odoc
              ocaml-lsp
            ]);

            inputsFrom = [
              self'.packages.stellogen
            ];
          };
        };
    };
}
