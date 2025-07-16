syn clear

syn keyword sgKeyword new declaration eval slice show use interact fire process
syn match sgComment "\s*'[^'].*$"
syn match sgId "#\%(\l\|\d\)\w*"
syn region sgComment start="'''" end="'''" contains=NONE
syn region sgString start=/\v"/ skip=/\v\\./ end=/\v"/
syn match sgSeparator "[\<\>\{\}\[\]|]"
syn match sgOperator "@"
syn match sgOperator "::"
syn match sgOperator "=="
syn match sgOperator ":="
syn match sgOperator "!="

hi link sgKeyword Keyword
hi link sgId Identifier
hi link sgComment Comment
hi link sgOperator Operator
hi link sgSeparator Special
hi link sgString String
