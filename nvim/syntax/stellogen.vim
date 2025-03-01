syn clear

syn keyword sgKeyword show exec spec trace process end galaxy run interface
syn match sgComment "\s*'[^'].*$"
syn match sgId "#\%(\l\|\d\)\w*"
syn match sgIdDef "\zs\%(\l\|\d\)\w*\ze\s*="
syn match sgIdType "\zs\%(\l\|\d\)\w*\ze\s*::"
syn match sgType "^\w*\s*::\s*\zs\%(\l\|\d\)\w*\ze"
syn region sgComment start="'''" end="'''" contains=NONE
syn region sgString start=/\v"/ skip=/\v\\./ end=/\v"/
syn match sgSeparator "[;\.\{\}\:\[\]|]"
syn match sgOperator "[=@]"
syn match sgOperator "=>"
syn match sgOperator "!="

hi link sgKeyword Keyword
hi link sgId Identifier
hi link sgIdDef Identifier
hi link sgIdType Identifier
hi link sgComment Comment
hi link sgOperator Operator
hi link sgSeparator Special
hi link sgString String
hi link sgType Type
