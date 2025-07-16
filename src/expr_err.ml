type expr_err =
  | EmptyRay
  | NonConstantRayHeader of string
  | InvalidBan of string
  | InvalidRaylist of string
  | InvalidDeclaration of string
