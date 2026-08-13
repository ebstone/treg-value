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
