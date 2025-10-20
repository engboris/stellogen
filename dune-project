(lang dune 3.7)

(name stellogen)

(generate_opam_files true)

(source
 (github engboris/stellogen))

(authors "Boris Eng")

(maintainers "Boris Eng")

(license GPL-3.0-only)

(documentation https://github.com/engboris/stellogen/blob/main/README.md)

(package
 (name stellogen)
 (synopsis "Stellogen is a minimalistic and logic-agnostic programming
language based on term unification.")
 (depends base menhir sedlex ppx_deriving js_of_ocaml js_of_ocaml-ppx)
 (tags
  ("transcendental syntax" "logic programming" "constraint programming" "resolution logic" "unification" "self-assembly")))

(using menhir 2.1)

; See the complete stanza docs at https://dune.readthedocs.io/en/stable/dune-files.html#dune-project
