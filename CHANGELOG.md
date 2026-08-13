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
  "fires" test proves it fails against its fixture. OPEN_QUESTIONS.md gained an
  "Arg name" column so G7 can check function defaults mechanically. No model
  code, no data transcription.

## 2026-08-11 (second session)
- W2 partial: CMS ASP infliximab biosimilar (April 2026) transcribed with a
  provenance sidecar carrying four unresolved items. docs/W2_sourcing_register.md
  records what remains and how to close it. O7-O9 opened.
- Surgery-state costing corrected: derives from Aliyev's Severe-Fulminant PMPM
  via the standard conversion, not an HCUP colectomy episode. O9 closed as C7.
  Amendment recorded.
- docs/W2_session_prompt.md added (transcription session + health-state cost
  derive script and its re-derivation test).

## 2026-08-12 (merge)
- Merged the W1 (guards) and W2-prep (CMS ASP data, sourcing register, surgery
  costing amendment, W2 prompt) branches, which had diverged from the same
  parent commit in two concurrent sessions. Reconciled OPEN_QUESTIONS.md (Arg
  name values added for O7/O8) and this file. Adjusted G1's sidecar schema to
  match the ASP sidecar's actual shape (`retrieved` in place of
  `retrieval_date`, `table_or_page` optional, `status` required) rather than
  W1's originally-guessed field names, and filled in its `sha256` (previously
  `PENDING`) from the committed CSV. No SPEC.md content changed by the merge
  itself; the surgery-costing amendment predates it (see SPEC_AMENDMENTS.md).
