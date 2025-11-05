Test examples directory
========================

Binary4 example:
  $ sgen run ../examples/binary4.sg
  { [(+b b1 4 1)] [(+b b1 3 0)] [(+b b1 2 0)] [(+b b1 1 0)] }
  { [(+b b2 4 1)] [(+b b2 3 1)] [(+b b2 2 0)] [(+b b2 1 0)] }
  { [(+b r 4 1)] [(+b r 3 0)] [(+b r 2 0)] [(+b r 1 0)] }
  { [(+b r 4 1)] [(+b r 3 1)] [(+b r 2 0)] [(+b r 1 0)] }
  { [(+b r 4 0)] [(+b r 3 1)] [(+b r 2 1)] [(+b r 1 1)] }
  { [(+b r2 4 0)] [(+b r2 3 1)] [(+b r2 2 1)] [(+b r2 1 1)] }

Circuits example:
  $ sgen run ../examples/circuits.sg

Lambda calculus example:
  $ sgen run ../examples/lambda/lambda.sg
  [(out (%cons r X7)) (ida (exp (%cons l X7) d))]
  [(out X7) (x (exp X7 d))]

Linear lambda example:
  $ sgen run ../examples/lambda/linear_lambda.sg
  {}
  {}

MALL (multiplicative-additive linear logic) example:
  $ sgen run ../examples/proofnets/mall.sg
  { [(-3 (%cons r (%cons l X4))) (-3 (%cons r (%cons r X4))) || (slice c b)] [(c X11) (d X11) || (slice c a)] }

MLL (multiplicative linear logic) example:
  $ sgen run ../examples/proofnets/mll.sg

Natural numbers example:
  $ sgen run ../examples/naive_nat.sg
  (+nat (s (s (s 0))))
  (res 1)
  (res 0)

NPDA (non-deterministic pushdown automaton) example:
  $ sgen run ../examples/states/npda.sg
  { [accept] [accept] }
  accept
  accept
  {}

Prolog-style arithmetic examples:
  $ sgen run ../examples/prolog/arithmetic.sg
  (result of 0 + 0 = 0)
  (result of 0 + (s (s (s (s 0)))) = (s (s (s (s 0)))))
  (result of (s (s 0)) + (s (s 0)) = (s (s (s (s 0)))))
  (result of (s (s 0)) + (s (s 0)) = (s (s (s (s 0)))))
  (result of 0 - 0 = 0)
  (result of (s (s (s (s 0)))) - (s (s 0)) = (s (s 0)))
  (result of (s (s (s (s 0)))) - (s (s 0)) = (s (s 0)))

Prolog-style family examples:
  $ sgen run ../examples/prolog/family.sg
  bob
  { [pat] [ann] }

Stack example:
  $ sgen run ../examples/stack.sg
  (save 0)

Sum types example:
  $ sgen run ../examples/sumtypes.sg
  a

Syntax reference:
  $ sgen run ../examples/syntax.sg
  a
  { [c] [b] [a] }
  (%string hello world)
  (function a b)
  { [(-f X) (-f Y) (r X Y) || (!= X Y)] [(+f b)] [(+f a)] }
  { [(r b a) || (!= b a)] [(r a b) || (!= a b)] }
  (+n2 (s (s 0)))
  { [(+field test2) (%cons (+f b) (%cons ok %nil))] [(+field test1) (%cons (+f a) (%cons ok %nil))] }
  [(+f a) ok]
  [(+f b) ok]
  (-field test2)

Turing machine example:
  $ sgen run ../examples/states/turing.sg
  reject
  reject
  reject
  accept
  accept
  accept
  accept
  accept

NFA (non-deterministic finite automaton) example:
  $ sgen run ../examples/states/nfa.sg
  {}
  accept
  {}
  {}
