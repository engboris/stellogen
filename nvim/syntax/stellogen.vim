syn clear

syn keyword sgKeyword kill clean eval show use exec spec linexec trace process run union
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
syn match sgOperator "&"

hi link sgKeyword Keyword
hi link sgId Identifier
hi link sgComment Comment
hi link sgOperator Operator
hi link sgSeparator Special
hi link sgString String
