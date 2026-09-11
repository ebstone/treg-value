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

**Status:** first link (prevalence) sourced 2026-09-10; second link (severity/treatment-line share) still not sourced. Opened with A6 (SPEC.md v1.1, O11).

**First link closed:** `data/raw/lewis2023_ibd_prevalence_incidence.csv` (+ sidecar) — Lewis et al. 2023, *Gastroenterology* 165(5):1197-1205.e2, PMCID PMC10592313. Claims-based (Medicare/Medicaid/commercial, pooled 1999-2017, point prevalence 2017-12-31), **Crohn's-disease-specific**, not IBD-combined — stronger than the NHIS route this entry originally anticipated, since NHIS survey data (the CDC facts-and-stats page's own second source) only reports combined IBD, never CD alone. US Crohn's prevalence: 305 per 100,000 (95% CI 302–308), extrapolated to 1.011 million against the 2020 Census. Superseded the Loftus/Olmsted-County-extrapolation figures (780,000 / ~33,000-per-year) that an earlier, older CCFA Factbook PDF had been mistakenly read from — see the sidecar's own notes for that correction.

**Still open, candidates sourced 2026-09-10 (disagreement recorded, not resolved):** the moderate-to-severe or advanced-therapy share — Lewis 2023 carries no severity or treatment-line breakdown. `data/raw/us_cd_biologic_treated_share.csv` (+ sidecar) transcribes two real, peer-reviewed, claims/EMR-based estimates of the *advanced-therapy-treated* share of diagnosed CD patients (a proxy for "moderate-to-severe," not a clinical severity read — see the sidecar's U2): Yu et al. 2018 (MarketScan commercial claims) 21.8% (2007) → 43.8% (2015); Xu et al. 2022 (IQVIA ambulatory EMR) 13.3% (2011) → 32.1% (2020). **These materially disagree** — Xu's later (2020) endpoint is lower than Yu's earlier (2015) one, the opposite of either paper's own within-study trend — for reasons neither confirmed nor resolved here (different cohort/claims-vs-prescription definitions; see the sidecar). Both are also now stale against 2026's advanced-therapy landscape (four additional agents approved since Xu's 2020 cutoff), so both likely understate a current share.

**A candidate for the DelveInsight page Eric originally supplied was checked and rejected**, not silently skipped: its free severity split (461,000 mild / 755,000 moderate-to-severe, 2024) doesn't reconcile against its own stated total prevalence (sums to 1.216M against a stated "1.1 million" headline), cites no primary source, and DelveInsight is the same vendor class this repository already declined to use for O13 (2026-08-28 status brief: "not CHEERS-grade provenance").

**How to close:** decide and record which of Yu/Xu (or a bounding pair spanning both) is used, and why — this is a real decision structurally like C8's and C10's, not a default, and per this entry's own long-standing instruction the direction of the choice should be recorded the way C10 recorded its own.

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

## S-9. Real-world instalment/annuity and outcomes-based payment arrangements for one-time cell and gene therapies

**Status:** not sourced. **Blocking for the manuscript**, not for the code. Opened with A7 (SPEC.md v1.2, L17/L19).

**How to close:** retrieve and verify the arrangements the secondary literature attributes to Zolgensma (instalment/pay-over-time option at 2019 US launch), Kymriah (outcomes-based arrangement with CMS, response at approximately one month), Luxturna (outcomes-based rebates; an instalment model discussed with CMS), Strimvelis (money-back guarantee on treatment failure), Zynteglo/beti-cel (proposed instalments over roughly five years with outcomes-based rebates), the CMS Cell and Gene Therapy Access Model, and the MIT NEWDIGS FoCUS precision-financing taxonomy. **Every one of those is offered here from memory and none is a verified citation.**

**Record two distinctions per row, not one.**

- **Proposed versus executed.** A great deal of writing on gene-therapy payment innovation describes arrangements that were *announced* and never operated. If A7's rationale says "these arrangements exist," and what exists is a set of press releases, the rationale is wrong in exactly the way S-8 warns about.
- **Rebate (form R) versus deferred milestone (form M) versus true annuity.** These are three instruments with three different justified prices (L19, L21), and the secondary literature calls all three "outcomes-based" or "pay-over-time". A precedent retrieved without its structure cannot support L19's base case.

**If the retrieved evidence is weaker than the paraphrase, L17's and L19's rationales are rewritten, not defended.**

---

## S-10. US regulatory and legal constraints on instalment and outcomes-based contracts

**Status:** not sourced. Not blocking for the code; **blocking for any claim that these arrangements are available**, as distinct from conceivable. Opened with A7 (SPEC.md v1.2).

**How to close:** retrieve and record the Medicaid best-price interaction; the federal anti-kickback statute as it bears on value-based arrangements; and the CMS value-based purchasing rule understood to permit multiple best prices. Confidence that each is a real and relevant constraint is moderate; confidence on status and detail is low, which is why the A7 amendment refers to "the constraints named in S-10" rather than naming the three.

**Why this one matters.** A study that models an arrangement US law obstructs is modelling a counterfactual, and the readout should say which it is.

---

## S-11. Eligible-population incidence (new-diagnosis inflow) for the 10–30 year BIA horizon

**Status:** inflow half sourced 2026-09-10; outflow (turnover) half not sourced. Opened with A6 (SPEC.md v1.1, O15).

**Inflow sourced:** `data/raw/lewis2023_ibd_prevalence_incidence.csv` (same file as S-6's first link) — US Crohn's disease incidence 4.1 per 100,000 person-years (95% CI 3.9–4.3), ≈13,600 new diagnoses per year (95% CI ≈12,900–14,300) against the 2020 Census, same claims-based pooled 1999–2017 source as the prevalence figure. **This range is this file's own extrapolation, not a figure the paper states**: checked directly against the paper's text, it gives only a combined-IBD figure (≈39,000–56,000/yr for Crohn's and ulcerative colitis together), no Crohn's-specific count. The range above is round-to-nearest-hundred of the point estimate and both ends of the stated 95% CI, applied to the same 2020 Census population the prevalence figure uses.

**Still open:** O15 asks about incidence *and turnover* — this source gives only the rate new patients enter the diagnosed population, not the rate existing patients leave it (background mortality is separately sourced via `nchs_life_table_2023.csv`, but disease-specific attrition — remission out of the eligible definition, if the eligible definition is diagnosis-based rather than active-disease-based — is not addressed by either file). **How to close the remainder:** decide what "leaving the eligible pool" means under this study's own eligible-population definition once S-6's severity/treatment-line link is sourced (a diagnosis-based pool has no disease-driven outflow; a moderate-to-severe/advanced-therapy-based pool plausibly does, e.g. patients moving into sustained remission), then source that specific attrition rate if the chosen definition needs one. **Outflow cannot be backed out arithmetically from this file's own two rates**: prevalence ÷ incidence (305 / 4.1 = 74.4 years) is not a credible mean disease duration for a condition typically diagnosed in the twenties to forties, so the steady-state identity that shortcut relies on does not hold — the diagnosed pool was still growing over the 1999–2017 window these rates are pooled across — and no other arithmetic on this file substitutes for sourcing the rate directly. An external claims-data route to the turnover half was requested 2026-09-10; nothing has returned and no timeline exists.

**Why this matters beyond A6's 10/30yr figures.** L15 currently rejects the "flow" uptake reading (the terminal annual rate persisting for the full horizon) as "not well-defined until O15 closes" specifically because a flow reading against a fixed, non-replenishing pool is incoherent. A sourced inflow rate is necessary but not sufficient to revisit that rejection — it does not by itself resolve whether the pool should be modelled as replenishing, since that also depends on the still-unsourced severity/treatment-line share (S-6) defining what the pool actually is.

---

## Rule

A sidecar with `status: transcribed` and a recorded unresolved item is
acceptable and gets committed. A value with no sidecar does not enter the
repository at all.
