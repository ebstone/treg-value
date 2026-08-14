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

## 2026-08-13 (CHEERS 2022 compliance)
- data/raw/cheers_2022_checklist.csv holds all 28 items transcribed verbatim
  from the open-access statement, with sidecar, so the assessment is made
  against the standard's own wording rather than a paraphrase.
- analysis/run_cheers_assessment.R classifies each item as satisfied by a
  repository artifact (20), a manuscript matter (4), a genuine gap (3), or
  partial (1), each with named evidence. Stamped to
  output/tables/cheers_2022_compliance.csv.
- Item 24 asks for the effect of the choice of discount rate as well as time
  horizon. Time horizon was already varied; discount rate was not. The rate
  now reads from an option so a run can vary it without threading a rate
  argument through every function that discounts, and 0% and 5% are run as
  scenarios alongside SPEC.md's 3% base case.
- Three gaps are recorded rather than papered over, and none is something an
  analysis repository can close: item 19 (distributional and equity effects,
  not analysed), item 21 (no patient, public, clinician or payer engagement
  in study design), and item 25 (consequent on 21). Item 26 is partial --
  limitations exist, ethical and equity considerations and generalisability
  do not.
- Full suite: 344 assertions across 94 tests, 0 failures, 0 skips.

## 2026-08-13 (final readout)
- docs/results_readout.html: the co-author readout, versioned alongside the
  analysis rather than living only as a published artifact. Headlines the
  $100,000-$150,000 per QALY range that US value assessment conventionally
  treats as the benchmark for a value-based price, with $50,000 retained
  throughout as a conservative floor.
- Carries the manufacturing benchmark and aim A3, the refractory co-primary,
  the full robustness grid (comparator drug, originator pricing, life-table
  vintage, discount rate), probabilistic intervals and per-patient EVPI.
- One precision point recorded: the "no cure fraction justifies this product
  at autologous cost of goods" finding holds at $100,000 per QALY at every
  hazard, but at $150,000 a permanent cure requires 83.1%, which is
  arithmetically attainable. The claim is threshold-dependent and is now
  stated that way rather than absolutely.

## 2026-08-13 (adversarial review fixes)
- Maintenance dose cost was charged to the whole biologic cohort including its
  accumulated Death mass, so dead patients were billed infusion drug plus
  administration on every dose cycle. Death is absorbing in the maintenance
  matrix and the Moderate-Severe redirect gives it no exit path, so the error
  grew across the horizon. `one_cycle_cost_usd()` now charges living biologic
  mass only, mirroring the conventional-therapy drug cost on the adjacent line.
  Covered by a new property test in tests/testthat/test-markov-engine.R
  asserting that adding Death mass to the start-of-cycle vector cannot change
  the cycle cost, that the charge scales with living mass, and that a fully
  dead cohort is charged nothing; the test fails against the previous code.
  Effect on reported figures: comparator lifetime cost falls $495.00 with the
  maintenance cap off and $5.35 with it on; A moves $1.71, B moves $111.34,
  and P* at a cure fraction of 1 rises $113.06 (cap off, $100k/QALY, h=0.05).
  The bug was conservative -- it understated the justifiable price.
- derive/parse_nchs_life_table.R no longer takes hard-coded line ranges. It
  locates Table 1 by scanning for the first contiguous age 0-100 block, which
  removes a dependence on poppler version that had gone stale and made the
  documented 2023 command select an unrelated table and crash. The age-row
  regex now matches the interval separator literally instead of via an
  unescaped wildcard, the pdf path is shQuote-d, a row parsing to too few
  numeric fields raises an error naming the file and line, and duplicate ages
  are a hard error rather than being silently deduplicated. Verified by
  round-tripping data/raw/nchs_life_table_2023.csv through synthesised
  pdftotext output carrying both decoys that defeated the old parser.
- {digest} installed to the user library: G1 (provenance) and G5 (stamping)
  had been skipping silently for want of it, so two guards were inert. Suite
  now runs 349 assertions with no skips.

## 2026-08-14 (transcription audit; C8 reconciled)
- Audited every Aliyev-derived figure in data/raw/ against the source appendix
  PDFs. Supplementary Table 2 (59 rows: parameter, base-case value, alpha,
  beta) compared mechanically and matches in full; Supplementary Tables 3
  (induction), 4 (maintenance, all of UST/IFX/ADA/CT) and 5 (costs, utilities,
  unit costs, discount rate, indirect costs) are images in both the PDF and the
  DOCX, so they were rendered and read cell by cell. Every value matches. The
  appendix DEALE worked example independently reproduces the induction figure
  0.133, and the renormalised induction rows the engine produces are exactly
  the published rows divided by their own stated totals.
- C8 is reconciled and the reason recorded as C8a. The $7.40 Moderate-Severe
  gap was never unexplained: Appendix S2 page 3 builds that one state as its
  PMPM mean total cost minus its own mean pharmacy cost plus the Mild-moderate
  mean pharmacy cost. Under the same conversion, (374 - 123 + 111) * 0.60009 =
  $217.23 against Table 5's $217, a $0.23 gap rather than $7.40. C8's decision
  was correct on its own terms and no reported figure changes; only its stated
  reason was incomplete. Now covered by a provenance re-derivation test in
  tests/testthat/test-health-state-costs.R that also asserts the appendix rule
  beats the plain rule, so it cannot pass for the wrong reason.
- Not audited: the non-Aliyev sources (CMS ASP, NCHS life tables, ten Ham 2020,
  cell-therapy list prices, medical-care CPI, EUR/USD). Their source documents
  are not on the machine.

## 2026-08-14 (round-2 review fixes)
- Scenario S7 mixed life-table vintages: `value_of_one_cure_usd()` had no
  vintage argument and silently used the base 2023 table while S7 built its
  grid and comparator on the pre-pandemic 2019 one, so the cured stream and
  the standard care it is differenced against came from different mortality
  regimes. Threaded through `value_of_one_cure_usd()`,
  `price_star_usd_per_course()`, `frontier_intercept_from_model()` and
  `run_treg_trace()`. S7 B moves $167,229 to $172,606 and its required cure
  fraction 24.7% to 24.0% — the base-case figure, so the apparent sensitivity
  to the mortality table was the defect. scenarios.csv and the readout are
  regenerated and the readout sentence corrected. See SPEC_AMENDMENTS.md.
- G6 aim-coverage guard: `parse_aims_table()` stripped backticks from the
  output column but not bold markers from the Aim column, so aim IDs compared
  against SPEC_AMENDMENTS.md carried `**` and could never match its unbolded
  convention. The amendment branch was unreachable, passing only because every
  aim output happens to exist and short-circuits the check. The violation
  fixture wrote IDs unbolded and so exercised a shape SPEC.md never produces.
  Markers are now stripped, the fixture uses SPEC.md's own formatting, and it
  gained an A3 that is amended but has no output file — covered by a new test
  asserting the amendment branch clears it, which fails against the old parser.
- Both found by ultra review round 2. Neither the standard_care_grid()
  exactness question nor the state_sums conservation question was examined by
  that review; both remain open.

## 2026-08-14 (standard_care_grid verification)

- Answered the two questions the round-2 review brief made its priority and
  which neither ultra run addressed.
- **The analytic grid accounting is not exact.** `standard_care_at_age()`
  interpolates linearly between integer ages, and discounted lifetime cost is
  not linear in starting age. Measured against directly computed traces the
  error runs about $3 at age 35 to $23 at 95, up to $255 in net monetary
  benefit. Rebuilding the grid at quarter-year steps moves `A` about $70
  (-$2,655 to -$2,585, 2.7%), `B` about $74 (0.04%), and the required cure
  fraction from 24.00% to 23.97%; `P*(1)` does not move, the landmark lookup
  being common to `A` and `B` and cancelling in their sum. Left at one-year
  steps deliberately and the magnitude recorded in `R/treg_arm.R` instead: no
  conclusion turns on it, and superseding a published `A` for it is not worth
  the churn. Adding one grid point at the landmark age would recover 58% for a
  single extra run if that trade is ever wanted.
- **T7's state-sum invariant proves less than it reads.** In the Treg arm the
  three tracked quantities are running scalars and each cycle moves mass
  between them, so their total is invariant as an algebraic identity. Pricing
  every relapser at age 35, doubling standard-care cost, and inflating relapser
  QALYs by half each leave `max|state_sum - 1|` at 1.554e-15 -- unchanged to
  the last digit -- while `P*(0.5)` changes sign twice. T7 is a check that no
  mass is dropped between buckets and nothing more; the test now says so.
- Added the falsifiable companion T7 was missing: perturbing the standard-care
  grid only at ages a relapser can reach must leave the no-relapse case
  untouched and must move the relapsing case. Verified it fails against both
  corruptions T7 sleeps through -- a fixed-age lookup and a handoff that never
  charges.
- No reported figure changes, so no amendment. Suite: 367 passing, 0 failures,
  0 skips.
- Standing count: three of the twelve acceptance criteria cannot fail as
  written -- T3 (pi enters once as a scalar, so linearity is arithmetic), T7
  (above), and T1 partially (both routes to `A` share the grid and the
  pre-landmark loop, so they carry identical errors and agree anyway).

## 2026-08-14 (T1 and T3 made to bind)

- **T3 anchored on independently computed A and B.** It previously fitted a
  line to its own first and last observations and checked the interior, which
  `pi_cure` entering the arm at one line as a scalar makes true by arithmetic.
  Measured: that form passed at deviation ~2e-08 with the relapse hazard
  doubled, with cured-patient costs inflated tenfold, and with `pi` applied to
  a subset rather than all treated. It now compares the observed frontier
  against `frontier_intercept_independent()` plus `pi` times
  `value_of_one_cure_usd()`. Against the subset denominator -- the defect this
  project has suffered twice -- the old form passes at 1.73e-08 and the new one
  fails by $137,636.
- **T1's second route no longer duplicates the first.** The independent
  intercept accumulated the pre-landmark window with the same cycle-by-cycle
  loop `run_treg_trace()` uses, written out twice, so a mistake made once and
  copied reproduced itself in both. The window is now summed as a matrix
  series with no cycle loop. Measured: dropping the half-cycle correction from
  the helper both routes called left the old T1 passing at exactly 0.00; the
  closed form disagrees by $180.93.
- T1's remaining limit is recorded in the test rather than left implicit: a
  wrong shared constant is still invisible. Setting the rescue window to 7
  cycles moves `A` by $232.83 and T1 passes at 0.00, because both routes read
  `LANDMARK_CYCLES` and are each faithful to it. No cross-check validates its
  own inputs.
- No reported figure changes -- the closed form reproduces `A` to floating
  point, verify_readout.R passes, and no output table moved. Suite: 368
  passing, 0 failures, 0 skips.
- Standing count updated: of the three acceptance criteria previously unable to
  fail, T3 and T1 now bind, and T7 is honestly described with a falsifiable
  companion alongside it.
