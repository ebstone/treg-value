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
| O7 | CPT 96365/96366: facility or non-facility setting, and RVUs at CY2026 | `administration_billing_setting` | Stone | W3 | 2026-08-11 |
| O8 | Which infliximab biosimilar product prices the base case (Q5103 vs Q5104), and whether ASP-file figures are payment limits or raw ASP | `infliximab_biosimilar_product` | Stone | W3 | 2026-08-11 |

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
