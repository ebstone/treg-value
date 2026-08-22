# W2 sourcing register

Inputs that cannot be transcribed from a document already in hand. Each needs a
person to run a query and record the result with a `.source.yaml` sidecar.

Nothing here may be estimated, inflated forward from an older figure, or carried
across from `treg-cd`. If a value cannot be sourced, it goes in
`OPEN_QUESTIONS.md` and its consumer takes it as a required argument.

---

## S-1. Infliximab administration — CMS Physician Fee Schedule — RESOLVED 2026-08-12

**Status:** sourced, from CMS's own open-data API (pfs.data.cms.gov), not a
third-party or state mirror. See `data/raw/cms_pfs_infusion_administration_2026.csv`
and its sidecar. OPEN_QUESTIONS.md O7 closed as C9.

| Item | Value | Source |
|---|---|---|
| CY2026 PFS conversion factor | **$33.4009** | CMS PFS January 2026 release, CY2026 final rule (MM14315, effective 2026-01-01) |
| CPT 96365 total RVUs (work 0.21 + PE 1.76 + MP 0.04) | **2.01** | pfs.data.cms.gov, "Indicators for 2026" |
| CPT 96365 national payment amount | **$67.14** | 2.01 × $33.4009 |
| CPT 96366 total RVUs (work 0.18 + PE 0.45 + MP 0.01), add-on | **0.64** | pfs.data.cms.gov, "Indicators for 2026" |
| CPT 96366 national payment amount | **$21.38** | 0.64 × $33.4009 |

**Facility or non-facility:** turned out moot. CMS's own data has identical
RVUs for facility and non-facility settings for both codes — the "prior
project used $57.90 (2025) without recording which setting" gap this section
originally flagged does not have a live consequence for these two codes.

**Residual, not blocking W3:** whether 96366 is billed additively alongside
96365 (one unit of each per hour beyond the first) is assumed, not confirmed
against CMS billing policy; and the source data carries a second,
unexplained RVU row at a different conversion factor ($33.5675) that was not
used. Both recorded as unresolved items in the sidecar for whoever next
touches this data.

---

## S-2. Surgery state cost — RESOLVED, no external source needed

**Correction, 2026-08-12 (OPEN_QUESTIONS.md C8):** the Moderate-Severe row
below, as originally written, used $362 as Aliyev's PMPM figure. That number
does not appear anywhere in Aliyev's actual Suppl. Table 2 -- verified at
1200 DPI against the source PDF. The real figure is **$374**, which does
*not* reconcile to Aliyev's adopted $217/cycle via this conversion rule (it
gives $224.43, a $7.40 gap). The other three states below are unaffected and
do reconcile as shown. See `data/raw/aliyev2019_base_case_costs_utilities.csv`
and `derive/health_state_costs.R`: Moderate-Severe (and Moderate-Severe
Responder, which Suppl. Table 2 has no PMPM row for at all) now use Aliyev's
adopted per-cycle figure directly rather than this rule, per Eric Stone's
direction. The claim "all four reconcile... with no free parameters" below
is therefore false for Moderate-Severe and should not be relied on.

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
Moderate-Severe     $374 PMPM x 0.60009  = $224.43   (Aliyev: $217 -- does NOT reconcile, see correction above)
Mild                $152 PMPM x 0.60009  = $ 91.21   (Aliyev: $ 91)
Remission            $17 PMPM x 0.60009  = $ 10.20   (Aliyev: $ 10)
```

Three of four reconcile within about a dollar with no free parameters; see the
correction above for Moderate-Severe. The rule is the derivation; re-base to
2025 USD with a named index and the same rule applies to every state
including Surgery.

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

## S-6. US eligible population — CDC/NHIS prevalence + published CD severity distribution

**Status:** not sourced. Opened with A6 (SPEC.md v1.1, O11).

**How to close:** NHIS adult IBD prevalence for the most recent published year, then a published moderate-to-severe or advanced-therapy share with its cohort definition recorded. Decide and record which prevalence source is used and whether severity is a point or a bounding pair — candidates disagree materially, so this is real work, not a lookup, and the direction of the choice is recorded as C10 recorded its own.

**Record each link with its own sidecar. Do not multiply through to a single "eligible patients" figure and record only that** — the third link (the share of moderate-to-severe patients who would be offered and accept a one-time allogeneic cell therapy) is not sourceable for a product with no label and no efficacy data, and a single product figure would hide that. That link is swept, not sourced, exactly as π is.

---

## S-7. Uptake analogs

**Status:** not sourced, and recommended not to be. Recorded so that the decision not to source is visible rather than looking like an omission.

**How to close, if it is ever wanted:** the nearest evidence is analogy, and this repository has a respectable way to handle analogy (the manufacturing benchmark's `tenham_analogy_anchors()` leg — labelled, bounded, never pointed). The candidate analogs (CAR-T uptake in approved indications; new IBD biologic launches) are weak for different reasons. The recommendation instead is L12's: sweep the terminal share, bound the shape (S8).

---

## S-8. BIA horizon-convention citations

**Status:** not sourced. **Blocking for the manuscript**, not for the code.

**How to close:** retrieve and record Sullivan et al. 2014 (*Value in Health*, ISPOR Budget Impact Analysis Good Practice II Task Force) for the one-to-three-year guidance; the current AMCP Format; and the ICER methods documents on single- and short-term transformative therapies, plus the amortised/outcomes-based payment literature.

**Why this one is blocking.** L10's rationale currently rests on a paraphrase of those bodies of work from memory. The planning document that proposed A6 committed exactly this error one revision earlier — a paraphrase from memory asserted as a repository fact, in a document that contained the warning against it — and it survived to review. **If the retrieved sources are narrower than the paraphrase, L10's rationale is rewritten, not defended.** The recommendation itself (a three-year base case) survives a weaker justification, which is precisely why the justification could weaken unnoticed.

---

## Rule

A sidecar with `status: transcribed` and a recorded unresolved item is
acceptable and gets committed. A value with no sidecar does not enter the
repository at all.
