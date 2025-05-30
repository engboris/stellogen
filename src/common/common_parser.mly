%token PRINT
%token EOF
%token AT
%token EOL
%token AMP
%token STAR
%token SLASH
%token LBRACK RBRACK
%token LBRACE RBRACE
%token LANGLE RANGLE
%token LPAR RPAR

%%

let delimited_opt(l, x, r) :=
  | ~=x; <>
  | ~=delimited(l, x, r); <>

%public let pars(x) == ~=delimited(LPAR; EOL*, x, EOL*; RPAR); <>
%public let bracks(x) == ~=delimited(LBRACK; EOL*, x, EOL*; RBRACK); <>
%public let braces(x) == ~=delimited(LBRACE; EOL*, x, EOL*; RBRACE); <>
%public let bracks_opt(x) == ~=delimited_opt(LBRACK; EOL*, x, EOL*; RBRACK); <>
%public let braces_opt(x) == ~=delimited_opt(LBRACE; EOL*, x, EOL*; RBRACE); <>
