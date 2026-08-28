# SPEC.md — TREG-VALUE

**Study:** What one durable regulatory T-cell (Treg) cure is worth in moderate-to-severe Crohn's disease, and the price that value implies at each plausible cure fraction and durability.

**Authors:** Jadambaa, Stone, Abraham (Johns Hopkins Bloomberg School of Public Health)
**Repository:** `treg-value`
**Version:** 1.2 — 2026-08-23
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

## 2a. Budget impact frame — A6 and A7's budget leg

§2 governs A1–A5 and is unchanged by this section. A6 answers a different
question — what a payer writes in cheques, and when — and needs commitments §2
refuses. They are stated here rather than folded into §2 so that no reader takes
a budget figure for a frontier figure. **A7's budget leg is governed by this
section unchanged; A7's per-cure frontier is governed by §2.**

| | |
|---|---|
| Perspective | US commercial payer (L14) |
| Reporting horizon | Base case 3 years; 1 and 5 reported as sensitivity — together these three are **the budget impact analysis proper**. 10 and 30 reported and separately labelled as an **extended offset-accrual projection**, which is not a budget impact analysis. A lifetime leg is retained as the reconciliation fixture (T13) and as the offset-capture denominator, and is never reported as a budget impact (L10) |
| Discounting | By horizon class (L11): 1/3/5 undiscounted base case with a 3% column; 10/30 and lifetime 3% base case with an undiscounted column. Both columns produced at every horizon |
| Denomination | Population-level annual dollars, and per member per month on a stated 1e6-member plan |
| Comparator displaced | Infliximab biosimilar alone, as §2 (L13). No current-treatment-mix comparator is built — US market shares are unsourced — and the single-comparator assumption is a stated limitation whose bias direction is known and conservative (§11 amendment, 2026-08-28) |
| Uptake | Linear ramp over a fixed 5-year ramp period to a swept terminal share; a single adoption wave, with no treatment after the ramp ends (L12, L15) |
| Population base | Eligible pool, held fixed (L16) — unsourced (O11); reported on a labelled illustrative schedule and as PMPM |
| Horizon semantics | The reporting horizon is **calendar-exact from t = 0** and is NOT the `horizon_years` argument of `run_comparator_trace()`, which governs the maintenance loop only and excludes the induction cycles that run before and in addition to it. The BIA's column is named `reporting_horizon_years` to keep the two distinguishable inside one `output/tables/` directory |
| Headline | A progression, not a figure: `offset_captured(H) = D(H) / D(lifetime)`, where `D(H)` is the discounted cumulative current-care-world-minus-Treg-world cost per treated patient excluding the course price, and `D(lifetime) = P*(π, h, λ = 0)`. λ does not enter — a budget holds no QALYs. It depends on π, h and the cap setting and not on the eligible population |
| Sign convention | Net budget impact is **positive when the Treg world costs the payer more** |
| Status | **Scenario-conditional.** Every A6 figure is conditional on a committed price, cure fraction, uptake level and reporting horizon, and is reported as a grid, never as a point estimate |
| Payment arrangement | Base case: a single payment in the adoption year, as A6 (L7). Alternatives — installment schedules, outcome-conditioned payment, and the offset-matched reference schedule — are reported as labelled arrangements and never replace the base case (L17, L19) |
| Outcome observation | The rebate trigger's timepoint, measured from the landmark (L19). **NOT** the reporting horizon and **NOT** `run_comparator_trace()`'s `horizon_years`: three time axes now coexist in `output/tables/`, and the column is named `outcome_observation_years` for that reason |
| Settlement timing | A conditional payment triggered at observation point `T` settles at patient-time `T + 12/52` years from adoption, carries that date's discount factor, and is placed at that calendar index (L21) |
| Justification test | An arrangement is justified **iff** the present value at `t = 0`, at 3%, of everything the payer pays under it — each payment and each rebate at its own date — does not exceed `P*(π, h, λ)` (L20) |

**A7 introduces no new analytic frame, only new contract commitments (L17–L21).**

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
| **L12** | **Uptake shape locked, uptake level swept.** Cumulative share of the eligible population treated follows a linear ramp over a 5-year ramp period to a swept terminal share `u`. S-curve and immediate-full-uptake are the bounding scenario pair (S8) | 2026-08-21 | Stone | No uptake data exist for a product with no efficacy data, so a specific curve would be an assumption with no owner. **The 5-year ramp period is itself a chosen level, not structure**, recorded as an analyst's assumption under O12 rather than defended as a derivation. **The ramp period is held fixed across every reported horizon**, or the same terminal share would mean a different adoption speed at each horizon and the horizon comparison would be confounded with an uptake comparison. **S8's logistic leg carries a steepness parameter that is unsourceable in exactly the way the ramp period is**, and it is treated the same way: a required argument with no default, its value stated as an analyst's assumption under O12 rather than defended as a derivation (§11 amendment, 2026-08-28). All three shapes share one contract — the same ramp period, the same terminal share at its end — so S8 varies the path and nothing else |
| **L13** | **The comparator displaced is the same infliximab biosimilar base case (Q5104) as the frontier's, and it is the only comparator displaced.** The current-treatment-mix refinement is **not performed**: US market shares across advanced therapies in moderate-to-severe CD cannot be sourced from citable primary material, so the single-comparator assumption is carried as a stated limitation rather than as a blocked scenario (§11 amendment, 2026-08-28). The direction of the resulting bias is known and stated in the rationale | 2026-08-21 | Stone | Keeps the BIA reconcilable to `A` and `B`, which is what makes T13 possible; US market shares are unsourced. **Direction:** Q5104 is the cheapest of the three biosimilars (C10) and S5 showed ustekinumab and adalimumab comparators both raise `B`, so displacing the cheapest agent yields the smallest offset and the largest net budget impact — conservative for an affordability question |
| **L14** | **BIA perspective: US commercial payer**, distinct from §2's healthcare-sector perspective. The difference is the denominator and the horizon, not the unit costs | 2026-08-21 | Stone | Every unit cost here is already a payer payment amount — CMS ASP payment limits (C10) and CMS PFS national payment amounts (C9) — so the two perspectives coincide on inputs. Recorded so no reader infers that a second, differently-costed model was built. **Known gap:** ASP payment limits are not net-of-rebate commercial prices (O14) |
| **L15** | **Single adoption wave.** Cumulative treated caps at `u × N` at the end of the 5-year ramp; nobody is treated after year 5. Years 6 onward are pure offset accrual on the already-treated cohorts | 2026-08-21 | Stone | The alternative "flow" reading — the terminal annual rate persisting for the full horizon — would treat roughly six times the eligible pool over 30 years, incoherent with a pool held fixed (L16) unless incidence replenishes it, and incidence is unsourced (O15); that reading is **not well-defined until O15 closes**. A single wave is cleanly interpretable as one adoption wave followed by offset accrual, which is what the offset-capture progression measures, and leaves the 1/3/5-year horizons numerically unchanged since the ramp and those horizons coincide. **Direction:** a single wave produces the smaller long-horizon expenditure and therefore the more favourable-looking 30-year figure — the non-conservative direction, chosen for coherence rather than for conservatism. **T16 does not discriminate between the two readings**, so this decision has no mechanical guard and must be checked by reading the uptake function |
| **L16** | **The eligible pool is held fixed over the reporting horizon; no incidence or turnover is modelled** | 2026-08-21 | Stone | Defensible over 1–5 years, where incidence is second-order against a pool level that is itself entirely unsourced. **Not defensible at 10 and 30 years, and stated as a limitation there rather than absorbed** (O15). Interacts with L15: under a single adoption wave a fixed pool is drawn down toward `u` and never replenished |

**L17–L21 govern A7 (alternative payment arrangements) only.** No figure in A1–A6 depends on any of them.

| # | Decision | Locked | Date | Rationale |
|---|---|---|---|---|
| **L17** | **An installment arrangement is a re-timing of the course price and nothing else.** Its base case is a present-value-neutral schedule of equal nominal annual payments over `N` years, first payment in the adoption year, with the financing rate an explicit contract term supplied as a required argument (O16) and the base case set to the study's own 3%. An interest-free schedule is reported alongside and is labelled as what it is — a price reduction, reported as its equivalent per-course present-value discount, not as an affordability gain. `N` is a stated choice, not a swept parameter: base case 5 years, 3 years reported alongside. **Every installment figure is reported at population level**; a per-treated-patient figure is reported only on the single-cohort reconciliation fixture | 2026-08-23 | Stone | An installment whose financing rate equals the analysis rate is exactly present-value-neutral and moves no discounted figure once the whole schedule is inside the window for every cohort — that invariance is what makes T19 a real test rather than a tautology, and it is the only clean way to separate "re-timing" from "price cut". **The separation is visible only across L11's two columns and is the strongest argument for L11 there is:** at `H ≥ ramp_period_years + N − 1`, a present-value-neutral schedule shows 0.0% on the discounted column and the financing charge `N/a_c − 1` on the undiscounted one, while an interest-free schedule shows `−(1 − a_a/N)` and 0.0% — each is invisible in one column and unmistakable in the other. An interest-free installment is not a payment arrangement; it is a manufacturer forgoing the time value of money, and presenting it as affordability engineering would let a price reduction masquerade as a financing innovation. **The 3% base-case financing rate is the study's own analytic discount rate and is not a cost of capital.** A manufacturer's true financing cost is higher and unsourced (O16); this study has warrant for one rate only and uses it, recording that any other rate is a transfer between the parties. **`N` is normative, not epistemic** — a contract term a negotiator picks, in exactly the sense L10 distinguishes for the reporting horizon — so it is stated, not swept. **5 years is a chosen level, not structure**, recorded as an assumption in the same spirit as L12's 5-year ramp period. **Population level, not per patient:** over a staggered cohort stack "per treated patient" needs a horizon-dependent denominator, which is the L2/guard-3 hazard in a new costume |
| **L18** | **Outcomes-based payment is evaluated in expected-value cohort terms and yields an effective price. No distribution over per-patient outcomes is constructed, and no variance, budget-predictability or risk-reduction claim is made** | 2026-08-23 | Stone | Payment enters the budget linearly in the individual outcome indicator, so the cohort-share expectation is **exact, not an approximation**, and a per-patient distribution would add nothing to the expected budget. It would add something to a variance — and that variance would be misleading: this study's uncertainty in π is epistemic and swept across 101 points, not sampled, so a binomial band around a cohort share is roughly three orders of magnitude smaller than the uncertainty that actually matters, and would report precision the study does not have. **It would also require reading π as a per-patient probability rather than as a share of all treated patients, which is the move L2, guard 3 and T4 exist to prevent.** The risk-transfer question is answered instead by the sweep itself: **on the discounted lifetime leg** the spread of net budget impact across `π ∈ [0,1]` is `B(h, 0)` per treated patient under a lump sum and exactly zero at T21's risk-neutralising price. **The lifetime-leg qualifier is required, not decorative** — T14 restricts the `−B(h, λ = 0)` slope to that leg in terms, and at 1/3/5 years the spread is the π-range of `D(H)`, which is smaller and horizon-dependent |
| **L19** | **The rebate trigger is the study's own §7 derived quantity `still_in_drug_free_remission(T) = π·exp(−h·T)` evaluated at a stated observation point `T` measured from the landmark — never π itself.** Base case `T = 2 years`; 12 weeks (the landmark, `T = 0`) and 5 years reported alongside. A contract observed at the landmark is labelled a **response-based** contract, not an outcomes-based one. The contract structure is a rebate against an invoice paid at adoption (**form R**), not a deferred milestone payment (form M); the two are different contracts with different justified prices and only form R is built. The trigger excludes background mortality, matching §7's formula exactly. `T` is reported in a column named `outcome_observation_years` and is neither the reporting horizon nor `run_comparator_trace()`'s `horizon_years` | 2026-08-23 | Stone | §7 exists because "comparing π directly against those figures is the same class of error as a conditional denominator: the right number against the wrong reference point" — **and a rebate trigger is a comparison against a timepoint.** At the landmark the trigger equals π exactly (T4), so a landmark-triggered contract rebates on a 12-week response, pays full price for a patient who relapses in month four, and is not a durable-cure contract at all. L1 fixed the landmark at 12 weeks as a *clinical rescue window*, explicitly superseding a 52-week rationale, and nothing in this specification claims it is a durability-confirmed cure signal — the entire sweep over `h` is the admission that it is not. **The 12-week leg is retained and reported precisely so a reader can see what a landmark-triggered contract would pay, not because it is the recommended design.** The 2-year base case coincides with L6's maintenance-cap clock, which is the only other two-year boundary this model treats as decision-relevant; **that coincidence is a convenience and not a derivation**, and is recorded as an assumption rather than defended. **Form R is named because form M is not a rescaling of it:** under M the whole payment is deferred and its justified price is `e^{hT}·v^{−τ}·(B + A/π)`, whereas under R only the rebate leg is deferred and the justified price is L21's ratio; the two coincide only when the rate is zero. **Mortality direction:** excluding background mortality makes the trigger share larger, so fewer patients count as failures, so fewer rebates and a **higher expected payment** — conservative for an affordability question, as L13 was conservative for its own. **Naming:** §2a exists because two horizon-like quantities collided in one `output/tables/` directory; a third makes that worse, so `outcome_observation_years` is named distinctly |
| **L20** | **Every arrangement is evaluated against the frontier's own justified price `P*(π, h, λ)`, with the observed-analog list price carried as the separately-labelled second axis exactly as A6 carries it (L13's spirit). An arrangement is justified if and only if the present value at `t = 0`, at the study's 3% rate, of everything the payer pays under it — every payment and every rebate, each at its own date — does not exceed `P*(π, h, λ)`. No re-timing makes an unjustified price justified** | 2026-08-23 | Stone | This is the misreading the whole extension invites: that spreading payment over five years makes an observed analog list price acceptable. It does not — it makes it arrive later. The frontier is a present value at `t = 0`, so a present-value test is the only test commensurable with it, and stating it as a locked decision puts it where a reader looking for it will find it rather than in a footnote. **The per-cure frontier is measured against the same `A` and `B`**, so an outcomes-based contract has a justified price on the study's own terms and needs no external benchmark to be assessed; and the per-cure number exceeding `B` at the risk-neutralising price is the rule working, not a value discovery |
| **L21** | **One time convention governs every conditional payment.** A rebate triggered at observation point `T` (measured from the landmark, §7's clock) is settled at patient-time `τ = T + 12/52` years measured from adoption, carries the discount factor `v^τ` at the rate in force, and is placed at index `⌊τ⌋ + 1` of the per-patient price stream. No coincident-settlement approximation is used anywhere. The resulting justified per-cure price is `P*_cure = (A + πB) / (1 − ρ(1 − πe^{−hT})v^τ)`. **The `_usd_per_cure` unit and its per-cure denominator apply at `ρ = 1` only**; at `ρ < 1` the contract's headline figure is an invoice per treated patient and carries `_usd_per_course`. Two denominators are declared: `cured_patients_at_landmark` at `T = 0` and `sustained_remitters_at_observation` at `T > 0` | 2026-08-23 | Stone | The landmark is 12 weeks after adoption, not `t = 0`, and this study has already been bitten by exactly that gap: `value_of_one_cure_usd()`'s docstring records that a `B` discounted to the landmark instead of to `t = 0` "is larger by exactly 1/v^6 (0.68% at 3% annual over 12 weeks) and breaks T2 by ~$1,100 while leaving T1 and T3 untouched — which is how it was found, and why T2 is worth having." A convention that reintroduces the same 0.68% for the tidiness of a closed-form identity would be that defect deliberately re-committed, and the identity it buys (`net = −A(0)` exactly, constant in π) is available anyway as the `τ → 0` limit and is reported as a limit. **The convention also removes a pole, but that is the weaker of the two arguments and is stated as such:** with `v^τ < 1` at every observation point, `P*_cure` is finite on the whole of `π ∈ [0,1]` with its only pole at negative π, where a coincident-settlement version is singular at π = 0. It is a *regularised* pole rather than a tame curve: with `A(λ) < 0` the value at π = 0 is a large negative number and the curve traverses most of its range inside the first two grid points. **The reportable statement is the sign condition, not the limit value:** `P*_cure > 0` iff `A + πB > 0`, i.e. iff `π > −A/B`, below which no positive price is justified — the same threshold `P*` itself has, inherited rather than introduced. **Two denominators, because there are two populations:** at the landmark a success is a cure in L2's sense; at `T > 0` a success is a patient still in drug-free remission at `T`, a strictly smaller group of size `π e^{−hT}` of all treated. `CLAUDE.md`'s standing warning is that the cure fraction "has twice been implemented as a share of a subset and reported as if it were not", and one suffix over two denominators is that shape exactly. **`ρ < 1` gets no per-cure unit at all**, because the payer's invoice under a partial rebate is neither per course nor per cure and naming it either would be the conflation guard 2 exists to catch |

**Considered and rejected: making the rebate share `ρ` and the observation point `T` open items under guard 7.** L10's own reasoning forbids it. π and uptake are *epistemic* — facts nobody knows — so sweeping is honest. A reporting horizon and a contract term are *normative* — choices a decision-maker makes — so declining to choose is a refusal, not a justification. ρ and `T` are contract design parameters and belong here with stated base cases and reported ladders, not in `OPEN_QUESTIONS.md`. They remain required arguments with no defaults, enforced by a module-boundary assertion in `tests/testthat/test-payment-arrangements.R`, on the precedent of `price_usd_per_course` in A6 — which is likewise a required argument and likewise not an open item. **What *is* epistemic here is the financing rate**, and that is O16.

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
| S8 | Uptake shape: linear (base case) / logistic / immediate full uptake, as the bounding pair {logistic, immediate} around the linear ramp (A6) — `output/tables/budget_impact_s8.csv` |
| S10 | Payment schedule: lump sum (base case) / N-year present-value-neutral installment / N-year interest-free installment / offset-matched reference schedule (A7) |
| S11 | Outcomes-based contract: rebate share ladder × observation-point ladder, with full rebate at the landmark carried as the T21 limit case (A7) |

**Nothing is added to the swept-parameter table above by A7.** Every A7 parameter is either normative (`N`, ρ, `T` — stated, per L10's own epistemic/normative distinction) or already swept (π, h, u).

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
| **A7** | The price justified per durable cure under an outcomes-based contract, and payer budget impact under alternative payment arrangements — installment schedules and outcome-conditioned payment — across the same price, cure-fraction, uptake and reporting-horizon grid as A6, reported as scenario-conditional cells | `output/tables/payment_arrangements.csv` |

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
| Installment financing rate (A7) | Base case 3%, the study's own rate | **STATED CONVENTION** | O16 / register item S-9. Not a cost of capital; any other rate is a labelled illustration |
| Installment schedule length (A7) | 5 years base case, 3 years alongside | **STATED CHOICE** | L17. A chosen level, not structure, in the spirit of L12's ramp period |
| Rebate share ρ (A7) | Ladder including 1.00 | **STATED CHOICE** | L19. Contract design, normative, not swept |
| Outcome observation point (A7) | 2 years base case; 12 weeks and 5 years alongside | **STATED CHOICE** | L19 / register item S-9 |
| Settlement lag from the landmark (A7) | 12/52 years, the landmark's own offset from adoption | **STATED CONVENTION** | L21. Not a contract term; the model's own calendar |

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
| O14 | Net-of-rebate commercial price relative to the ASP payment limit | A6 level; direction stated |
| O15 | Eligible-population incidence and turnover over a 10–30 year window | Extended projection only; also blocks the "flow" uptake reading L15 rejects |
| O16 | Financing rate appropriate to an installment payment arrangement for a one-time therapy — a real cost of capital, not the analysis's own discount rate | A7's non-present-value-neutral installment legs; base case present-value-neutral at the study's 3% meanwhile (L17) |

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

| T19 | **Installment present-value neutrality over the cohort stack, and orthogonality to the model.** (a) For a present-value-neutral schedule (`r_contract = r_analysis`) on the discounted leg, at every reporting horizon `H ≥ ramp_period_years + N − 1`, the net budget impact equals the lump-sum figure to within $0.01 **for the full uptake ramp, not only for a single cohort**; and on the lifetime leg T13's identity `price − P*(π, h, λ = 0)` continues to hold to within $1 on the single-cohort fixture. **The bound is `ramp + N − 1`, not `N`.** (b) At every horizon, the population-level difference between the lump-sum and installment net budget impacts equals `price · Σ_{k ≤ min(K,H)} treated_k · v_a^{k−1} · [1 − (1/a_c)·Σ_{j ≤ min(N, H−k+1)} v_a^{j−1}]`, computed independently from the schedule, the two rates and the uptake vector without touching a cost stream, to within $0.01. **Falsification arm:** a fixture computing the same expression with truncation index `H` in place of `H − k + 1` must fail at every reported horizon with `1 < H < ramp + N − 1` — the 3- and 5-year rows. It must **not** be expected to fail at `H = 1`, where only cohort 1 exists and `H − k + 1 = H` makes the two expressions the same number. (c) **Stated as a share of the price, because `Δ` is proportional to it.** At a fixed uptake schedule and horizon, `Δ(H)/price` is identical at every cure fraction, every relapse hazard, every λ and both cap settings, to a relative deviation under `1e-10` — a function of `N`, `r_c`, `r_a`, the uptake vector and `H` alone. **The dollar form holds only on the analog price axis**, where the price is the fixed `median(us_list_price_usd)`; on the frontier axis `price = P*(π, h, λ)` spans more than 14× across the reported cells and `Δ` spans it with them. Both clauses are asserted: the ratio on both axes, the dollar identity on the analog axis only. (d) **The four-cell contract-rate check.** At `H ≥ ramp + N − 1`: a present-value-neutral schedule leaves the discounted column unchanged to the cent and raises the undiscounted column by exactly `N/a_c − 1`; an interest-free schedule (`r_contract = 0`) leaves the undiscounted column unchanged to the cent and lowers the discounted column by exactly `1 − a_a/N`. **Falsification arm:** computing `a_c` from `discount_rate_per_year()` instead of from `installment_financing_rate_per_year` must fail (b) **and** (d) — all four cells of (d) collapse to 0.0%, and (b) breaks on the undiscounted leg for the present-value-neutral contract and on the discounted leg for the interest-free one — while (a) and (c) still pass |
| T20 | **The offset-matched reference schedule, over the stack.** On the **discounted leg only**, and wherever `D(lifetime) = P*(π, h, λ = 0) > 0`: under a schedule paying, in the patient's own year `m`, `price · (D(m) − D(m−1)) / D(lifetime)` supplied **without a further discount factor**, the cumulative net budget impact at every reported horizon equals `(price / P*(π, h, λ = 0) − 1) × (the stacked cumulative offset through H)` to within $0.01, **for any uptake vector**; and at `price = P*(π, h, λ = 0)` it is exactly $0 at every reported horizon simultaneously. Additionally, and **scoped**: *on the lifetime leg*, where `n_years` is derived from the cost stream rather than given, no cohort's schedule is clipped — asserted as `length(newly_treated) − 1 + length(schedule) ≤ n_years`, equivalently `length(schedule) ≤ length(cost_stream)`. *At finite horizons the opposite is asserted*: cohort `k` contributes exactly `max(0, min(H − k + 1, L))` schedule elements, zero for a cohort not yet adopted by year `H` — because per-cohort truncation at `H − k + 1` is the mechanism that makes this identity true, the schedule and the offset being truncated at the same index. And every annual increment `D(m) − D(m−1)` is non-negative **on the reported grid**, asserted rather than assumed. **Falsification arms:** a one-year shift of the schedule fails the identity at every horizon; applying a second discount factor `v^{m−1}` to the schedule fails it at every horizon; truncating the schedule one element short fails the lifetime leg only |
| T21 | **The outcomes-based contract, under L21's settlement convention.** (a) *Two routes to the price leg.* The budget machinery's present value of the price leg per treated patient equals `q · [1 − ρ · (1 − π e^{−hT}) · v^τ]`, `τ = T + 12/52`, to within $0.01 at every point of the ρ × `T` ladder. **Falsification arm:** placing the rebate at index 1 rather than at `⌊τ⌋ + 1`, or omitting `v^τ`, must fail at every `T > 0` and at `T = 0`. (b) *Affinity and the risk-transfer corner.* On the discounted lifetime leg the net budget impact per treated patient is affine in π across the 101-point grid, deviation under $0.01, with slope `q·ρ·e^{−hT}·v^τ − B(h, 0)`; at `ρ = 1` and `q = B(h,0)·e^{hT}·v^{−τ}` the slope is exactly zero to within $0.01, at every observation point and every hazard. (c) *The level, against a second route to `A`.* At that corner the level equals `B(h,0)·e^{hT}·(v^{−τ} − 1) − A(λ = 0)` to within $1, with `A(λ = 0)` taken from `frontier_intercept_independent()`; and it reduces to exactly `−A(λ = 0)` in the `τ → 0` limit, which is reported as a limit and not as the identity. (d) *Sanity.* At `ρ = 0`, `P*_cure` equals `P*(π, h, λ)` exactly |

**T13–T18 belong to A6.** T17 and T18 govern the engine capability A6 rests on — per-cycle cost streams and their truncation — and are the reason a horizon never reaches the Treg arm as an argument. **Monotonicity in the horizon is deliberately not asserted at any relapse hazard, including h = 0**: a relapser re-entering standard care starts a second induction course and their own cap clock, and independently of any relapse the Treg cohort's 12-week landmark deferral (L9) shifts its 2-year cap clock 12 weeks later than the comparator world's, so there is a window in which the Treg world pays biologic and the comparator world does not. A passing monotonicity test would mean one of those two has stopped being charged.

**T19–T21 belong to A7.** **T20 is A7's gate, not T19.** T19's content is "the payment arrangement did not move the model", which is the right thing to assert about a re-timing but is a statement about arithmetic A7 performs on its own output. T20 is the one that closes a loop through the model: a schedule derived from `D(·)` and a price derived from `P*(·)` cancel exactly, over the whole cohort stack, at every horizon, which cannot happen unless the offset machinery, the frontier and the cohort clock all agree. **It is the T13 of this extension.** T21(c)'s independence is partial and is claimed as no more than that: `frontier_intercept_independent()` shares no code path with `run_treg_trace()`, but both routes to `A` share the grid and the pre-landmark loop, so T21(c) is a check on the contract arithmetic rather than on `A`.

**T1 and T2 are the gate.** They are the intercept and the slope stated as properties rather than as values, which is why they cannot pass on a false premise.

---

## 11. Amendment procedure

Changes to this file require an entry in `SPEC_AMENDMENTS.md` recording the date, the person signing off, what is superseded, and why — committed alongside the change. A scope reduction that drops an aim from §6 is an amendment, not a decision made in code.

Every output file carries the git commit hash and the SHA-256 of this file at run time. A run whose spec hash differs from the last committed one fails.
