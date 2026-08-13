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
