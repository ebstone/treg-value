# Amendments to SPEC.md

Every departure from `SPEC.md` is recorded here, in the same commit as the
change it describes. Date, who signed off, what is superseded, and why.

A scope reduction that drops an aim from SPEC.md section 6 is an amendment,
not a decision made in code.

| Date | Signed off | Supersedes | Change | Reason |
|---|---|---|---|---|
| — | — | — | — | — |

## 2026-08-11 — L9 locked

**Signed off:** Stone
**Supersedes:** SPEC.md v1.0 section 4, which carried L9 as an open decision
requiring co-author sign-off before W4, and OPEN_QUESTIONS.md item O0.

**Change:** Pre-landmark trajectory locked as option (b) — Treg patients follow
conventional-therapy dynamics in weeks 0-12. Promoted into the locked decisions
table; O0 closed as C6.

**Reason:** L9 was the efficacy half of the same question L3 answers on the cost
side, and should have been locked alongside it when the 12-week landmark was
set. Granting the comparator's trajectory without its cost is the unearned
intercept in a different place. Accepted consequence: A may be negative and the
frontier may start below zero.

## 2026-08-11 — Surgery-state costing corrected

**Signed off:** Stone
**Supersedes:** SPEC.md v1.0 section 8, which listed the surgery cost as
TO SOURCE from HCUPnet colectomy; OPEN_QUESTIONS.md item O9; and W2 sourcing
register item S-2 as originally written.

**Change:** The Surgery state cost derives from Aliyev Suppl. Table 2's
Severe-Fulminant PMPM through the same PMPM-to-cycle conversion as every other
health state. No external episode cost is sourced. O9 closed as C7.

**Reason:** Aliyev's Surgery state covers all surgeries and procedures
(Lichtenstein 2005), many outpatient — not a colectomy admission. The retired
workbook's substitution of a one-time inpatient colectomy episode cost was a
category error inconsistent with the state's own transition structure. All four
of Aliyev's published per-cycle health-state costs, Surgery included, reconcile
to within about a dollar under the single conversion rule with no free
parameters.

**Correction, 2026-08-12:** the Moderate-Severe figure this entry implied ("all
four... reconcile") does not actually reconcile — see OPEN_QUESTIONS.md C8.
Surgery, Mild and Remission are unaffected.

## 2026-08-13 — Model starting age set to 35

**Signed off:** Stone
**Supersedes:** nothing explicit — SPEC.md §3 (Model structure) describes the
Markov structure but never states a cohort starting age, and none of
Aliyev's transcribed appendix tables carry one either (the main manuscript,
where Aliyev would state it, is paywalled and was not accessible this
session).

**Change:** The comparator Markov engine's cohort starts at age 35. Sourced
from the SONIC trial (Colombel et al., NEJM 2010) — median age 34-35 years
across arms in a biologic-naive infliximab-for-Crohn's-disease population,
the closest independently-published, directly-relevant anchor available.
Not presented as Aliyev's own figure, because it isn't verified to be one.

**Reason:** Background mortality (life-table integration) and the lifetime
horizon both require a starting age; none was specified anywhere in this
repo's governing documents before this session needed one to build the
engine.

## 2026-08-13 — Transition-row renormalisation

**Signed off:** Stone (via the W3 session prompt's trap 4, executed this
session)

**Supersedes:** nothing — this states an implementation decision SPEC.md
did not previously make explicit.

**Change:** Aliyev's published transition-matrix rows do not all sum to
exactly 1 (source rounding gives figures as far off as 0.9994 and 1.0006 in
the transcribed data). Each row is renormalised to sum to exactly 1 by
dividing every cell by that row's own raw sum, in
`R/transition_matrices.R`'s `renormalize_transition_matrix()` — visible,
tested (`tests/testthat/test-transition-matrices.R` asserts both the
pre-renormalisation deviation and the post-renormalisation exactness), and
never performed silently inside the Markov engine itself.

**Reason:** T7 requires every state vector to sum to 1.00 within 1e-10 every
cycle; that is unreachable if the transition matrices themselves do not sum
to 1 going in. Renormalising is the only correction that does not invent or
discard probability mass, and dividing by the row's own sum is the
minimum-distortion way to do it.

## 2026-08-13 — Conventional-therapy per-cycle drug cost was not being charged

**Signed off:** Stone (defect found and corrected during W4)
**Supersedes:** every cost figure reported by W3, including the four
lifetime discounted comparator costs in that session's closing report and
in `output/tables/comparator_ifx_trace.csv` as first written.

**Change:** Aliyev's Suppl. Table 5 lists "Conventional therapy per cycle,
$67" as a line separate from the per-severity health-state costs. W3's
engine charged only the health-state costs and the biologic dose costs, so
every patient-cycle spent on conventional therapy was costed as though the
conventional regimen itself were free. `R/costs_utilities.R` now exposes
`conventional_therapy_cost_usd_per_cycle()` and `R/markov_engine.R` charges
it to living CT-cohort mass.

**Effect:** lifetime discounted comparator cost at the 8-week window with
the cap on moves from $74,270.51 to $115,257.80 (+55%). QALYs are unchanged.
Because most of the cohort spends most of the lifetime horizon on CT after
the 2-year cap, this is the dominant cost term over long horizons, not a
rounding correction.

**Reason:** it is a straightforward omission, not a modelling choice — the
figure is in the sourced data and describes a cost the modelled patients
incur. Recorded here rather than silently fixed because it invalidates
already-reported numbers.

## 2026-08-13 — Pre-landmark window is mortality-free

**Signed off:** Stone (via the W4 session prompt's T4 requirement)
**Supersedes:** nothing explicit; SPEC.md L9 specifies conventional-therapy
*dynamics* for weeks 0–12 without stating whether background mortality
applies within that window.

**Change:** background mortality is suppressed across the Treg arm's six
pre-landmark cycles. Transitions between health states still run on the CT
matrix; only the Death column is zeroed.

**Reason:** T4 requires that at `pi_cure = 1` the share of the treated
cohort in drug-free remission at cycle 6 equals 1.00. With mortality active
the cycle-6 cohort is 0.99956, and T4 becomes unreachable by construction
rather than by error — the cure could never peel a full unit from a cohort
that is no longer a full unit. Aliyev's own Induction assumption #2 ("No
chance of Surgery or Death during induction… low risk of bias due to short
lengths of induction phases") makes exactly this simplification for the
equivalent window in every comparator arm, with the same justification. The
suppressed quantity is 4.4e-4 of the cohort over 12 weeks at age 35.

## 2026-08-13 — Drug-free remission costing

**Signed off:** Stone
**Supersedes:** nothing; SPEC.md names the sustained drug-free remission
state but does not price it.

**Change:** a patient in sustained drug-free remission carries Aliyev's
Remission health-state cost ($10.20 per cycle, 2017 USD) and no drug cost
of any kind — no biologic, no conventional therapy.

**Reason:** the state is drug-free, so no pharmaceutical cost applies. It is
not care-free: a cured Crohn's patient in remission still has ambient
CD-related medical contact, which is what Aliyev's $17 PMPM Remission figure
describes (about $265 a year — plainly ambient care, not drug cost, since
biologics run tens of thousands). Charging it is the conservative reading:
it raises the cured patient's cost, which lowers `B` and therefore lowers
the justifiable price. Charging zero would inflate the headline result.

## 2026-08-13 — Relapsed patients are charged a full standard-care course

**Signed off:** Stone
**Supersedes:** nothing; SPEC.md L4 sends relapsed patients back to standard
care without saying whether they are charged induction again on arrival.

**Change:** a patient who relapses out of drug-free remission enters the
full comparator path at the moment of relapse — induction course included,
then maintenance — with their own 2-year cap clock starting then.

**Reason:** L3 already charges the induction course to the non-cured at
cycle 6, on the grounds that a rescued patient clinically requires one. A
patient relapsing after years of drug-free remission requires one at least
as clearly. The alternative — dropping them straight into maintenance —
would give the Treg arm free re-entry to biologic therapy and inflate `B`.
This is the conservative reading and the one consistent with L3.

## 2026-08-13 — Analog comparison before the landmark

**Signed off:** Stone
**Supersedes:** nothing; SPEC.md section 7 gives the decay rule without
addressing analogs that read out earlier than this study's landmark.

**Change:** `analog_comparison_table()` marks any analog whose readout
precedes the 12-week landmark as `comparable = FALSE` and returns `NA` for
its drug-free-remission share rather than an extrapolated number. This
currently affects Ovasave/CATS1 (week 8).

**Reason:** section 7's rule is `pi_cure · exp(−h·t)`, a decay forward from
the landmark. Run backwards it returns a share above `pi_cure`, which this
model cannot support: before the landmark no patient has been declared
cured, and the pre-landmark window is conventional-therapy dynamics (L9),
not drug-free remission. Emitting a number there would be the section 7
error — the right number against the wrong reference point — reintroduced
by the very function written to prevent it.

## 2026-08-13 — Reference comparator priced on Q5104 (Renflexis)

**Signed off:** Stone
**Supersedes:** OPEN_QUESTIONS.md O8, closed as C10; unresolved item U3 in
`data/raw/cms_asp_infliximab_2026.csv.source.yaml`. SPEC.md section 2 names
the reference comparator as "Infliximab, biosimilar pricing base case"
without naming a product, and section 8 lists the unit cost as TO SOURCE.

**Change:** the base case is priced on HCPCS Q5104 (Renflexis,
infliximab-abda) at the current CMS ASP payment limit, $2.6615 per mg
(2026-07 quarter). Three infliximab biosimilars carry payment limits in that
file; this names which one the base case uses. The originator (J1745,
$3.1479/mg) prices scenario S4.

**Reason:** the choice was a decision rather than a lookup — SPEC.md
requires a biosimilar but does not say which, and no sourcing exercise can
settle it. Q5104 is the lowest priced of the three at the current quarter,
which makes the comparator arm the cheapest available and therefore makes
`B` and every justifiable price on the frontier the smallest — the
conservative direction, and the one least likely to overstate what the
therapy is worth. The two higher-priced biosimilars (Q5103 $2.7710, Q5121
$3.0830) would each raise the frontier.

**Effect on reported results:** none. Q5104 was already the value carried in
`R/dosing.R` pending this decision, so every figure in the W4 readout stands
as published. What changes is that the input is now decided and justified
rather than inherited.

## 2026-08-13 — All costs re-based to 2025 USD

**Signed off:** Stone
**Supersedes:** every dollar figure reported before this date, and SPEC.md
section 8's "then re-based to 2025", which had not been implemented.

**Change:** cost inputs arrived on three bases — Aliyev's health-state and
conventional-therapy costs in 2017 USD, and the CMS ASP and Physician Fee
Schedule figures at current 2026 rates. All are now re-based to 2025 USD,
SPEC.md section 2's stated currency year, through medical-care CPI
(BLS CPIMEDNS, `data/raw/cpi_medical_care_annual.csv`). Factors: 2017 to
2025 is 1.220440; 2026 to 2025 is 0.979316.

Re-basing is applied in `R/price_index.R` at the `R/` boundary, never inside
`derive/`. The derive layer continues to reproduce Aliyev's published
per-cycle figures in Aliyev's own dollar year, which its provenance
re-derivation test depends on.

**Effect on reported results:** every dollar figure moves. Central case, at
$100,000 per QALY: A from −$2,507.11 to −$2,655.38; B at h = 5% from
$160,996.86 to $172,041.94; the required cure fraction at a $20,000 course
from 14.0% to 13.2%. Directionally, health-state costs rise 22% while the
CMS-sourced drug and administration prices fall 2%, so the comparator arm
becomes more expensive and the therapy's justifiable price rises.

**Reason:** SPEC.md fixes the currency year and a cost-effectiveness model
cannot mix dollar years across its inputs. Medical-care CPI is the
conventional US deflator for healthcare-sector costs.

**Known limitation, recorded rather than resolved:** the 2025 index average
covers eleven months (October 2025 is absent from the published BLS series)
and the 2026 average seven. Both are documented in the index file's own
sidecar. The eleven-month gap moves the re-basing factor by roughly 0.07%.

## 2026-08-13 — Manufacturing benchmark built without a dose (W5)

**Signed off:** Stone
**Supersedes:** SPEC.md section 8's "Manufacturing benchmark | Range | TO
BUILD (W5) | Triangulated: analogy anchors, techno-economic bottom-up,
revealed prices"; W2 sourcing register item S-5.

**Change:** the benchmark is built from two of the three specified legs.
Analogy anchors come from ten Ham et al. 2020's eight case studies,
converted at the 2018 euro/dollar rate and re-based to 2025 USD. Revealed
prices come from approved autologous CAR-T list prices and one reported
per-dose cost of goods. The **techno-economic bottom-up leg is not built.**

**Reason the third leg is missing:** it requires the Treg dose in cells per
kilogram, which S-5 identified as the single most important input. That dose
is not public. All three registered TRX103 trials (NCT06721962 Crohn's,
NCT06462365 GvHD, NCT07427628) describe their arms only as "Dose level
1/2/3" and disclose no cells-per-kilogram figure; the registry records were
retrieved and searched directly. Building the leg would require inventing
the dose, which is precisely what a benchmark whose whole purpose is to be
compared against a sourced price must not do.

**Consequence:** the benchmark is a range, which is what SPEC.md section 8
asks for. It spans $12,266 to $380,336 per course in 2025 USD, with the
allogeneic anchors between $12,266 and $68,958 and a median of $38,634. The
two-order-of-magnitude spread S-5 predicted is present and is driven by
whether a batch amortises across many treatments or serves one.

**L8 is unaffected.** No pricing function reads any of this; T12 now greps
five files in the pricing path against every name the benchmark module
exports, not two files against a keyword list.

## 2026-08-13 — Refractory co-primary adjusted at induction only

**Signed off:** Stone
**Supersedes:** nothing in SPEC.md; this records how section 2's
"refractory co-primary, run identically" (also scenario S2) is implemented.

**Change:** the refractory population differs from the biologic-naive base
case in its induction transition matrix only. Multipliers are derived from
UNITI-1 (anti-TNF-refractory) against UNITI-2 (conventional-therapy
failure), two trials sharing a protocol and endpoints and differing only in
prior therapy, from their own posted per-arm counts: response 0.608,
remission 0.520 on the active arm. Maintenance transitions are unadjusted.

**Reason maintenance is unadjusted:** IM-UNITI randomised only week-8
responders, so its maintenance figures are conditioned on induction success.
Using them as a maintenance multiplier would condition a population
adjustment on response — the conditional-denominator error that guard 3 and
T4 exist to prevent, in a new place. No other like-for-like source was
found. Recorded as OPEN_QUESTIONS.md O10.

**Consequence, stated because it is easy to misread:** the two co-primary
populations currently differ by under 1% on B (0.46% with the cap on, 0.73%
with it off), because an induction-only adjustment acts over four cycles of
a sixty-five-year horizon and the two-year maintenance cap returns both
populations to conventional therapy regardless. **This is a statement about
the available evidence, not a finding that the populations are alike.** A
maintenance multiplier would very likely separate them materially.

**Direction:** leaving maintenance unadjusted understates the refractory
penalty on the comparator, which makes the comparator look better and the
Treg product's justifiable price lower. Conservative.

**Independent provenance check:** Aliyev's transcribed UST week-6 response
parameter carries Beta(116, 93). UNITI-2's ~6 mg/kg arm reports exactly 116
responders of 209, leaving 93 non-responders, confirming that the base case
this repository inherited is UNITI-2 and that UNITI-1 is its correct
refractory counterpart. Asserted in tests/testthat/test-refractory.R.

## 2026-08-13 — Scenarios S4, S5 and S7 built; S3 and S6 not

**Signed off:** Stone
**Supersedes:** nothing; this records the disposition of SPEC.md section 5's
scenario grid.

**Built.** S4 prices the comparator on the originator (J1745) rather than
the biosimilar. S5 runs ustekinumab and adalimumab as reference comparator,
each on its own FDA-label regimen and its own induction readout window
(week 6 and week 4 respectively, per Aliyev's parameter table) rather than
infliximab's -- reusing infliximab's window for another drug would repeat
the W3 defect where the dosing schedule and the transition window described
different numbers of weeks. S7 substitutes the pre-pandemic 2019 NCHS life
table for the 2023 base case.

**S3 (redosing on post-cure relapse) is not built.** L4 already states that
redosing "requires an efficacy premise no data supports". Implementing it
would require assuming a redose cure probability, and the only available
value is the initial cure fraction, which is the parameter being solved for.
That makes the price appear on both sides of the frontier equation and turns
a stated scenario into an assumed one. The base case charges relapsed
patients a full standard-care course instead, which is the conservative
reading and is already recorded.

**S6 (administration bundle) is not built.** It is blocked on
OPEN_QUESTIONS.md O3 (preconditioning dose) and O4 (whether a Treg infusion
qualifies for observation billing), both owned by Dula and both unsourced.
No part of it can be built without inventing one of those values.

**What the scenarios show.** Across every scenario, at $100,000 per QALY and
a 5% relapse hazard, the required cure fraction at the median manufacturing
benchmark stays between 22.8% and 24.7% against a base case of 24.0%. The
originator-pricing scenario moves the comparator's lifetime cost by only
0.7%, because the two-year maintenance cap means drug price acts on a small
share of a lifetime horizon. No scenario changes any conclusion.
