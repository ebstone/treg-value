# Adversarial review prompt — treg-value

Paste the block below into a fresh Claude Code session at the repository
root, then run `/code-review ultra`.

Note on scope: all work is committed to `main` (22 commits, no feature
branch), so there is no diff to review. This is a **whole-codebase** review
of `R/`, `derive/`, `analysis/` and `tests/testthat/` — about 3,800 lines.

---

You are reviewing a health-economic model adversarially. Assume it contains
at least one defect that changes a reported number, and that previous
reviewers missed it. Your job is to find it, not to confirm the model works.

## What the code computes

An early health technology assessment of a hypothetical allogeneic Treg cell
therapy for moderate-to-severe Crohn's disease. No efficacy data exist for
the product, so the model does not assume a cure fraction and price the
consequence. It inverts the question and solves for the maximum justifiable
price at each possible cure fraction:

    P*(pi, h, lambda) = A(lambda) + pi * B(h, lambda)

where `pi` is the cure fraction as a share of ALL TREATED PATIENTS, `h` is an
ongoing annual post-cure relapse hazard, `lambda` is willingness to pay, `A`
is the value when the therapy cures nobody, and `B` is the value of one
durable cure. The comparator is infliximab. A 6-state Markov model on
2-week cycles runs to age 100 from a starting age of 35.

## Read these first, in this order

- `SPEC.md` — the governing authority. It supersedes every comment, memo and
  README paragraph in the repository, including `CLAUDE.md`. Sections 1, 4
  (locked decisions L1-L9), 5 (scenario grid) and 10 (acceptance criteria
  T1-T12) matter most.
- `CLAUDE.md` — working rules, including the eight guards.
- `SPEC_AMENDMENTS.md` — every departure from SPEC.md, with reasoning. Long,
  and worth reading in full: a deviation recorded here is sanctioned, and a
  deviation NOT recorded here is a finding.
- `OPEN_QUESTIONS.md` — parameters that must be required arguments with no
  defaults, plus the closed-decision log C1-C10.

## Two defect classes this project has already suffered

Both were reported as correct before being caught. Check for recurrences in
any form, including new ones:

1. **The denominator.** `pi_cure` must be a share of everyone treated. It has
   twice been implemented as a share of a subset — patients in remission on
   the biologic track — and reported as though it were unconditional. That
   flattened the price curve roughly fivefold. Verify against the trace, not
   against the parameter's declared attribute: an attribute records intent,
   a trace records what happened.

2. **The intercept.** `P*(0)` must equal `A` and nothing else. A previous
   build carried several thousand dollars of unexplained savings there,
   which meant the arm was credited with the comparator's benefit without
   being charged its cost. `A` is expected to be NEGATIVE here; that is the
   documented, correct behaviour under L9, not a bug to fix.

## Verify the acceptance criteria independently

`SPEC.md` section 10 states T1-T12. Tests claiming to enforce them live in
`tests/testthat/`. Do not take a passing test as evidence the property
holds — read what each test actually asserts and decide whether it could
pass while the property is violated. T3 (linearity of the frontier) is
especially easy to make vacuous by construction.

## Specific areas to scrutinise

These are unusual or high-consequence design decisions. Form your own view;
do not assume any of them is already correct.

1. `R/treg_arm.R` and `standard_care_grid()` — non-cured and relapsed
   patients are accounted analytically through a precomputed age grid rather
   than tracked cycle by cycle in the state vector. Determine whether this
   is exact, what it assumes, and whether the cohort-level bookkeeping
   (`state_sums`) genuinely demonstrates conservation given that some mass
   is accounted outside the tracked vector.

2. `R/frontier.R` — `frontier_intercept_from_model()` and
   `frontier_intercept_independent()` are claimed to be code-disjoint routes
   to `A`, which is what makes T1 meaningful. Establish whether they are
   genuinely independent or share enough structure that agreement is
   near-automatic.

3. `R/psa.R` — utilities are sampled by drawing one value and rescaling all
   states by a single factor to preserve ordering. Consider what that does
   to the correlation structure and whether the reported credible intervals
   are consequently too narrow. Also check the Dirichlet concentration and
   the Moderate-Severe cost draw, which is rescaled rather than drawn
   directly.

4. The currency chain — `derive/health_state_costs.R` converts 2008 to 2017
   by a source-specified rule, `R/price_index.R` re-bases to 2025 by CPI, and
   `R/manufacturing_benchmark.R` converts 2018 EUR to USD then re-bases.
   Check for double-counting, wrong-direction adjustment, or a figure
   re-based twice.

5. `R/refractory.R` — multipliers derived from ustekinumab trials are
   applied to an infliximab comparator, at induction only. Check the
   arithmetic of `apply_refractory_to_induction()`, particularly that
   response and remission multipliers interact correctly and that no row can
   go negative.

6. `R/markov_engine.R` — the 2-year maintenance cap, the half-cycle
   correction, and the redirect of Moderate-Severe mass from the biologic
   cohort to conventional therapy. Confirm the cap charges the correct number
   of dose cycles and that the redirect cannot lose or duplicate mass.

## What is deliberate, and not a finding

- The eight guards in `tests/testthat/` (provenance, units, denominators,
  no-snapshots, stamping, aim coverage, no-defaults, no-status-prose) are the
  project's chosen engineering discipline. Report a guard that fails to catch
  what it claims to; do not report the existence of the framework.
- Anything recorded in `SPEC_AMENDMENTS.md` has been signed off. You may
  challenge the reasoning, but say so explicitly rather than reporting it as
  an undocumented assumption.
- Scenarios S3 and S6 are deliberately unbuilt, with reasons recorded.
- The absence of a distributional analysis and of patient involvement is a
  declared limitation, not an oversight.

## What counts as a finding

A concrete failure: inputs or state that produce a wrong number, with the
mechanism named and the affected output identified. Rank by whether the
error changes a reported figure. Style preferences, naming, and
refactoring suggestions are out of scope unless they hide a defect.

If you conclude a number is wrong, say which number, by how much, and why.
