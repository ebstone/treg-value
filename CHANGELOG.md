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

## 2026-08-13 (comparator pricing decided)
- OPEN_QUESTIONS.md O8 closed as C10: the reference comparator's base case is
  priced on Q5104 (Renflexis) at $2.6615/mg, the current CMS ASP payment
  limit. Recorded in SPEC_AMENDMENTS.md; unresolved item U3 in the ASP
  sidecar resolved, leaving that file with none. Q5104 was already the value
  carried in R/dosing.R pending the decision, so no reported figure changes
  -- the input is now decided and justified rather than inherited. It is the
  lowest priced of the three biosimilars, which makes the comparator arm
  cheapest and B and P* smallest: the conservative direction. Originator
  J1745 prices scenario S4.
- Full suite unchanged: 127 assertions across 63 tests, 0 failures, 1 skip.

## 2026-08-13 (currency re-basing and probabilistic analysis)
- All costs re-based to 2025 USD (SPEC.md section 2's stated currency year,
  previously unimplemented) through medical-care CPI, added as
  data/raw/cpi_medical_care_annual.csv. Re-basing lives at the R/ boundary
  so derive/ keeps reproducing Aliyev's figures in Aliyev's dollar year and
  its provenance test stays valid. Amendment recorded; every dollar figure
  moves (A -$2,507 -> -$2,655; B at h=5%, $100k $160,997 -> $172,042).
- Engine optimised 5.6x (0.474s -> 0.085s per lifetime trace): age-adjusted
  matrices cached per integer age band, per-state transition loop replaced
  with a matrix multiply, state-sum logs preallocated, memoised CSV reader
  (R/io_cache.R) since every loader re-read its file on every call. Results
  unchanged to 1.7e-7 relative.
- R/psa.R + analysis/run_psa.R: probabilistic analysis (A5) over health-state
  costs, utilities, comparator price and transition rows sampled whole --
  every distribution Aliyev's own, from Suppl. Table 2's alpha/beta columns.
  pi_cure, h and lambda are NOT sampled: SPEC.md section 5 places no prior
  on them, so the PSA is conditional on a stated (pi, h, lambda) and a
  distribution over pi_cure would be a new assumption requiring an
  amendment. 1000 draws; one draw serves all 27 (lambda, h) combinations
  because neither changes the sampled model.
- Per-patient EVPI over the sourced parameter uncertainty at an illustrative
  price and cure fraction (part of A4). The break-even eligible population
  A4 also asks for remains blocked on O1 and O2, both unsourced.
- G5 strengthened: the source-text ban on write.csv now applies to analysis/
  only (R/psa.R legitimately writes sampled model INPUTS to scratch), and is
  replaced for R/ by a direct assertion that every file in output/ actually
  carries a commit hash and a SPEC.md hash -- an outcome test rather than a
  grep for a function name, with a violation fixture.
- Full suite: 210 assertions across 71 tests, 0 failures, 1 skip.

## 2026-08-13 (W5: manufacturing benchmark, and all five aims)
- R/manufacturing_benchmark.R + analysis/run_manufacturing_benchmark.R:
  triangulated benchmark from ten Ham analogy anchors (2018 EUR converted at
  the source year's rate, then re-based to 2025 USD) and reported autologous
  CAR-T cost of goods. Two new sourced inputs with sidecars: the FRED
  USD/EUR series and approved cell-therapy list prices. $12,266-$380,336 per
  course; allogeneic anchors $12,266-$68,958, median $38,634.
- The techno-economic bottom-up leg is NOT built: the Treg dose in cells/kg
  is not public (all three registered TRX103 trials disclose only "Dose
  level 1/2/3"), and inventing it would defeat the benchmark's purpose.
  Recorded as an amendment rather than filled with an assumption.
- Aim A3 satisfied: required cure fraction at each benchmark, all-treated
  denominator, with the section 7 analog comparison on matched timepoints.
  Headline: at allogeneic batch-amortised cost 4.2-13.6% suffices at
  $100k/QALY, but at autologous CAR-T cost of goods the required fraction
  exceeds 100% at every hazard -- no cure fraction justifies the product on
  that manufacturing model.
- analysis/run_aims.R writes all five SPEC.md section 6 aim outputs under
  their designated filenames. A4 reports per-patient EVPI plus the
  break-even population as the arithmetic A4 asks to show (N = trial cost /
  per-patient EVPI) across a schedule of trial costs, since O1 and O2 are
  both unsourced.
- **G6 had never been able to bind.** SPEC.md writes each aim's output path
  in markdown backticks, which parse_aims_table() carried through, so every
  file.exists() check tested a path that could not exist and every aim would
  have been reported uncovered no matter what was produced. Fixed, with a
  regression test asserting the parsed paths carry no backticks. T12 also
  strengthened: it now greps five pricing-path files against every name the
  benchmark module exports, rather than two files against a keyword list.
- Full suite: 280 assertions across 77 tests, 0 failures, 0 skips -- the
  first run in this project with nothing skipped.

## 2026-08-13 (refractory co-primary population)
- SPEC.md section 2 makes the refractory population co-primary, not a
  sensitivity analysis, and nothing implemented it. Now built:
  data/raw/uniti_induction_outcomes.csv holds UNITI-1 and UNITI-2 per-arm
  counts read from the ClinicalTrials.gov results API (counts stored, not
  pre-divided rates, so every downstream figure is auditable to a numerator
  and denominator). R/refractory.R derives the multipliers and applies them
  to induction; `population` threads through the engine, the standard-care
  grid and the frontier.
- Provenance confirmation worth keeping: Aliyev's UST week-6 response
  parameter is Beta(116, 93), and UNITI-2's 6 mg/kg arm reports exactly 116
  responders of 209 with 93 non-responders. The inherited base case IS
  UNITI-2, so UNITI-1 is its correct refractory counterpart. Asserted as a
  test rather than left as a coincidence.
- Adjustment is induction-only. IM-UNITI randomised week-8 responders, so
  its maintenance rates are conditioned on induction success and would
  reintroduce the conditional-denominator error in a new place. Recorded as
  OPEN_QUESTIONS.md O10 and as an amendment.
- Consequence recorded explicitly: the two co-primary populations currently
  differ by under 1% on B (0.46% cap on, 0.73% cap off), because an
  induction-only adjustment acts over four cycles of a sixty-five-year
  horizon and the two-year cap returns both populations to conventional
  therapy anyway. That is a statement about available evidence, not a
  finding that the populations are alike.
- Full suite: 302 assertions across 85 tests, 0 failures, 0 skips.

## 2026-08-13 (scenarios S4, S5, S7)
- S4 (originator infliximab pricing): the priced product now threads through
  the engine and the standard-care grid. J1745 costs $1,166/dose against
  Q5104's $999.
- S7 (pre-pandemic life-table vintage): data/raw/nchs_life_table_2019.csv
  added with sidecar; load_life_table() takes a vintage. A parsing trap
  found and recorded -- the 2019 report writes its terminal row as "100 and
  over" where the 2023 report writes "100 and older", so a parser matching
  only the newer wording silently drops the absorbing row and yields a
  100-row table whose cohort never exhausts. Both spellings accepted; row
  count and terminal row asserted.
- S5 (ustekinumab / adalimumab as reference comparator):
  data/raw/biologic_dosing_regimens.csv transcribed from the FDA labels via
  the openFDA API, R/comparator_dosing.R turns a regimen into an engine
  dosing plan, and the engine now consumes a plan rather than hardcoded
  infliximab dosing. Ustekinumab's induction is vial-banded (three 130 mg
  vials at 70 kg), adalimumab's two induction doses differ in size (four
  syringes then two), and subcutaneous maintenance carries no infusion fee.
- analysis/run_scenarios.R runs all three and stamps output/tables/scenarios.csv.
- S3 and S6 deliberately not built, recorded as an amendment: S3 would
  require assuming a redose cure probability, which is the parameter being
  solved for; S6 is blocked on O3 and O4, both unsourced.
- Full suite: 331 assertions across 92 tests, 0 failures, 0 skips.
