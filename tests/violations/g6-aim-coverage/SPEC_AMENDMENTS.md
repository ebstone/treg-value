# Fixture amendments (G6 violation)

Deliberately silent on the fixture's second aim, which is left uncovered on
purpose so `uncovered_aims()` has something to catch.

## 2026-08-14 — A3 dropped

A3 is recorded here, unbolded, exactly as the real SPEC_AMENDMENTS.md refers
to identifiers. Its output file is deliberately absent, so the only thing that
can keep it out of `uncovered_aims()` is the amendment branch actually working
against a bolded aim ID. Before that branch was reachable, A3 would have been
reported uncovered despite being properly amended.
