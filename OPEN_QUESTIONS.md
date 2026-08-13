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
| O8 | Which infliximab product prices the reference-comparator base case — originator (J1745) or one of three biosimilars (Q5103/Q5104/Q5121, ASP payment limits $27.710/$26.615/$30.830 per 10mg, 2026-07 quarter) — or whether biosimilars should be carried as a bounding pair. Narrowed 2026-08-12: the ASP-methodology half of this question (payment limit vs raw ASP) is resolved, see cms_asp_infliximab_2026.csv.source.yaml | `infliximab_biosimilar_product` | Stone | W3 | 2026-08-11 |

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
| C8 | Moderate-Severe health-state cost: Aliyev Suppl. Table 2 PMPM ($374) doesn't reconcile to Suppl. Table 5's adopted per-cycle figure ($217) via the stated conversion rule (gives $224.43, a $7.40 gap) | Use the adopted per-cycle figure directly (aliyev2019_base_case_costs_utilities.csv, $217) rather than re-deriving from PMPM — replicates what Aliyev's model actually used. Other three states (Mild, Remission, Surgery) derive from PMPM correctly and are unaffected — Stone | 2026-08-12 |
| C9 | CPT 96365/96366 facility/non-facility setting and RVUs at CY2026 | Sourced directly from CMS's own open-data API (pfs.data.cms.gov): 96365 = 2.01 total RVU ($67.14); 96366 = 0.64 total RVU ($21.38, add-on). Facility and non-facility RVUs are identical for both codes in CMS's own data, so the setting decision turned out moot for this input. See cms_pfs_infusion_administration_2026.csv.source.yaml for two residual sidecar-level unresolved items (96366 additive-billing confirmation; a second, unexplained conversion-factor row) — neither blocks W3 | 2026-08-12 |
