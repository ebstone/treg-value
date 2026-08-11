# W2 sourcing register

Inputs that cannot be transcribed from a document already in hand. Each needs a
person to run a query and record the result with a `.source.yaml` sidecar.

Nothing here may be estimated, inflated forward from an older figure, or carried
across from `treg-cd`. If a value cannot be sourced, it goes in
`OPEN_QUESTIONS.md` and its consumer takes it as a required argument.

---

## S-1. Infliximab administration — CMS Physician Fee Schedule

**Status:** partially sourced. Conversion factor in hand, code-level rate not.

| Item | Value | Source |
|---|---|---|
| CY2026 PFS conversion factor | **$33.4009** | CMS PFS January 2026 release, CY2026 final rule (MM14315, effective 2026-01-01) |
| CPT 96365 total RVUs, non-facility | **TO SOURCE** | — |
| CPT 96365 national payment amount | **TO SOURCE** | — |

**How to close:** PFS Look-up Tool, https://www.cms.gov/medicare/physician-fee-schedule/search/overview — CPT 96365, national, CY2026, non-facility. Record RVUs and the payment amount separately so the arithmetic is checkable, not just the total.

**Decide and record:** facility or non-facility. Infliximab infusion for Crohn's occurs in both hospital outpatient and independent infusion settings, and the two rates differ materially. The prior project used $57.90 (2025) without recording which setting it represented.

**Also needed:** CPT 96366 (each additional hour). Infliximab infusions run 2 hours or more, so 96365 alone understates administration.

---

## S-2. Surgery state cost — RESOLVED, no external source needed

Aliyev's Surgery state is **all surgeries and procedures** (Lichtenstein et al.
2005), many of them performed in an outpatient setting. It is not a colectomy
admission, and it must not be costed as one.

Its cost derives from the Severe-Fulminant CD-related PMPM mean total cost in
Aliyev Suppl. Table 2, through the same single conversion rule as every other
health state:

```
PMPM -> 2-week cycle:  14 / 30.44        = 0.45992
2008 -> 2017 trend:    1.03^9            = 1.30477
combined:                                = 0.60009

Severe-Fulminant  $1,475 PMPM x 0.60009  = $885.14   (Aliyev: $884)
Moderate-Severe     $362 PMPM x 0.60009  = $217.23   (Aliyev: $217)
Mild                $152 PMPM x 0.60009  = $ 91.21   (Aliyev: $ 91)
Remission            $17 PMPM x 0.60009  = $ 10.20   (Aliyev: $ 10)
```

All four reconcile within about a dollar with no free parameters. The rule is
the derivation; re-base to 2025 USD with a named index and the same rule
applies to every state including Surgery.

**Do not query HCUP.** The retired workbook substituted a one-time colectomy
episode cost on state entry — a >25x substitution into a state whose own
transition probabilities describe roughly 1.5 cycles of occupancy with patients
cycling in and out. That was a category error and is not carried forward.

---

## S-3. Life table — NCHS

**Status:** not sourced.

**How to close:** NCHS United States Life Tables, most recent published year, sex-averaged, from the model's start age.

**Decide and record:** vintage. The 2021 table reflects COVID-era mortality, and background mortality determines the large majority of every arm's QALYs. SPEC.md carries a pre-pandemic vintage as scenario S7, so both are needed.

---

## S-4. Observation stay — CMS OPPS

**Status:** not sourced. Needed for scenario S6 only, and gated on O4 (whether a Treg infusion qualifies for observation billing at all).

**How to close:** CY2026 OPPS Addendum B, APC 8011. Record the conversion factor and the relative weight separately from the payment rate.

---

## S-5. Treg dose — RESTORE protocol

**Status:** not sourced. Benchmark only; does not affect the frontier.

**How to close:** NCT06721962 registry record and any published protocol. Needed in cells/kg. This is the single most important input to the manufacturing benchmark in W5 — published allogeneic cell therapy COGS spans two orders of magnitude driven mainly by dose size and lot size, so without it the benchmark range is wide by construction.

---

## Rule

A sidecar with `status: transcribed` and a recorded unresolved item is
acceptable and gets committed. A value with no sidecar does not enter the
repository at all.
