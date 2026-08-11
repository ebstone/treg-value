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

## S-2. Surgery state cost — HCUP

**Status:** not sourced. HCUPnet requires an interactive query; no national mean colectomy cost is retrievable from published summaries at the specificity this model needs.

**How to close:** HCUPnet, https://datatools.ahrq.gov/hcupnet/ — National Inpatient Sample, most recent available year, mean cost per stay, colectomy procedure, restricted to a Crohn's disease principal diagnosis if the cell size permits.

**Decide and record:**
- **Cost or charge.** HCUP reports both; they differ by roughly a factor of three. The model needs cost.
- **Data year**, so the inflation path to 2025 USD is explicit.
- **Whether the Surgery state is a one-time entry cost or a per-cycle occupancy cost.** Aliyev's Appendix S2 treats it as recurring at $884 per cycle via the PMPM mechanic; the retired workbook substituted a one-time episode cost applied on state entry. These are not reconcilable and the choice moves the surgery pathway substantially. Record the decision in `SPEC_AMENDMENTS.md`, not in code.

The prior project used $30,389 (2021 HCUPnet) as a one-time entry cost. Treat that as a sanity check on magnitude, not as a value to carry across.

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
