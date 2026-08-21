# SPEC.md — TREG-VALUE

**Study:** What one durable regulatory T-cell (Treg) cure is worth in moderate-to-severe Crohn's disease, and the price that value implies at each plausible cure fraction and durability.

**Authors:** Jadambaa, Stone, Abraham (Johns Hopkins Bloomberg School of Public Health)
**Repository:** `treg-value`
**Version:** 1.1 — 2026-08-21
**Status:** Governing authority. This file supersedes every prior memo, code comment, README paragraph and conversation. Any departure from it is an entry in `SPEC_AMENDMENTS.md`, made in the same commit as the change it describes.

---

## 1. The equation

Every output is a consequence of one affine relationship.

```
P*(π, h, λ)  =  A(λ)  +  π · B(h, λ)
```

| Term | Definition | Unit |
|---|---|---|
| `P*` | Maximum justifiable price of one Treg course | `usd_per_course` |
| `π` | Cure fraction — share of **all treated patients** in sustained drug-free remission at the landmark | unitless; `denominator = all_treated` |
| `h` | Post-cure relapse hazard, continuous and ongoing | `per_year` |
| `λ` | Willingness to pay | `usd_per_qaly` |
| `A` | Net value accruing at π = 0: the deferral of the comparator induction course across the rescue window, less the health and non-drug cost penalty of that window | `usd_per_course` |
| `B` | **The headline quantity — what one durable cure is worth.** Discounted lifetime net monetary benefit of a cured patient less a patient on standard first-line biologic therapy | `usd_per_cure` |

`B` is the paper. The frontier, the required cure fraction at any benchmark price, and the value of information are reported as consequences of `B`.

---

## 2. Analytic frame

| | |
|---|---|
| Perspective | US healthcare sector |
| Currency year | 2025 USD |
| Discount rate | 3% annual, costs and QALYs |
| Cycle length | 2 weeks (native to Aliyev's DEALE-derived probabilities) |
| Horizon | Lifetime primary; 30-year and 40-year secondary |
| Reference comparator | Infliximab, biosimilar pricing base case |
| Secondary comparators | Ustekinumab, adalimumab — frontier checks only |
| Population | Single population: comparator dynamics as estimated in the source trials, which pool biologic-naïve and biologic-experienced patients rather than a uniform stratum. No refractory-adjusted population is run separately (§11 amendment, 2026-08-21) |
| WTP thresholds | $50,000 / $100,000 / $150,000 per QALY |
| Reporting standard | CHEERS 2022 |
| Study type | **Early health technology assessment.** Not a cost-effectiveness analysis. No efficacy data exist for this product in this indication and no ICER is reported |

---

## 2a. Budget impact frame — A6 only

§2 governs A1–A5 and is unchanged by this section. A6 answers a different
question — what a payer writes in cheques, and when — and needs commitments §2
refuses. They are stated here rather than folded into §2 so that no reader takes
a budget figure for a frontier figure.

| | |
|---|---|
| Perspective | US commercial payer (L14) |
| Reporting horizon | Base case 3 years; 1 and 5 reported as sensitivity — together these three are **the budget impact analysis proper**. 10 and 30 reported and separately labelled as an **extended offset-accrual projection**, which is not a budget impact analysis. A lifetime leg is retained as the reconciliation fixture (T13) and as the offset-capture denominator, and is never reported as a budget impact (L10) |
| Discounting | By horizon class (L11): 1/3/5 undiscounted base case with a 3% column; 10/30 and lifetime 3% base case with an undiscounted column. Both columns produced at every horizon |
| Denomination | Population-level annual dollars, and per member per month on a stated 1e6-member plan |
| Comparator displaced | Infliximab biosimilar base case, as §2 (L13); full treatment mix is S9 |
| Uptake | Linear ramp over a fixed 5-year ramp period to a swept terminal share; a single adoption wave, with no treatment after the ramp ends (L12, L15) |
| Population base | Eligible pool, held fixed (L16) — unsourced (O11); reported on a labelled illustrative schedule and as PMPM |
| Horizon semantics | The reporting horizon is **calendar-exact from t = 0** and is NOT the `horizon_years` argument of `run_comparator_trace()`, which governs the maintenance loop only and excludes the induction cycles that run before and in addition to it. The BIA's column is named `reporting_horizon_years` to keep the two distinguishable inside one `output/tables/` directory |
| Headline | A progression, not a figure: `offset_captured(H) = D(H) / D(lifetime)`, where `D(H)` is the discounted cumulative current-care-world-minus-Treg-world cost per treated patient excluding the course price, and `D(lifetime) = P*(π, h, λ = 0)`. λ does not enter — a budget holds no QALYs. It depends on π, h and the cap setting and not on the eligible population |
| Sign convention | Net budget impact is **positive when the Treg world costs the payer more** |
| Status | **Scenario-conditional.** Every A6 figure is conditional on a committed price, cure fraction, uptake level and reporting horizon, and is reported as a grid, never as a point estimate |

---

## 3. Model structure

Decision tree for induction using Aliyev's binary Response / No Response structure, feeding a cohort Markov model over six states — Remission, Mild, Moderate-Severe Responder, Moderate-Severe, Surgery, Death — on 2-week cycles, with background mortality from US life tables. The Treg arm adds a two-fate split at the landmark.

Induction accrues cost and QALYs as explicit cycles in every arm. It is not a free window.

---

## 4. Locked decisions

| # | Decision | Locked | Date | Rationale |
|---|---|---|---|---|
| **L1** | **Landmark: 12 weeks (cycle 6).** The two-fate split occurs at cycle 6; non-response is declared at cycle 6 | 2026-08-11 | Dula | Clinical rescue window. Supersedes the 52-week rationale in the retired analysis plan |
| **L2** | **π is unconditional on all treated patients.** Not conditional on remission, response, or track | 2026-08-11 | — | Commensurable with published analogs and with any future trial readout |
| **L3** | **Non-cured patients enter standard care in full** from cycle 6 — the comparator's transition probabilities *and* its drug, administration and monitoring costs, including the induction course a rescued patient clinically requires | 2026-08-11 | — | All value flows through the cure. Prevents an unearned intercept |
| **L4** | **Post-relapse: relapsed patients rejoin standard care.** Redosing is a named scenario (S3), not the base case | 2026-08-11 | Stone | Default is the conservative reading; redosing requires an efficacy premise no data supports |
| **L5** | **Infliximab induction window: run both week-4 and week-8 readings** as a scenario pair (S1) | 2026-08-11 | Stone | The published table gives IFX and ADA identical rows; the endpoint is inferred, not observed |
| **L6** | **Maintenance duration: report 2-year cap and no-cap as a bounding pair** on every primary output | 2026-08-11 | Stone | No persistence data exists in any sourced material. The conclusion must hold across both bounds, or the failure is stated |
| **L7** | **Single Treg dose per course.** Dose count affects the manufacturing benchmark only, never the frontier, which solves for price per course | 2026-08-11 | Stone | Any efficacy effect of a second dose is already absorbed by sweeping π |
| **L8** | **Manufacturing cost is a benchmark, never a model input.** No pricing function may read it | 2026-08-11 | — | The primary result must not depend on it. Enforced by a grep test |
| **L9** | **Pre-landmark trajectory: Treg patients follow conventional-therapy dynamics in weeks 0–12**, since no advanced therapy has been administered. They are not given infliximab's trajectory, and they are not charged for infliximab | 2026-08-11 | Stone | Granting the comparator's efficacy without its cost is the unearned intercept L3 exists to remove. This closes it on the efficacy side as L3 closes it on the cost side |

**Consequence of L9, recorded so it is not a surprise in a results table.** `A` is the discounted value of deferring one infliximab induction course by 12 weeks, *less* the health penalty of spending those 12 weeks on conventional therapy rather than infliximab. **`A` may be small and negative.** That is correct behaviour: a therapy that cures nobody has cost the patient a quarter-year of effective treatment. The frontier may therefore start below zero, and this is a stronger position than an intercept sitting at a few thousand dollars of unexplained savings. `T1` asserts `P*(0)` equals this quantity and nothing else, whatever its sign.

**L10–L16 govern A6 (the budget impact analysis) only.** No figure in A1–A5 depends on any of them.

| # | Decision | Locked | Date | Rationale |
|---|---|---|---|---|
| **L10** | **The reporting horizon is a stated analyst choice, not a swept parameter. Base case: 3 years**, with 1 and 5 years as the sensitivity range around it — together the budget impact analysis proper. 10 and 30 years are reported and separately labelled as an extended offset-accrual projection, which is not a budget impact analysis. A lifetime leg is retained as the T13 reconciliation fixture and as the offset-capture denominator and is never reported as a budget impact. **The horizon is a reporting boundary and never a model parameter: streams are computed once at the lifetime horizon and truncated at reporting time** | 2026-08-21 | Stone | CHEERS 2022 item 9 asks the analyst to state and justify a horizon. π and uptake are epistemic — facts nobody knows, so sweeping them is the honest response — but a time horizon is a normative reporting choice determined by the decision-maker's budget cycle, and declining to make it would be a refusal rather than a justification. Three years is the ISPOR/AMCP centre of mass; 1 and 5 bracket it. The extended projection exists because a short window applied to a one-time cure measures front-loading rather than affordability. **10 and 30 are round exploratory endpoints chosen for the readability of the offset-capture progression. They are not anchored to any figure this study publishes: no 30-year price frontier exists here to compare them against, every `A`, `B` and `P*` being computed at the lifetime horizon and only there.** The citations behind the ISPOR/AMCP and ICER readings are sourcing-register item S-8 and are not yet retrieved |
| **L11** | **The discounting convention follows the horizon's class, and that mapping is what is locked — not a rate.** Budget impact analysis proper (1/3/5 years): undiscounted base case, 3% reported alongside. Extended offset-accrual projection (10/30 years) and the lifetime reconciliation leg: 3% base case, undiscounted reported alongside. **Both columns produced at every horizon without exception** | 2026-08-21 | Stone | ISPOR's nominal-cash-flow argument applies to a budget forecast and not to a cost-accrual projection, so the crossover sits at the class boundary because that is where the object being reported changes. Undiscounting a backloaded offset over decades overstates it — the non-conservative direction. Under 3% the long arm converges to the lifetime leg where T13's identity holds exactly; undiscounted it converges to a quantity with no counterpart in this study. Producing both columns everywhere makes the convention a labelling decision about which figure the readout leads with rather than a computation that hides an alternative. **The base-case convention changes between the 5-year and 10-year rows of the same table; this is deliberate and is marked by a `discounting_base_case` column and a footnote** |
| **L12** | **Uptake shape locked, uptake level swept.** Cumulative share of the eligible population treated follows a linear ramp over a 5-year ramp period to a swept terminal share `u`. S-curve and immediate-full-uptake are the bounding scenario pair (S8) | 2026-08-21 | Stone | No uptake data exist for a product with no efficacy data, so a specific curve would be an assumption with no owner. **The 5-year ramp period is itself a chosen level, not structure**, recorded as an analyst's assumption under O12 rather than defended as a derivation. **The ramp period is held fixed across every reported horizon**, or the same terminal share would mean a different adoption speed at each horizon and the horizon comparison would be confounded with an uptake comparison |
| **L13** | **The comparator displaced is the same infliximab biosimilar base case (Q5104) as the frontier's.** The full current-treatment mix is S9, blocked on O13 | 2026-08-21 | Stone | Keeps the BIA reconcilable to `A` and `B`, which is what makes T13 possible; US market shares are unsourced. **Direction:** Q5104 is the cheapest of the three biosimilars (C10) and S5 showed ustekinumab and adalimumab comparators both raise `B`, so displacing the cheapest agent yields the smallest offset and the largest net budget impact — conservative for an affordability question |
| **L14** | **BIA perspective: US commercial payer**, distinct from §2's healthcare-sector perspective. The difference is the denominator and the horizon, not the unit costs | 2026-08-21 | Stone | Every unit cost here is already a payer payment amount — CMS ASP payment limits (C10) and CMS PFS national payment amounts (C9) — so the two perspectives coincide on inputs. Recorded so no reader infers that a second, differently-costed model was built. **Known gap:** ASP payment limits are not net-of-rebate commercial prices (O14) |
| **L15** | **Single adoption wave.** Cumulative treated caps at `u × N` at the end of the 5-year ramp; nobody is treated after year 5. Years 6 onward are pure offset accrual on the already-treated cohorts | 2026-08-21 | Stone | The alternative "flow" reading — the terminal annual rate persisting for the full horizon — would treat roughly six times the eligible pool over 30 years, incoherent with a pool held fixed (L16) unless incidence replenishes it, and incidence is unsourced (O15); that reading is **not well-defined until O15 closes**. A single wave is cleanly interpretable as one adoption wave followed by offset accrual, which is what the offset-capture progression measures, and leaves the 1/3/5-year horizons numerically unchanged since the ramp and those horizons coincide. **Direction:** a single wave produces the smaller long-horizon expenditure and therefore the more favourable-looking 30-year figure — the non-conservative direction, chosen for coherence rather than for conservatism. **T16 does not discriminate between the two readings**, so this decision has no mechanical guard and must be checked by reading the uptake function |
| **L16** | **The eligible pool is held fixed over the reporting horizon; no incidence or turnover is modelled** | 2026-08-21 | Stone | Defensible over 1–5 years, where incidence is second-order against a pool level that is itself entirely unsourced. **Not defensible at 10 and 30 years, and stated as a limitation there rather than absorbed** (O15). Interacts with L15: under a single adoption wave a fixed pool is drawn down toward `u` and never replenished |

The decision set is closed. No item in `SPEC.md` awaits a co-author.

---

## 5. Swept parameters and scenario grid

Swept, not assumed. No prior is placed on any of these.

| Parameter | Grid |
|---|---|
| `π` | 0 to 1, 101 points |
| `h` | 0% / 5% / 10% per year |
| `λ` | $50k / $100k / $150k per QALY |
| Horizon | Lifetime / 30-year / 40-year |
| Maintenance cap | On (2-year) / off |
| `u` (terminal uptake share of the eligible pool) — A6 only | 0 to 1; 0 and 1 must both be present (T16) |
| BIA price — A6 only | `P*(π, h, λ)` from A2, plus a separately-labelled axis of observed analog list prices |

The A6 **reporting horizon is not swept** and is deliberately absent from this table: L10 makes it a stated analyst choice with a designated base case, not a parameter with a prior.

| Scenario | Content |
|---|---|
| S1 | Infliximab induction window: week 4 vs week 8 |
| S3 | Redosing on post-cure relapse |
| S4 | Originator infliximab pricing |
| S5 | Ustekinumab and adalimumab as reference comparator |
| S6 | Administration bundle included (infusion, preconditioning, observation stay) |
| S7 | Pre-pandemic life-table vintage |
| S8 | Uptake shape: linear / logistic / immediate full uptake (A6) |
| S9 | Current-treatment-mix comparator in place of infliximab alone (A6) — blocked on O13 |

---

## 6. Aims and their outputs

Per guard G6, every aim maps to a named output file. An aim with neither an output nor an amendment fails `test-aims-covered.R`.

| Aim | Statement | Output file |
|---|---|---|
| **A1** | What one durable cure is worth | `output/tables/value_of_one_cure.csv` |
| **A2** | Maximum justifiable price per course across π, h and λ | `output/tables/price_frontier.csv` |
| **A3** | Required cure fraction at each manufacturing benchmark, on the all-treated denominator, with the analog comparison on matched timepoints (§7) | `output/tables/required_cure_fraction.csv` |
| **A4** | Per-patient EVPI and break-even eligible population, arithmetic shown | `output/tables/voi_breakeven.csv` |
| **A5** | Probabilistic analysis over π, h, comparator prices, transition rows sampled whole, and health-state costs | `output/tables/psa_summary.csv` |
| **A6** | Payer budget impact at a 3-year base-case horizon with a reported 1–30 year range, across the price, cure-fraction and uptake grid, with the share of lifetime cost offset captured at each horizon, reported as scenario-conditional cells with the required cure fraction attached to each | `output/tables/budget_impact.csv` |

---

## 7. The analog comparison rule

π is assessed at 12 weeks. Published analogs report at their own timepoints — PolTREG PTG-007 at 24 months, Ovasave/CATS1 at week 8. **Comparing π directly against those figures is the same class of error as a conditional denominator: the right number against the wrong reference point.**

The comparison is therefore made on the derived quantity

```
still_in_drug_free_remission(t) = π · exp(−h · t)
```

evaluated at each analog's own timepoint, never on π itself. An acceptance test asserts this.

---

## 8. Parameter register

| Parameter | Value | Status | Source |
|---|---|---|---|
| Transition probabilities, induction | — | **TRANSCRIBE** | Aliyev 2019 Suppl. Table 3 |
| Transition probabilities, maintenance | — | **TRANSCRIBE** | Aliyev 2019 Suppl. Table 4 |
| Health-state costs | — | **RE-DERIVE** | Aliyev Appendix S2 via PMPM→cycle (14/30.44) × cost trend (1.03⁹) ≈ 0.600×, then re-based to 2025 |
| Utilities | — | **TRANSCRIBE** | Aliyev / Buxton EQ-5D-to-CDAI algorithm |
| Infliximab biosimilar unit cost | — | **TO SOURCE** | CMS ASP, current quarter |
| Administration cost | — | **TO SOURCE** | CMS Physician Fee Schedule, CPT 96365 |
| Surgery-state cost | — | **RE-DERIVE** | Aliyev Suppl. Table 2 Severe-Fulminant PMPM, through the same conversion as every other health state. Not an episode cost; not a colectomy |
| Life table | — | **TO SOURCE** | NCHS, vintage stated |
| Observation stay | — | **TO SOURCE** | CMS OPPS APC 8011 |
| Treg dose (cells/kg) | — | **TO SOURCE** | RESTORE protocol, NCT06721962. Benchmark only |
| Manufacturing benchmark | Range | **TO BUILD (W5)** | Triangulated: analogy anchors, techno-economic bottom-up, revealed prices. Margin sourced, not invented |
| US eligible population, moderate-to-severe CD (A6) | — | **TO SOURCE** | O11 / register item S-6. Prevalence × severity share × a swept eligibility fraction; the third link is not sourceable for a product with no label and is swept, not assumed |
| Uptake trajectory (A6) | Linear ramp, 5-year ramp period, terminal share swept | **SWEPT** | O12 / register item S-7. Shape locked by L12; no uptake-analogy leg is built |
| Plan membership for PMPM (A6) | 1e6 members | **STATED CONVENTION** | A labelled denominator for reporting per-member-per-month, not an estimate of any real plan |

---

## 9. Open items — no defaults permitted (guard G7)

Anything listed here is a required argument. Functions refuse to run rather than assume.

| # | Item | Effect |
|---|---|---|
| O1 | Eligible population fractions | A4 reports break-even threshold only until sourced |
| O2 | Confirmatory trial cost benchmark | A4 comparison |
| O3 | Preconditioning dose | S6 only |
| O4 | Whether a Treg infusion qualifies for observation billing | S6 only |
| O5 | Real-world biologic persistence | Would replace L6's bounding pair |
| O6 | Productivity costs in a societal scenario | Out of base case |
| O11 | US eligible population for a one-time allogeneic Treg course in moderate-to-severe CD — a count, not a fraction | A6 reports on a labelled illustrative schedule and as PMPM meanwhile |
| O12 | Adoption/uptake trajectory for a first-in-class one-time cell therapy in a chronic non-oncology indication | A6's uptake level swept; S8 reports the shape pair |
| O13 | US market shares across advanced therapies in moderate-to-severe CD | S9 only |
| O14 | Net-of-rebate commercial price relative to the ASP payment limit | A6 level; direction stated |
| O15 | Eligible-population incidence and turnover over a 10–30 year window | Extended projection only; also blocks the "flow" uptake reading L15 rejects |

---

## 10. Acceptance criteria

| Test | Assertion |
|---|---|
| T1 | `P*(0)` equals `A` computed independently from sourced unit prices and the 12-week window, to within $1 |
| T2 | `(P*(1) − P*(0)) == B`, and `B` recomputed directly as the cured-versus-standard-care NMB difference agrees to within $1 |
| T3 | `P*(π)` linear across the 101-point grid; deviation under $0.01 |
| T4 | At π = 1, the share of the **treated cohort** in drug-free remission at cycle 6 equals 1.00 |
| T5 | `P*` strictly decreasing in `h`, strictly increasing in `λ`; `B` decreasing in `h` |
| T6 | Every exported numeric carries a unit suffix; cross-unit arithmetic routes through a named converter |
| T7 | State vectors sum to 1.00 ± 1e-10, every cycle, every arm, every horizon |
| T8 | Undiscounted life-years match life-table expectation within 1 year |
| T9 | Every `data/derived/` value re-derives from `data/raw/`; every raw file has a resolving `.source.yaml` |
| T10 | Every aim in §6 has an output file or a signed amendment |
| T11 | The analog comparison uses `π · exp(−h·t)` at each analog's timepoint, never π |
| T12 | No pricing function reads the manufacturing benchmark (grep, zero call sites) |
| T13 | At λ = 0, on the lifetime reconciliation leg, with 3% discounting and a single cohort treated at t = 0, the BIA's discounted net budget impact per treated patient equals `price − P*(π, h, λ = 0)` to within $1. The lifetime leg exists for this test and is never reported as a budget impact |
| T14 | Net budget impact per treated patient is affine in π across the 101-point grid at every reported horizon; deviation under $0.01. **On the lifetime leg only**, the slope equals exactly `−B(h, λ = 0)` and the intercept `price − A(λ = 0)` |
| T15 | In each world separately, **gross** annual expenditure undiscounted ≥ discounted, per year and cumulatively, at every horizon; cumulative gross expenditure in each world is non-decreasing in horizon length. **No sign is asserted for the discounting effect on the net series, and no monotonicity is asserted for net budget impact or for `offset_captured(H)` in the horizon** |
| T16 | At uptake `u = 0` the two worlds' annual budgets are identical to the cent in every year at every horizon, and net budget impact is exactly $0. Net budget impact scales exactly linearly in the number treated |
| T17 | Per-cycle cost streams sum to the pre-existing scalar `discounted_cost_usd` in both `run_comparator_trace()` and `run_treg_trace()`, to within 1e-6, for every induction window and cap setting |
| T18 | **Independent-route horizon truncation.** For each reported horizon H and every window/cap combination, `run_comparator_trace("IFX", w, cap, H)$discounted_cost_usd` equals the prefix sum of the lifetime stream through cycle `induction_cycles + round(H · ALIYEV_CYCLES_PER_YEAR)` — the index that reproduces that argument's own semantics (§2a), not the calendar-exact reporting boundary — to within 1e-6. Additionally, `sum(interpolated stream) == interpolated total` from `standard_care_at_age()`, at a set of non-integer ages including the landmark age |

**T13–T18 belong to A6.** T17 and T18 govern the engine capability A6 rests on — per-cycle cost streams and their truncation — and are the reason a horizon never reaches the Treg arm as an argument. **Monotonicity in the horizon is deliberately not asserted at any relapse hazard, including h = 0**: a relapser re-entering standard care starts a second induction course and their own cap clock, and independently of any relapse the Treg cohort's 12-week landmark deferral (L9) shifts its 2-year cap clock 12 weeks later than the comparator world's, so there is a window in which the Treg world pays biologic and the comparator world does not. A passing monotonicity test would mean one of those two has stopped being charged.

**T1 and T2 are the gate.** They are the intercept and the slope stated as properties rather than as values, which is why they cannot pass on a false premise.

---

## 11. Amendment procedure

Changes to this file require an entry in `SPEC_AMENDMENTS.md` recording the date, the person signing off, what is superseded, and why — committed alongside the change. A scope reduction that drops an aim from §6 is an amendment, not a decision made in code.

Every output file carries the git commit hash and the SHA-256 of this file at run time. A run whose spec hash differs from the last committed one fails.
