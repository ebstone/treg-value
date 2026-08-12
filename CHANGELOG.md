# Changelog

One line per session: what changed, and which tests now cover it.

## 2026-08-11
- Repository initialised. SPEC.md v1.0 committed as governing authority.
  No code, no tests yet.
- L9 locked (pre-landmark trajectory = conventional therapy). Decision set closed;
  no item in SPEC.md awaits a co-author. See SPEC_AMENDMENTS.md.
- W1: renv + testthat scaffolding, and all eight guards (G1 provenance, G2 units,
  G3 denominators, G4 no-snapshots, G5 stamping, G6 aim coverage, G7 no-defaults,
  G8 no-status-prose) built with a violation fixture apiece under
  tests/violations/. Full suite green on the empty repository (34 assertions
  across 25 tests, 2 skips scaffolded for W4/analysis code); each guard's
  "fires" test proves it
  fails against its fixture. OPEN_QUESTIONS.md gained an "Arg name" column so G7
  can check function defaults mechanically. No model code, no data transcription.
