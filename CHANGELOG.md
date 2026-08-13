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

## 2026-08-12 (W2 continued)
- ten Ham et al. 2020's original source (not previously in hand) located and
  downloaded publicly; transcribed Table I and Table II into
  data/raw/tenham2020_case_studies.csv.
- All four Aliyev targets transcribed: aliyev2019_assumptions.csv (29 rows,
  Suppl. Table 1 -- read from a 400 DPI rendering per the prompt's
  scrambled-text-layer warning, not pdftotext), aliyev2019_source_parameters.csv
  (59 rows, Suppl. Table 2), aliyev2019_induction_transitions.csv (Suppl.
  Table 3), aliyev2019_maintenance_transitions.csv (Suppl. Table 4, including
  the Conventional Therapy sub-table). Corrected W2_session_prompt.md's
  citation: Tables 1-4 are all in Appendix S2, not Appendix S1 as the prompt
  states (verified by opening both files -- Appendix S1 is only 3 pages and
  has no Table 3 or 4). Also transcribed Suppl. Table 5 as
  aliyev2019_base_case_costs_utilities.csv, beyond the prompt's original
  four-file list -- needed to resolve the finding below.
- Found and resolved OPEN_QUESTIONS.md O9/C8: Aliyev's own Suppl. Table 2
  ($374 PMPM, verified at 1200 DPI) and Suppl. Table 5 ($217/cycle) disagree
  for Moderate-Severe; the stated conversion rule reproduces the other three
  health states within $1 but gives $224.43, not $217, for this one. Per
  Eric Stone: Moderate-Severe and Moderate-Severe Responder now read
  Suppl. Table 5's adopted figure directly; Mild, Remission and Surgery
  still derive from PMPM. Both paths implemented in
  derive/health_state_costs.R, reading from data/raw/ rather than
  re-hardcoding transcribed numbers, with re-derivation tests for each path
  in tests/testthat/test-health-state-costs.R.
- G1 (provenance) now validated against seven real transcribed files, not
  just fixtures; caught and fixed a real bug in the guard itself
  (`field_is_empty()` broke on the ASP sidecar's nested `citation` object).
  Full suite: 46 assertions across 27 tests, 0 failures, 2 skips (pre-existing,
  W4/analysis-code scaffolds). Gate A satisfied: every data/raw/ file has a
  resolving sidecar, and the health-state cost rule reproduces all published
  per-cycle figures (three derived, two adopted directly, both documented).

## 2026-08-12 (pre-W3 sourcing)
- Sourced what W2_sourcing_register.md S-1 and OPEN_QUESTIONS.md O7/O8/U1-U4
  flagged as blocking W3. CPT 96365/96366 (infusion administration) RVUs and
  payment amounts sourced directly from CMS's own open-data API
  (pfs.data.cms.gov/dataset -- www.cms.gov itself returned HTTP 403 to a
  direct fetch) as data/raw/cms_pfs_infusion_administration_2026.csv. O7
  closed as C9: 96365 = $67.14, 96366 = $21.38 (add-on), and the
  facility/non-facility question S-1 raised turned out moot -- CMS's own
  data has identical RVUs for both settings for these two codes.
- Re-pulled the CMS ASP infliximab file at the current 2026-07 quarter
  (superseding 2026-04), added the originator (J1745) and a third biosimilar
  (Q5121, Avsola) alongside Q5103/Q5104. Resolved U1 (confirmed "Payment
  Limit" is ASP+6% by CMS's own methodology, not raw ASP), U2 (quarter now
  current), and U4 (originator now included). U3 (which product prices the
  base case) stays open -- a decision, not a lookup -- narrowed into O8 for
  Eric/co-author sign-off.
- Corrected W2_sourcing_register.md S-2, which had stated Aliyev's
  Moderate-Severe PMPM as $362 (a figure that does not appear in the actual
  source and appears to have been backed into to make the reconciliation
  arithmetic work) -- now states the real $374 figure and the C8 finding
  that it does not reconcile, rather than the previously-false "all four
  reconcile... with no free parameters" claim.
- Full suite unchanged at 46 assertions / 27 tests, 0 failures, 2 pre-existing
  skips (new data/raw/ files validated against G1 individually and via the
  full suite).
