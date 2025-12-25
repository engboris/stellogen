type expr_err =
  | EmptyRay
  | NonConstantRayHeader of string
  | InvalidBan of string
  | InvalidRaylist of string
  | InvalidDeclaration of string
  | InvalidMacroArgument of string
  | InvalidBanStructure of string
  | CircularImport of string
  | FileLoadError of
      { filename : string
      ; message : string
      }
