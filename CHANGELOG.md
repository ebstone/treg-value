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

## 2026-08-13 (W3: comparator Markov engine)
- Sourced two remaining gaps found while building: data/raw/nchs_life_table_2023.csv
  (NCHS United States Life Tables 2023, Table 1, sex-averaged -- fetched
  directly from cdc.gov) for background mortality, and a model starting age
  (35, from the SONIC trial's median age -- SPEC.md never specified one and
  Aliyev's own figure is paywalled). Both recorded in SPEC_AMENDMENTS.md.
- Found and fixed a real gap from W2: aliyev2019_maintenance_transitions.csv
  never actually got the Conventional Therapy (CT) sub-table's rows, though
  W2's sidecar referenced having viewed that page. Added them; sha256 and
  sidecar updated.
- Built the comparator engine: R/transition_matrices.R (loads and
  renormalises Aliyev's induction/maintenance matrices -- trap 4, recorded
  in SPEC_AMENDMENTS.md, never silent), R/life_table.R (DEALE-style
  annual-to-2wk mortality conversion, matching Aliyev's own methodology),
  R/dosing.R (induction/maintenance dosing schedules, provisional pending
  O8 on which biosimilar prices the base case), R/costs_utilities.R, and
  R/markov_engine.R (induction decision tree, dual biologic/CT cohort
  tracking with the Moderate-Severe redirect mechanic, 2-year cap, half-cycle
  correction, age-varying background mortality, 3% discounting).
  analysis/run_infliximab_trace.R runs and stamps the trace and a validation
  table for all 12 combinations (2 windows x 2 cap settings x 3 horizons)
  -- intermediate artifacts, no SPEC.md section 6 aim satisfied this session.
- All six traps in the W3 session prompt addressed and tested: induction
  cost/QALY accrual, cap-timing dose-count exactness, induction window/dosing
  consistency, transition-row renormalisation (documented, not silent),
  maintenance Moderate-Severe row sourced from Table 4 (CT) directly rather
  than reused from induction, and no colectomy-scale Surgery cost.
- Extended G2 (units) with six new suffixes real model code needed
  (`_usd`, `_utility`, `_discount_factor`, `_prob_1yr`, `_life_years`,
  `_age_years`, plus `_years`/`_kg`/`_mg`/`_mg_per_kg`), and fixed two real
  gaps the guard itself had never been exercised against: suffix matching
  was case-sensitive (broke idiomatic UPPER_SNAKE_CASE R constants), and the
  unnamed-converter check flagged any function combining 2+ differently-
  suffixed arguments even when nothing was actually being converted (an
  orchestrator taking several independent inputs) -- narrowed to exactly 2,
  matching the guard's own pairwise-conflation rationale. Also fixed G6's
  skip condition, which kept "output/tables/ is empty" as its trigger even
  after this session populated it with non-aim intermediate files -- now
  checks for an aim-*designated* output specifically.
- T6, T7, T8 all pass; T8 in particular: model undiscounted life expectancy
  from age 35 is 45.203 years against the life table's own 45.2, a 0.003-year
  difference.
- Full suite: 92 assertions across 48 tests, 0 failures, 2 pre-existing skips.

## 2026-08-13 (W4: Treg arm and price frontier)
- **Correction to W3, recorded in SPEC_AMENDMENTS.md:** Aliyev's separate
  "Conventional therapy per cycle, $67" cost line was never charged. Every
  cost figure W3 reported is superseded; lifetime comparator cost at the
  8-week/cap-on case moves $74,270.51 -> $115,257.80 (+55%), QALYs unchanged.
  output/tables/comparator_ifx_trace.csv regenerated.
- R/treg_arm.R: conventional-therapy dynamics to the 12-week landmark (L9),
  two-fate split at cycle 6 on the ALL-TREATED denominator (L1/L2),
  drug-free-remission state with an ongoing relapse hazard, relapsers
  rejoining standard care in full (L4). `pi_cure` is declared with
  `denominator = "all_treated"`, which binds W1's dormant G3 scaffold --
  that test now runs instead of skipping.
- R/frontier.R: A, B and P*(pi, h, lambda). `price_star_usd_per_course()`
  evaluates the arm at each pi rather than assembling `A + pi*B`, so T3's
  affineness check is a real property test and not a tautology. A is
  computed by two code-disjoint routes for T1.
- R/analog_comparison.R: SPEC.md section 7's decayed quantity
  `pi_cure*exp(-h*t)` at each analog's own timepoint (T11).
- **T2 caught a real defect.** `value_of_one_cure_usd()` discounted B to the
  landmark while P* is a price paid at t=0 -- inconsistent reference points,
  a $1,102 gap at h=0.05. T1 and T3 both passed throughout; only the two
  independent routes to B exposed it. Fixed by denominating B at t=0.
- Four decisions SPEC.md did not settle, each recorded in SPEC_AMENDMENTS.md
  rather than made in code: pre-landmark window mortality-free (without it
  T4's "equals 1.00" is unreachable by construction), drug-free remission
  costing, relapsers charged a full standard-care course, and analogs
  reading out before the landmark marked incomparable rather than
  back-extrapolated.
- G2 narrowed to its documented defect class: flag two value-bearing
  suffixes only when they share a NUMERATOR and differ in denominator
  (`_usd_per_dose` vs `_usd_per_course` -- the ten Ham sidecar's recorded
  defect), not any two differing suffixes. The old rule flagged eight
  correct functions including every orchestrator; the W3 "exactly two"
  workaround was fragile and tripped on argument-count accident. Violation
  fixture updated to demonstrate the real defect class. Also exempted
  objects carrying a declared `denominator` attribute from the suffix
  requirement, since guard 3 governs those more strictly than a suffix
  would.
- Outputs stamped as price_frontier_w4.csv, value_of_one_cure_w4.csv and
  analog_comparison_w4.csv -- deliberately NOT SPEC.md section 6's aim
  filenames. A1-A3's content is computed here, but A4 (EVPI) and A5 (PSA)
  are W6; naming three of five aim files would arm G6 into a permanent
  failure for scheduling reasons rather than correctness ones. G6's skip
  message stays explicit and visible instead.
- Full suite: 127 assertions across 63 tests, 0 failures, 1 skip (G6 only).
  Tests cover T1, T2, T3, T4, T5, T7, T11, T12.
