# SPEC.md — TREG-VALUE

**Study:** What one durable regulatory T-cell (Treg) cure is worth in moderate-to-severe Crohn's disease, and the price that value implies at each plausible cure fraction and durability.

**Authors:** Jadambaa, Stone, Abraham (Johns Hopkins Bloomberg School of Public Health)
**Repository:** `treg-value`
**Version:** 1.0 — 2026-08-11
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
| Population | Biologic-naïve base case; refractory co-primary, run identically |
| WTP thresholds | $50,000 / $100,000 / $150,000 per QALY |
| Reporting standard | CHEERS 2022 |
| Study type | **Early health technology assessment.** Not a cost-effectiveness analysis. No efficacy data exist for this product in this indication and no ICER is reported |

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

### L9 — Pre-landmark trajectory (**requires sign-off before W4**)

Weeks 0–12 in the Treg arm: what disease dynamics apply before the split?

- (a) Treg follows infliximab's trajectory — grants biologic efficacy without charging for a biologic. This is the unearned intercept in a new place.
- (b) **Treg follows conventional-therapy dynamics**, since no advanced therapy has been administered. **Recommended.**
- (c) Treg has its own assumed pre-landmark effect — unsourceable.

**Consequence of (b), stated plainly:** `A` becomes the discounted value of deferring one infliximab induction course by 12 weeks, *less* the health penalty of 12 weeks on conventional therapy rather than infliximab. **`A` may be small and negative.** That is correct behaviour — a therapy that cures nobody has cost the patient a quarter-year of effective treatment — and it is a stronger position than an intercept sitting at a few thousand dollars of unexplained savings. Co-authors should sign off knowing the frontier may start below zero.

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

| Scenario | Content |
|---|---|
| S1 | Infliximab induction window: week 4 vs week 8 |
| S2 | Refractory population, run identically to base case |
| S3 | Redosing on post-cure relapse |
| S4 | Originator infliximab pricing |
| S5 | Ustekinumab and adalimumab as reference comparator |
| S6 | Administration bundle included (infusion, preconditioning, observation stay) |
| S7 | Pre-pandemic life-table vintage |

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
| Surgery cost | — | **TO SOURCE** | HCUPnet colectomy |
| Life table | — | **TO SOURCE** | NCHS, vintage stated |
| Observation stay | — | **TO SOURCE** | CMS OPPS APC 8011 |
| Treg dose (cells/kg) | — | **TO SOURCE** | RESTORE protocol, NCT06721962. Benchmark only |
| Manufacturing benchmark | Range | **TO BUILD (W5)** | Triangulated: analogy anchors, techno-economic bottom-up, revealed prices. Margin sourced, not invented |

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

**T1 and T2 are the gate.** They are the intercept and the slope stated as properties rather than as values, which is why they cannot pass on a false premise.

---

## 11. Amendment procedure

Changes to this file require an entry in `SPEC_AMENDMENTS.md` recording the date, the person signing off, what is superseded, and why — committed alongside the change. A scope reduction that drops an aim from §6 is an amendment, not a decision made in code.

Every output file carries the git commit hash and the SHA-256 of this file at run time. A run whose spec hash differs from the last committed one fails.
