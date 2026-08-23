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

## 2026-08-13 — Maintenance dose was charged to dead biologic mass

**Signed off:** Stone (defect found by adversarial review, corrected before merge)
**Supersedes:** the cap-off leg of every cost figure reported before this
entry, including `output/tables/comparator_ifx_trace.csv`,
`price_frontier.csv`, `required_cure_fraction.csv` and `scenarios.csv` as
first written. Cap-on figures move by less than $6 and are superseded only
to the precision of their fifth significant figure.

**Change:** `one_cycle_cost_usd()` charged the maintenance dose against
`sum(occupancy_start_biologic)`, the whole biologic cohort, including the
Death mass accumulated in it. Death is absorbing in the maintenance matrix
and the Moderate-Severe redirect gives it no exit path from the biologic
cohort, so that mass grows monotonically across the horizon and was billed
infusion drug plus administration on every dose cycle. The adjacent line
already charged the conventional-therapy drug cost to living CT mass only;
the dose charge now mirrors it.

**Effect:** lifetime discounted comparator cost at the 8-week window falls
$495.00 with the cap off ($141,589.85 to $141,094.84, -0.35%) and $5.35
with the cap on. A moves $1.71, B moves $111.34, and P* at a cure fraction
of 1 rises $113.06 (cap off, $100,000 per QALY, h=0.05). QALYs are
unchanged. The error was conservative: it overstated comparator cost and so
understated the justifiable price. No scenario changes any conclusion, and
`analysis/verify_readout.R` confirms the readout figures still match the
regenerated outputs at their reported precision.

**Reason:** a straightforward accounting error, not a modelling choice — a
dead patient cannot receive an infusion. Recorded here rather than silently
fixed because it invalidates already-reported numbers, following the
precedent of the conventional-therapy drug cost entry above. Covered by a
property test in `tests/testthat/test-markov-engine.R` asserting that Death
mass in the start-of-cycle vector cannot change the cycle cost; the test
fails against the previous implementation.

## 2026-08-21 — Refractory co-primary population retired

**Signed off:** Stone, after deliberation

**Supersedes:** SPEC.md v1.0 §2's population row ("Biologic-naïve base case;
refractory co-primary, run identically") and §5's S2 row; the 2026-08-13
amendment "Refractory co-primary adjusted at induction only", which
described how S2 was implemented rather than whether it should exist;
`docs/results_readout.html`'s "Refractory co-primary population" section
as first published; and OPEN_QUESTIONS.md O10, closed below as moot.

**Change:** the refractory-adjusted population is no longer run as a
co-primary output. §2's population row is restated instead: the model has
one population, and its comparator transition probabilities are already
estimated from trial data that pools biologic-naïve and biologic-experienced
patients rather than one uniform stratum — UNITI-1 (anti-TNF-refractory) and
UNITI-2 (anti-TNF-naïve, conventional-therapy failure) both feed the induction
and maintenance parameters this model inherits via IM-UNITI. This is now
stated as a limitation of the underlying evidence base rather than
represented as a solved contrast between two cleanly-separated populations.
`docs/results_readout.html`'s comparison table is removed and replaced with
a Limitations entry describing the mixed-population source data.
`R/refractory.R`, `analysis/run_refractory_coprimary.R`,
`tests/testthat/test-refractory.R` and the two output tables they produce
are left in place, unchanged and still passing — they are accurate as far
as they go, just no longer reported as a co-primary result.

**Reason:** already recorded, not newly discovered, by the 2026-08-13
amendment this one supersedes: the refractory adjustment this repository can
derive from published trials covers induction only, because every
randomised maintenance trial in the refractory setting enrolled induction
responders and using it would commit the conditional-denominator error
guard 3 and T4 exist to prevent. That amendment's own stated consequence —
the two co-primary populations differed by under 1% on `B`, "a statement
about the available evidence, not a finding that the populations are
alike" — is the basis for this decision: an induction-only adjustment was
never able to produce a genuine refractory-population estimate, only a
near-identical one that risked being read as though it were.

**OPEN_QUESTIONS.md O10 closed as C11**, moot now that no separation between
the two populations is attempted.

## 2026-08-14 — Scenario S7 mixed two life-table vintages

**Signed off:** Stone (defect found by adversarial review round 2, corrected
before merge)
**Supersedes:** the S7 row of `output/tables/scenarios.csv` as first written,
the S7 line of the results readout, and the readout sentence describing how
far the mortality table moves the required cure fraction.

**Change:** `value_of_one_cure_usd()` took no life-table vintage and loaded
`load_life_table(raw_dir)`, which defaults to the base 2023 NCHS table. S7
builds its standard-care grid and comparator on the pre-pandemic 2019 table
and passes the vintage to both, but had no way to pass it to `B`. The cured
patient therefore died on the 2023 table while the standard care that same `B`
differences against used 2019. The argument is now threaded through
`value_of_one_cure_usd()`, `price_star_usd_per_course()`,
`frontier_intercept_from_model()` and `run_treg_trace()`, and passed from
`analysis/run_scenarios.R`.

**Effect:** S7 `B` at $100,000 per QALY moves from $167,229 to $172,606 (+3.2%);
at h = 0 it moves +2.6% and at h = 0.10 +3.4%. The S7 required cure fraction at
the median allogeneic benchmark moves from 24.7% to 24.0%. `A` is unaffected:
it is evaluated at a cure fraction of zero, where there is no drug-free
remission mass for a life table to act on.

**Consequence for the reported conclusion, recorded because it is not merely a
cell change.** Corrected, S7 lands on 24.0% — the base case figure. The
apparent 0.7-point sensitivity to the mortality table was the defect, not a
result. The readout previously said the comparator drug, drug price and
mortality table each shift the required cure fraction by about one percentage
point; the mortality table does not move it at all to the precision reported.
No other scenario is affected, because S7 is the only one that varies the
vintage.

**Reason:** an argument that existed on two of the three call sites a scenario
needs. Recorded here rather than silently fixed because it invalidates an
already-reported figure and an already-stated conclusion.

## 2026-08-21 — Budget impact analysis added as aim A6 (SPEC.md v1.1)

**Signed off:** Stone
**Supersedes:** SPEC.md v1.0 §2 (single analytic frame, perspective and
discounting convention); §5's swept-parameter and scenario tables; §6's
five-aim list; §8's parameter register; §9's open items; §10's twelve
acceptance criteria. SPEC.md is bumped to **v1.1**. Every previous change to
this specification was a clarification, correction or reduction and the version
correctly stayed at 1.0; this is the first additive scope expansion. Nothing in
§1 is superseded: the frontier `P*(π, h, λ) = A(λ) + π·B(h, λ)` remains the
study's primary, prior-free result and is unchanged.

**Change:** a population-level budget impact analysis is added as aim A6,
alongside — not in place of — the price frontier. New locked decisions L10–L16.
New scenarios S8 and S9. New open items O11–O15. New acceptance criteria
T13–T18. A new §2a states the BIA's analytic frame separately from §2's.

**A6 is scenario-conditional and is labelled as such in every artifact.**
Unlike A1–A5 it requires committing to a price, a cure fraction, an uptake
level and a reporting horizon. Price is taken from this study's own
`P*(π, h, λ)`; the cure fraction is swept as in §5; the uptake level is swept
and only its shape is locked; the reporting horizon is a stated analyst choice
with a designated base case. Each cell carries the required cure fraction that
price implies (A3's machinery), so a reader can see which budget cells describe
a defensible adoption at all.

**The reporting horizon is a stated choice, not a swept parameter (L10).** An
earlier draft of this amendment treated the horizon as a swept parameter by
analogy with π. That analogy is wrong and is withdrawn: π is epistemic — a fact
about the world nobody knows — while a time horizon is a normative reporting
choice determined by the decision-maker's budget cycle, and CHEERS 2022 item 9
asks the analyst to state and justify it rather than to decline to. The base
case is three years, the ISPOR/AMCP centre of mass; one and five years bracket
it; together these are the budget impact analysis proper. Ten and thirty years
are reported as an extended offset-accrual projection and are labelled as such:
they exist because a short window applied to a one-time potentially curative
therapy measures the front-loading rather than the affordability, the critique
underlying the cell- and gene-therapy literature on amortised, annuity and
outcomes-based payment models and ICER's methods work on single- and short-term
transformative therapies. **Ten and thirty are round exploratory endpoints
chosen for the readability of the offset-capture progression. They are not
anchored to any figure this study publishes.** In particular, this study
publishes no thirty-year price frontier: every `A`, `B` and `P*` in this
repository is computed at the lifetime horizon and only there, and the thirty-
and forty-year runs in `output/tables/comparator_ifx_trace.csv` are
comparator-arm cost and QALYs alone. A thirty-year BIA's current-care world is
comparable to that published comparator figure; its Treg world and the frontier
are not. **The citations underlying this paragraph are sourcing-register item
S-8 and are not yet retrieved; this rationale must not enter a manuscript
before they are.**

**The headline of A6 is a progression, not a figure, and it is a cost
quantity.** A6 reports first the share of the lifetime cost offset captured at
each horizon: `offset_captured(H) = D(H)/D(lifetime)`, where `D(H)` is the
discounted cumulative current-care-world-minus-Treg-world cost per treated
patient excluding the course price, and `D(lifetime) = P*(π, h, λ = 0)`.
Willingness to pay does not enter — a budget holds no QALYs, which is the same
logic T13 rests on. The statistic depends on π, h and the cap setting and not
on the eligible population, which makes it the one headline finding of this aim
that survives O11 never being sourced.

**Discounting follows the horizon's class (L11).** One to five years:
undiscounted base case, per ISPOR — a budget forecast is nominal cash flow.
Ten and thirty years and the lifetime leg: 3% base case, per SPEC.md §2 — that
class is not a budget forecast, undiscounting a backloaded offset over decades
overstates it (the non-conservative direction), and under 3% the long arm
converges to the lifetime leg where T13's identity holds exactly. Both columns
are produced at every horizon, so the convention is a decision about which
figure the readout leads with rather than a computation that hides an
alternative. The base-case convention changes between the five- and ten-year
rows of the same table; this is deliberate and is marked in the table.

**Uptake is a single adoption wave (L12, L15).** A linear ramp over a fixed
five-year ramp period to a swept terminal share, after which nobody further is
treated. The alternative reading — a terminal annual rate persisting for the
full horizon — would treat several times the eligible pool over thirty years
and is not well-defined until O15 closes. **The five-year ramp period is
itself a chosen level, not structure**, and is recorded as an assumption under
an open question rather than defended as a derivation. **Direction:** a single
wave produces the smaller long-horizon expenditure and therefore the more
favourable-looking thirty-year figure — the non-conservative direction, chosen
for coherence rather than for conservatism.

**L8 is unaffected and T12's scope is unchanged.** `R/budget_impact.R` takes
the course price as a required argument with no default, supplied by
`analysis/run_bia.R` from `output/tables/price_frontier.csv` and, separately
labelled, from an observed-analog-price axis. **The BIA files are deliberately
NOT added to T12's file set**, which stays the five `R/` pricing-path files it
covers today: T12 greps for raw-data basenames as well as function names, and
adding an analysis script that legitimately reads a raw price file would make
T12 fail on first run and invite weakening it. The invariant is instead
asserted directly in `tests/testthat/test-budget-impact.R`: `R/budget_impact.R`
supplies no default for the price and calls no export of the benchmark module.
For the avoidance of doubt, **using benchmark values downstream of a computed
frontier is already sanctioned and needs no amendment** — §6 A3 is defined as
"required cure fraction at each manufacturing benchmark" and does exactly that.
L8 forbids a pricing *function* reading the benchmark, which is what T12
enforces and what `R/frontier.R`'s own header describes.

**T13 is the gate, and it is a statement about one leg.** At λ = 0, net
monetary benefit is the negative of cost, so `A(0) + π·B(0)` is a pure
discounted lifetime cost difference and the net budget impact of treating one
patient is exactly `price − P*(π, h, λ = 0)`. λ = 0 is the budget corner of
§1's own equation. The identity holds at the lifetime horizon and only there,
because `A` and `B` are lifetime quantities, so the analysis retains a lifetime
leg as a test fixture that is never reported as a budget impact.

**T18 replaces an earlier draft's nesting property, which was vacuous.** That
draft asserted that the streams at one horizon equal the leading years of the
streams at a longer one — but streams are computed once at the lifetime horizon
and truncated at reporting time, so both sides were the same vector and the
assertion could not fail against any permitted implementation. T18 instead
compares an independently re-run `run_comparator_trace()` at each horizon
against the prefix sum of the lifetime stream at the corresponding cycle index,
sharing no truncation logic between the two routes. Its principal target is the
induction-offset indexing error: `total_cycles` governs the maintenance loop
only, so truncating at `round(H · cycles_per_year)` rather than at
`induction_cycles + round(H · cycles_per_year)` is silently wrong by two to
four cycles in a direction that varies with the induction window. **That index
reproduces the `horizon_years` argument's own semantics and is not the
calendar-exact reporting boundary** — §2a keeps the two apart, and A6's
`reporting_horizon_years` column is the calendar-exact one.

**Monotonicity in the horizon is deliberately not asserted, at any relapse
hazard.** Two independent mechanisms make the annual incremental cost
difference able to turn against the Treg world. First, a patient relapsing out
of drug-free remission is charged a full standard-care course on re-entry —
induction included, with their own two-year cap clock starting then — while
their comparator-world counterpart, induced at t = 0, returned to conventional
therapy at year two. Second, and independent of any relapse: under L9 the
Treg arm's whole cohort spends twelve weeks on conventional therapy, so the
non-cured enter standard care at the landmark and their cap clock expires
twelve weeks later than the comparator world's; in that window the Treg world
is still paying biologic and the comparator world is not. The second mechanism
operates at a relapse hazard of zero and at a cure fraction of zero. There is
therefore no corner of the grid where monotonicity is guaranteed, and the
offset-capture share inherits the same behaviour: it is neither monotone in the
horizon nor bounded above by 100%, and the readout states how to read a dip or
an above-100% cell rather than suppressing one.

**T15 is deliberately weaker than first drafted.** "Undiscounted ≥ discounted"
holds for a non-negative gross expenditure stream and NOT for a net-impact
stream, since undiscounting weights later years more heavily and later years
are where the offsets fall. T15 asserts the inequality on gross expenditure in
each world separately and asserts no sign for the discounting effect on the net
series.

**What A6 does not resolve.**

The eligible population is not sourced (O11) and no uptake data exist for a
first-in-class one-time therapy in this indication (O12). A6 therefore reports
against a schedule of explicitly illustrative round population sizes and as
per-member-per-month on a stated one-million-member plan — the same treatment
`assumed_trial_cost_usd` already gives O2 in A4 — rather than a single figure
carrying false precision. Sourcing is recorded as S-6: US prevalence and the
moderate-to-severe share are sourceable and are real work with a named owner;
the share of moderate-to-severe patients who would be offered and accept a
one-time cell therapy is not sourceable for a product with no label and no
efficacy data, and is swept rather than assumed.

**A6 also does not resolve, and must not be read as resolving, the
mixed-population limitation recorded in the 2026-08-21 amendment above.** The
budget impact analysis inherits the comparator's transition probabilities
unchanged, and therefore inherits in full the limitation that those
probabilities are estimated from trial populations pooling biologic-naïve and
biologic-experienced patients rather than one uniform stratum — UNITI-1
(anti-TNF-refractory) and UNITI-2 (anti-TNF-naïve, conventional-therapy
failure) both feed the induction and maintenance parameters this model inherits
via IM-UNITI. **The gap is more consequential in A6 than on the frontier, which
is why it is restated here rather than left to be inherited.** A payer's
eligible population is defined by treatment line — who has failed what — and
that is precisely the distinction the source trials pool. Every A6 figure
therefore counts a denominator defined on a stratum whose cost dynamics the
numerator does not separately describe. No refractory-specific budget impact is
reported, for the reason that amendment gives: the only adjustment derivable
from published trials covers induction alone, and extending it to maintenance
would condition the adjustment on response — the conditional-denominator error
guard 3 and T4 exist to prevent. This is stated as its own limitation in the
readout's budget-impact section, not only in the readout's general Limitations
list, so that a reader of that section alone is not left to find it elsewhere.

Over the ten- and thirty-year windows the eligible pool is additionally held
fixed, with no incidence or turnover modelled (O15, L16). That is defensible
over one to five years and is a stated limitation beyond it.

**Direction, stated because a payer will read this.** L13 displaces infliximab
biosimilar Q5104 alone, the cheapest agent in the model (C10), rather than a
mix. Scenario S5 showed ustekinumab and adalimumab comparators both raise `B`.
Displacing the cheapest agent yields the smallest offset and the largest net
budget impact — conservative for an affordability question, as C10 was
conservative for a value question.

**Effect on reported results: none.** No figure in A1–A5 changes. The engine
work this amendment authorises is additive — per-cycle cost streams alongside
the existing scalars, an opt-in argument on the Treg arm, and three new unit
suffixes — and T17 requires the streams to sum to those scalars to within 1e-6.
Existing outputs are regenerated only so their spec hashes match v1.1; that
regeneration requires re-running the 1,000-draw probabilistic analysis first,
since `analysis/run_aims.R` reads two `_w6` files that `analysis/run_psa.R`
produces and that are not committed to the tree.

**G6's exemption for A6, recorded so it is not mistaken for coverage.** §6 now
names A6 with an output file that does not exist, and `uncovered_aims()`
clears it because this entry contains the string "A6". That is the sanctioned
amendment branch, not a defect — but the exemption never expires, so **G6 will
never again assert that `budget_impact.csv` exists.** The gate for the session
that builds A6 is T13 passing and `budget_impact_reconciliation.csv` existing,
not a green G6.

## 2026-08-23 — A6's undiscounted leg was discounted across adoption cohorts

**Signed off:** Stone (defect found while building an unrelated aim, verified
against `main` and corrected on its own branch)
**Supersedes:** every `discounted = FALSE` row of
`output/tables/budget_impact.csv` at a reporting horizon of three years or
more, as first written; the budget-impact section's 3-year base-case table in
the results readout; the readout's horizon-path sentence; and the readout's
stated conclusion about the direction in which discounting moves the net.

**Change:** `stacked_cohort_expenditure_usd_per_year()` brings adoption cohort
`k` to t = 0 with `discount_factor_years_to_discount_factor(k - 1)`, which
reads the rate in force rather than taking it as an argument. Its own docstring
states the contract that follows: the undiscounted leg is produced by running
the whole computation at a zero rate. `analysis/run_bia.R` honoured that
contract for the per-patient TRACES — `treg_undiscounted` is built inside
`with_zero_discounting()`, and the comparator's undiscounted stream comes from
its own zero-rate leg — but not for the STACK, which it called at the ambient
3%. The undiscounted leg was therefore undiscounted within each cohort and
discounted between them, an accounting that corresponds to no convention this
study states. The two world stackers now have named undiscounted counterparts,
`treg_world_undiscounted_expenditure_usd_per_year()` and
`current_care_undiscounted_expenditure_usd_per_year()`, on the precedent of
`standard_care_undiscounted_cost_stream_grid()`, and `analysis/run_bia.R`
carries the matching pair alongside each leg's streams.

**Effect:** confined entirely to undiscounted rows at horizons that reach a
second adoption cohort. No discounted row moves — all 11,760 are bit-identical
after regeneration — and no 1-year row moves in either leg, because the first
cohort sits at `k - 1 = 0` and takes a factor of 1 at every rate. At the
readout's central cell (cap on, h = 5%, π = 0.50, frontier price, u = 0.25,
100,000 eligible) the cumulative net budget impact rises from $1,125,628,703 to
$1,159,769,592 at three years (+$34.1M, +3.0%) and from $1,769,715,050 to
$1,879,092,360 at five (+$109.4M, +6.2%); the 1-year figure is unchanged at
$399,147,209. Every cell of the 3-year base-case table moves by between +2.98%
and +3.03%; across every undiscounted final-year row at three years or more the
movement spans +2.98% to +6.28%. The offset-capture progression does not move
at all, being defined at 3% on both legs. The defect was anti-conservative for an
affordability question: it understated what a payer would nominally pay.

**Consequence for the reported conclusion, recorded because it is not merely a
cell change.** The readout said that over three years the discounted figure was
the larger of the two, "because the offsets that discounting shrinks arrive
later than the price it does not." Corrected, the three-year ordering is the
other way round — $1,128.0M discounted against $1,159.8M undiscounted — because
the term that dominates over that stretch is the discounting of each later
cohort's whole contribution back to t = 0, which the nominal leg does not apply
at all. The broader claim the sentence was making survives and is in fact
sharpened: discounting still has no fixed sign here, and now changes sign
inside a single row, the discounted figure being larger at one year and at
thirty and smaller at three, five and ten. That sentence is rewritten along
with the figures.

**`budget_impact_reconciliation.csv` is unaffected, and the reason is the
defect's own shape.** The reconciliation legs are one cohort of one patient
adopting at t = 0, so `k - 1 = 0` and the cohort factor is 1 whatever the rate;
the file regenerates byte-identical and T13 still closes to 7.0e-10 dollars
over all 48 lifetime legs. This is why the study's own gate could not see the
defect: T13 is stated on the single-patient fixture, which is precisely the
fixture in which a cohort-placement error is invisible.

**Reason:** a contract stated in a docstring and honoured at two call sites out
of three. Recorded here rather than silently fixed because it invalidates
already-reported figures and an already-stated conclusion. Covered by a
property test in `tests/testthat/test-budget-impact.R` asserting that the
undiscounted world expenditures do not depend on the rate in force, that they
differ from the discounted convention once a second cohort adopts, and that the
two coincide at the single-cohort fixture; the test fails against the previous
implementation.

---

## 2026-08-23 — Alternative payment arrangements added as aim A7 (SPEC.md v1.2)

**Signed off:** Stone
**Supersedes:** SPEC.md v1.1 §2a (heading, opening sentence and four added
rows); §5's scenario table; §6's six-aim list; §8's parameter register; §9's
open items; §10's eighteen acceptance criteria. SPEC.md is bumped to **v1.2**.
v1.1 was the first additive scope expansion; this is the second, and nothing in
§1 or §2 is superseded: the frontier `P*(π, h, λ) = A(λ) + π·B(h, λ)` remains
the study's primary, prior-free result and is unchanged, as is §2a's budget
impact frame, which A7's budget leg inherits whole.

**Change:** alternative payment arrangements are added as aim A7, alongside —
not in place of — the budget impact analysis. New locked decisions L17–L21. New
scenarios S10 and S11. One new open item, O16. New acceptance criteria T19–T21.
No new analytic frame section: A7's budget leg is governed by §2a and its
per-cure frontier by §2, and §2a's heading and opening sentence are widened to
say so rather than a §2b being written.

**A7 is not a second budget impact analysis and must not be read as one.** Its
budget leg is A6's budget impact analysis under different payment terms, and it
inherits in full every A6 limitation: the unsourced eligible population (O11),
the unsourced uptake trajectory (O12), the single adoption wave (L15), the
fixed pool over the extended projection (L16), the ASP-versus-net-commercial-price
gap (O14), and the mixed-population limitation the A6 amendment restated for
A6's own reasons. **A7 resolves none of them.** The readout states this in the
section itself rather than leaving it to be inherited.

**What A7 changes, and what it does not, stated in that order because the
second is larger.** No model quantity changes. `A`, `B`, `P*` and every A1–A5
figure are untouched; the two-fate split, the relapse mechanic and the
per-cycle cost streams are untouched. **A6's headline,
`offset_captured(H) = D(H)/D(lifetime)`, does not move by one basis point** —
§2a defines `D(H)` as excluding the course price, and a payment arrangement
changes only the price leg. What changes is the timing and the conditioning of
that leg, and therefore what share of the price falls inside a reporting
window.

**The installment leg is a re-timing, not an analysis, and it is reported as
such (L17).** Payments are placed by the cohort stacker on each cohort's own
clock: cohort `k`'s payment `j` lands in calendar year `k + j − 1`, so the
schedule seen inside a window of length `H` is truncated at `H − k + 1`
payments and differs cohort by cohort. The lump-minus-installment difference is

    Δ(H) = price · Σ_{k ≤ min(K,H)} treated_k · v_a^{k−1} · [1 − (1/a_c) · Σ_{j ≤ min(N, H−k+1)} v_a^{j−1}]

with `a_c` built from the CONTRACT's financing rate and `v_a` from the analysis
rate in force. **The bracketed factor — equivalently the difference expressed
as a SHARE OF THE PRICE — contains no term from the disease model**: not the
cure fraction, not the relapse hazard, not the maintenance cap, not the
willingness-to-pay threshold, not a cost stream. It is a function of the
schedule, the two rates, the uptake vector and the horizon alone, and every
input to it is already published in `budget_impact.csv`. **The difference in
dollars is not invariant, because it is proportional to the price and A7's
first price axis is `P*(π, h, λ)`, which varies across the reported cells by a
factor of fourteen; the dollar figure is constant only on the observed-analog
axis, where the price is a single number.** T19(c) asserts the invariance as a
share of the price on both axes, and the dollar identity on the analog axis
only. **The difference is printed because a reader should not have to do the
arithmetic, not because it is a finding.**

**On the uptake ramp an installment reduces the reported impact at every
horizon the budget impact analysis proper reports, on both discounting
columns.** Because the last cohort adopts in year 5 and its schedule runs to
year `5 + N − 1`, the whole schedule is inside the window for every cohort only
from `H = ramp + N − 1` — nine years at the five-year base case, where the
discounted column returns to exactly the lump-sum figure and the undiscounted
column reaches its ceiling of `N/a_c`. At one, three and five years the
installment therefore always lowers the reported figure. **The undiscounted leg
first exceeds the lump sum between the seventh and eighth year — the crossing
and the full-inclusion horizon are two different dates and are not to be
conflated** — so the first reported horizon at which the crossing is visible is
ten years, and there only in the undiscounted column, which L11 makes a
labelled sensitivity rather than the base case at those horizons. **The
opposite reading — that the five-year figure rises — is a property of the
single-cohort reconciliation fixture and of nothing on the reported grid**, and
both are printed side by side for exactly that reason.

**L11's two columns are what separate a re-timing from a price cut, and this is
the clearest demonstration of it in the study.** Once the whole schedule is
inside the window, a present-value-neutral installment leaves the discounted
column unchanged to the cent and raises the undiscounted column by the
financing charge, while an interest-free schedule leaves the undiscounted
column unchanged and lowers the discounted column by an equivalent per-course
discount. Each arrangement is invisible in one column and unmistakable in the
other. An interest-free installment is not a payment arrangement but a
manufacturer forgoing the time value of money, and is reported as its
equivalent per-course discount.

**The one genuinely new result on the installment side is an inversion of A6's
own headline.** Under a schedule paying, in the patient's own year `m`,
`price · (D(m) − D(m−1)) / D(lifetime)`, the cumulative net budget impact at
every reported horizon is `(price / P*(π, h, λ = 0) − 1)` times the cumulative
offset, and at `price = P*(π, h, λ = 0)` it is exactly zero at every horizon
simultaneously — **and, because the schedule is proportional to the offset
cohort by cohort, this holds over the whole cohort stack for any uptake
vector**, which the equal-payment installment does not. **A6's offset-capture
progression, read as a distribution over payment timing, is the schedule that
makes a justified cure budget-neutral in every window.** That is T20 and it is
A7's gate. **It is a reference schedule and not a contract proposal**: it
depends on π and h, which nobody knows at contract time, and it presumes both
parties accept this model. Four qualifications travel with it wherever it
appears: it is defined on the discounted leg only, because
`D(lifetime) = P*(π, h, λ = 0)` is a present value at t = 0; it requires
`D(lifetime) > 0`, which fails at low cure fractions where the intercept
dominates; the offset-capture progression is **not** asserted to be a
cumulative distribution function — §2a and `offset_captured_share()` both
decline to assert monotonicity, and the schedule's non-negativity is checked on
the reported grid rather than assumed; and the schedule is multi-decade, with
**between one and twenty-one per cent of the price still outstanding after
thirty years — a median of about six per cent across the two hundred and forty
discounted thirty-year scenario groups**, not the one per cent of the most
favourable cell.

**Outcomes-based payment is evaluated in expected-value cohort terms, and that
is exact rather than an approximation (L18).** Payment enters the budget
linearly in the individual outcome indicator, so no distribution over
per-patient outcomes is required. **None is constructed, and no variance,
budget-predictability or risk-reduction claim is made.** A binomial band around
a cohort share would be roughly three orders of magnitude smaller than the
epistemic uncertainty this study actually carries — π is swept across 101
points, not sampled — and would report precision the study does not have. It
would also require reading π as a per-patient probability rather than as a
share of all treated patients, which is the move L2, guard 3 and T4 exist to
prevent. **The risk-transfer question is answered by the sweep instead:** on the
discounted lifetime leg the spread of net budget impact across `π ∈ [0,1]` per
treated patient is `B(h, 0)` under a lump sum and exactly zero under a
full-rebate contract priced at the rate T21 identifies. At the one-, three- and
five-year horizons the spread is the corresponding range of `D(H)` and is
smaller; the lifetime-leg qualifier is stated wherever the result is.

**One time convention governs every conditional payment (L21).** A rebate
triggered at observation point `T`, measured from the landmark, is settled at
patient-time `T + 12/52` years from adoption, carries that date's discount
factor, and lands in that calendar year — so cohort `k`'s rebate falls outside
a reporting window whenever `k + T` exceeds it, and a one-year budget impact of
a two-year-observation contract shows the entire price and none of the rebate.
That is the mirror image of the offset-capture problem and is a finding rather
than a defect. The convention is not a tidying choice: the twelve-week gap
between adoption and the landmark is worth 0.68% at 3%, and this study has
already been bitten by it once — `value_of_one_cure_usd()` records that a `B`
discounted to the landmark rather than to t = 0 broke T2 by about $1,100 while
leaving T1 and T3 untouched. The justified per-cure price follows from the
convention and from L20's present-value test:

    P*_cure(π, h, λ, T, ρ)  =  (A(λ) + π·B(h, λ)) / (1 − ρ·(1 − π·e^{−hT})·v^τ),   τ = T + 12/52

which returns `P*` exactly at ρ = 0, is a ratio of two affine functions of π
rather than a hyperbola, and is finite across the whole cure-fraction sweep
including π = 0 — where a convention treating the rebate as coincident with the
invoice would be singular. **Finite is not the same as well behaved, and this
amendment does not claim it is:** the denominator lies in `[1 − ρv^τ, 1]` and is
strictly positive, so the per-cure price carries the sign of `A(λ) + π·B(h, λ)`
at every cure fraction and is negative below `π = −A(λ)/B(h, λ)`, exactly as
`P*` itself is. **No positive price per cure is justified there**, and the
readout reports that sign condition rather than the value at π = 0, which with
a negative intercept is a large negative number. **Nor is the per-cure price
monotone in the observation point or rising in the relapse hazard.** It falls in
the hazard, because `B(h, λ)` falls with `h` far faster than the rebate
denominator does, and at low hazards it falls in the observation point as well;
it rises in the observation point only where `π·h·e^{−hT}` exceeds
`ln(1.03)·(1 − π·e^{−hT})`. The readout prints the surface and asserts no
direction on it. The separate and correct directional claim in this amendment
is L19's, about the trigger's exclusion of background mortality raising the
**expected payment**, which is a statement about expenditure at a given price
and not about the justified price.

**The unit, and its two denominators.** `_usd_per_cure` is added to
`ALLOWED_UNIT_SUFFIXES`, which SPEC.md §1's own table has declared for `B`
since v1.0 and which no identifier in the repository has ever carried. It
applies to the full-rebate leg only: at a partial rebate the contract's
headline figure is an invoice per treated patient and carries
`_usd_per_course`, because a partial-rebate payment is neither per course nor
per cure and naming it either would be the conflation guard 2 exists to catch.
**At the landmark a success is a cure in L2's sense; at a later observation
point a success is a patient still in drug-free remission then, a strictly
smaller population.** Two denominators are therefore declared —
`cured_patients_at_landmark` and `sustained_remitters_at_observation` — because
this project's recorded failure mode is a share of a subset reported as though
it were a share of the whole, and one suffix over two populations is that shape
exactly. `_usd_per_cure` is **not** added to `DIMENSIONLESS_RATIO_SUFFIXES`;
that is the reclassification defect `R/units.R` documents at length for
`_usd_per_year`. **No existing identifier is renamed:** `value_of_one_cure_usd()`
and `required_cure_fraction()`'s `slope_b_usd_per_course` keep their historical
names, which are inconsistent with §1's unit table and are left that way
deliberately — renaming the latter would combine a per-course and a per-cure
argument in a function that is neither a named converter nor unit-suffixed,
turning guard 2 red on correct code, and renaming the former would change a
committed output column appearing in four committed CSVs and ten scripts and
tests.

**What the units guard does and does not cover here.** `unnamed_converters()`
flags a function combining a per-course and a per-cure price only when that
function is neither a named converter **nor itself named with a permitted unit
suffix** — the third exit `R/units.R` documents on the reasoning that an
undeclared return unit is what hides a conflation. A7's per-cure functions are
unit-suffixed by house style and are therefore outside the guard's reach; the
named converter `usd_per_course_to_usd_per_cure()` and the guard-3
declarations, not guard 2, are what carry the denominator discipline on this
leg. This is recorded because the alternative — asserting the guard catches
what it does not — is how a guard stops being read.

**Why A7 is an aim rather than columns on A6.** The installment figures are
recoverable from `budget_impact.csv` by arithmetic, and on that leg alone this
would be scenario S10 and nothing more. The outcomes-based leg is **not** so
recoverable: the rebate settles in each cohort's own calendar year, so a
reporting window can contain some cohorts' rebates and not others, and the
aggregate is not any single effective price applied to the standard cohort
stack. What does not fit inside A6 at all is the per-cure justified price: it
has no time axis, no population, no uptake path and no reporting horizon; it is
a ratio of two affine functions of the cure fraction where every published
frontier figure is affine; and its unit is `usd_per_cure`, which §1's own table
declares for `B` and which did not exist in `R/units.R` until this amendment.
**The precedent is A2 and A3.** They are two solve-directions of one affine
relation — A2 for the price, A3 for the cure fraction — and each holds its own
aim, output file and acceptance criterion, because a decision-maker arrives
with a different quantity in hand. A7 is a third solve-direction: price per
durable cure, conditional on a contract structure. The budget-side arrangements
are written into A7's own output file rather than added as columns to
`budget_impact.csv`, whose schema is pinned by an existing test and whose
published readout section would otherwise change meaning.

**What A7 does not resolve.** No real-world payment arrangement for a one-time
therapy is sourced (register item S-9). Two distinctions are recorded as the
specific things that must be verified: whether an arrangement was *announced*
or *executed*, which the secondary literature routinely blurs; and whether it
was a rebate against an invoice, a deferred milestone payment, or a true
annuity, which are three instruments with three different justified prices and
one shared name. US regulatory constraints on these arrangements are unassessed
(register item S-10); a study that models an arrangement US law obstructs is
modelling a counterfactual, and the readout says which it is. **Both are
blocking for the manuscript and neither is blocking for the code.** The
financing rate appropriate to an installment is unsourced (O16); the base case
is present-value-neutral at the study's own 3%, which is an analytic discount
rate and not a cost of capital, and any other rate is reported as a labelled
illustration whose size is a transfer between the two parties. **Whether a
two-year drug-free-remission outcome is adjudicable from routine claims data is
not assessed anywhere in this study**, and is recorded as a limitation rather
than absorbed.

**Effect on reported results: none.** No figure in A1–A6 changes. Nothing in
`R/` outside `R/payment_arrangements.R` and `R/units.R` is touched, no engine
work is authorised, and the Treg arm never learns that a contract exists —
putting the rebate inside the arm would make `B` contract-dependent and would
break T13, T14 and T17 at once. Existing outputs are regenerated so their spec
hashes match v1.2; **that regeneration requires re-running the 1,000-draw
probabilistic analysis first**, for the same reason the v1.1 amendment
recorded, and until it is done every committed output is red on G5's
stale-spec check. The specification commit and the regeneration commit are
separate, and the first is red by construction.

**G6's exemption for A7, recorded so it is not mistaken for coverage.** §6 now
names A7 with an output file that does not exist, and `uncovered_aims()` clears
it because this entry contains the string "A7". That is the sanctioned
amendment branch, not a defect — but the exemption never expires, so **G6 will
never again assert that `payment_arrangements.csv` exists.** The gate for the
session that builds A7 is T19, T20 and T21 passing and
`payment_arrangements_reconciliation.csv` existing, not a green G6. This is the
identical trap A6's own amendment recorded, and it is recorded again because it
is now structural rather than incidental.
