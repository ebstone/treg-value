# Open questions

Every item here is a required argument in code with no default (guard 7).
A function that needs one of these refuses to run rather than assume a value.

| # | Question | Arg name | Owner | Blocks | Opened |
|---|---|---|---|---|---|
| O1 | US eligible-population fractions for moderate-to-severe CD by treatment line | `eligible_population_fractions` | Unsourced | A4 population figure; break-even reported meanwhile | 2026-08-11 |
| O2 | Confirmatory trial cost benchmark for a cell-therapy programme | `confirmatory_trial_cost_usd` | Unsourced | A4 comparison | 2026-08-11 |
| O3 | Preconditioning dose | `preconditioning_dose` | Dula | S6 only | 2026-08-11 |
| O4 | Whether a Treg infusion qualifies for observation billing, and wage-index adjustment | `observation_billing_eligible` | Dula | S6 only | 2026-08-11 |
| O5 | Real-world biologic persistence (time to discontinuation) | `biologic_persistence` | Unsourced | Would replace L6's bounding pair | 2026-08-11 |
| O6 | Whether durable remission is exempt from productivity costs | `productivity_cost_exempt` | Co-authors | Societal scenario, out of base case | 2026-08-11 |
| O11 | US eligible population for a one-time allogeneic Treg course in moderate-to-severe CD — a count, not a fraction | `eligible_population_patients` | Unsourced | A6 reports on a labelled illustrative schedule and as PMPM meanwhile | 2026-08-21 |
| O12 | Adoption/uptake trajectory for a first-in-class one-time cell therapy in a chronic non-oncology indication | `uptake_trajectory` | Unsourced | A6's uptake level swept; S8 reports the shape pair. The 5-year ramp period is an assumption under this item, not a derivation (L12) | 2026-08-21 |
| O13 | US market shares across advanced therapies in moderate-to-severe CD | `current_treatment_mix_shares` | Unsourced | S9 only | 2026-08-21 |
| O14 | Net-of-rebate commercial price relative to the ASP payment limit | `net_price_ratio` | Unsourced | A6 level; direction stated (L14) | 2026-08-21 |
| O15 | Eligible-population incidence and turnover over a 10–30 year window | `eligible_population_incidence` | Unsourced | Extended projection only; also blocks the "flow" uptake reading L15 rejects | 2026-08-21 |

`Arg name` is the canonical R argument name guard G7 checks: no function in
`R/` may supply a default for a parameter with one of these names.

## Closed

| # | Question | Resolution | Date |
|---|---|---|---|
| C1 | Landmark timing | 12 weeks (cycle 6) — Dula | 2026-08-11 |
| C2 | Post-relapse pathway | Rejoin standard care; redosing as S3 — Stone | 2026-08-11 |
| C3 | Infliximab induction window | Run both week-4 and week-8 as S1 — Stone | 2026-08-11 |
| C4 | Maintenance duration | 2-year cap and no-cap as a bounding pair — Stone | 2026-08-11 |
| C5 | Treg dose count | Single dose per course; count affects benchmark only — Stone | 2026-08-11 |
| C6 | Pre-landmark trajectory (SPEC.md L9) | Treg follows conventional-therapy dynamics in weeks 0-12 — Stone | 2026-08-11 |
| C7 | Surgery-state costing | Derives from Aliyev's Severe-Fulminant PMPM via the standard conversion. Not an episode cost. The retired workbook's colectomy substitution was a category error — Stone | 2026-08-11 |
| C8 | Moderate-Severe health-state cost: Aliyev Suppl. Table 2 PMPM ($374) does not reconcile to Suppl. Table 5's adopted per-cycle figure ($217) under the PMPM conversion the other states use (gives $224.43, a $7.40 gap) | Use the adopted per-cycle figure directly (aliyev2019_base_case_costs_utilities.csv, $217) rather than re-deriving from PMPM — replicates what Aliyev's model actually used. Other three states (Mild, Remission, Surgery) derive from PMPM correctly and are unaffected — Stone | 2026-08-12 |
| C8a | Why C8's gap exists — resolved 2026-08-14 against the source, and recorded so the reconciliation is not reopened | The gap is not unexplained: Appendix S2 page 3 ("Health State Cost Calculations") states that this one state is built differently from the others — Moderate-Severe CD-related PMPM mean total cost MINUS its own mean pharmacy cost PLUS the Mild-moderate PMPM mean pharmacy cost. Suppl. Table 2 gives those as $374, $123 and $111 (2008 USD). Applying the same (14/30.44)*(1.03^9) conversion to that combination: (374 - 123 + 111) * 0.60009 = $217.23, against Table 5's $217 — a $0.23 gap, not $7.40. C8's decision is therefore correct on its own terms and no figure changes; only its stated reason was incomplete. C8 applied the plain rule, which is the right rule for the other three states and the wrong one for this state — Stone | 2026-08-14 |
| C9 | CPT 96365/96366 facility/non-facility setting and RVUs at CY2026 | Sourced directly from CMS's own open-data API (pfs.data.cms.gov): 96365 = 2.01 total RVU ($67.14); 96366 = 0.64 total RVU ($21.38, add-on). Facility and non-facility RVUs are identical for both codes in CMS's own data, so the setting decision turned out moot for this input. See cms_pfs_infusion_administration_2026.csv.source.yaml for two residual sidecar-level unresolved items (96366 additive-billing confirmation; a second, unexplained conversion-factor row) — neither blocks W3 | 2026-08-12 |
| C10 | Which infliximab product prices the reference-comparator base case | Q5104 (Renflexis) — the biosimilar base case. Lowest-priced of the three biosimilars at the 2026-07 quarter ($2.6615/mg), so the comparator arm is cheapest and `B` and `P*` are correspondingly smallest — the conservative direction. Originator J1745 prices scenario S4 — Stone | 2026-08-13 |
| C11 | Maintenance-phase refractory multiplier (was O10) | Moot. The refractory co-primary population itself is retired (SPEC_AMENDMENTS.md, 2026-08-21) — no separation between populations is attempted, so no maintenance-phase multiplier is needed — Stone | 2026-08-21 |
