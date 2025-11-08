if exists("b:current_syntax")
  finish
endif

" Comments (must be early to take precedence)
syn region sgCommentMulti start="'''" end="'''" contains=NONE
syn match sgComment "'[^'].*$"

" Strings
syn region sgString start=/\v"/ skip=/\v\\./ end=/\v"/

" Keywords
syn keyword sgKeyword def macro macros eval slice show use use-macros exec fire process spec stack chain process-step
syn keyword sgConstant ok

" Operators and separators
syn match sgOperator "::"
syn match sgOperator "=="
syn match sgOperator "\~="
syn match sgOperator "!="
syn match sgOperator "||"
syn match sgOperator "@"
syn match sgOperator "\.\.\."
syn match sgSeparator "[\{\}\[\]|]"

" Polarity markers (+ or - before identifiers)
syn match sgPolarity "[+-]\ze\w"

" Variables (uppercase starting identifiers)
syn match sgVariable "\<[A-Z_]\w*\>"

" Defined identifiers in (def X ...) - both simple and complex
syn match sgDefinedId "\((def\s\+\)\@<=[a-z_][a-z0-9_]*"
syn match sgDefinedId "\((def\s\+\)\@<=\d\+"
syn match sgDefinedId "\((def\s*(\)\@<=[^)]\+"

" Identifier references (prefixed with #)
syn match sgIdRef "#[a-z_][a-z0-9_]*"
syn match sgIdRef "#\d\+"
syn match sgIdRef "#([^)]\+)"

hi link sgKeyword Keyword
hi link sgConstant Constant
hi link sgComment Comment
hi link sgCommentMulti Comment
hi link sgOperator Operator
hi link sgSeparator Delimiter
hi link sgString String
hi link sgPolarity Special
hi link sgVariable Type
hi link sgIdRef Identifier
hi link sgDefinedId Function

let b:current_syntax = "stellogen"
