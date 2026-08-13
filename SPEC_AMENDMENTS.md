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
