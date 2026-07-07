Test syntax - basic syntax tests
==================================

Linear execution test:
  $ sgen run syntax/linear.sg

Prolog-style test:
  $ sgen run syntax/prolog.sg

Records test:
  $ sgen run syntax/records.sg

Multi-star def test:
  $ sgen run syntax/multistar_def.sg

Galaxy and forall test:
  $ sgen run syntax/galaxy.sg
  [(-check a) ok]
  [(-check b) ok]

Match (~=) is polarity-blind structural unifiability:
  $ sgen run syntax/match.sg
