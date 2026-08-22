# Budget impact (A6): what a payer writes in cheques, and when. SPEC.md
# section 2a and L10-L16 govern this file alone; no figure in A1-A5 depends on
# anything here.
#
# Design notes, one per way this particular accounting goes wrong:
#
# Trap 1 (uptake is a flow, not a stock). The course price is charged ONCE, in
# the year a patient adopts (L7). It is applied here by handing the price to
# the same cohort stacker the ongoing costs use, as a per-patient stream of
# length one: a stream that pays out in the patient's own first year and never
# again. Charging it annually to everyone ever treated inflates the result by
# roughly the horizon length.
#
# Trap 2 (the mirror of trap 1). Earlier adopters keep generating cost in later
# years, so the payer's bill in year m is a stack of overlapping cohorts, not
# one cohort scaled by the cumulative uptake share. `stacked_cohort_
# expenditure_usd_per_year()` is that stack, and it is the only place in this
# file where a calendar year and a patient-year are mapped onto each other.
#
# Trap 3 (the comparator world holds the same patients). The same u*N patients
# start a standard-care course in the same calendar year in the current-care
# world, so the payer's counterfactual bill is that world's stack and not zero.
# Netting against zero is the classic budget-impact double count.
#
# Trap 4 (the uptake denominator). `terminal_uptake_share` is a share of the
# ELIGIBLE POOL -- not of prevalent Crohn's patients, and not of all treated
# patients. It is declared with `with_denominator()` in
# `uptake_cumulative_share()` (guard 3). This project's recorded failure mode
# is a share of a subset reported as though it were a share of the whole, and
# it has happened twice.
#
# THE HORIZON NEVER REACHES THE MODEL. Every function here consumes a cost
# stream computed once at the lifetime horizon and keeps a prefix of it (L10).
# The prefix boundary is CALENDAR-EXACT from t = 0: `truncated_cost_usd_per_
# year()` buckets cycles into calendar years with `cost_stream_usd_per_cycle_
# to_usd_per_year()` and keeps the first H of them, which is cycles 1 through
# H * ALIYEV_CYCLES_PER_YEAR. That is NOT the `induction_cycles + round(H *
# ALIYEV_CYCLES_PER_YEAR)` index T18 checks: that index reproduces the
# `horizon_years` ARGUMENT's own semantics, which counts maintenance cycles
# only and therefore runs `induction_cycles` behind the calendar (SPEC.md
# section 2a, horizon semantics; T18 states the distinction in terms). The two
# indices differ by 2 to 4 cycles. A reporting horizon is a calendar boundary a
# payer names, so the calendar index is the one a budget uses.
#
# LIFETIME LUMPS ARE NEVER READ HERE. `standard_care_at_age()` returns a whole
# discounted future in one number and cannot be truncated; every stream this
# file consumes comes from the W7 per-cycle machinery instead.
#
# THE MANUFACTURING BENCHMARK IS NOT READ HERE. `price_usd_per_course` is a
# required argument with no default, supplied by `analysis/run_bia.R`. L8
# forbids a pricing function reading the benchmark; this file prices nothing,
# and tests/testthat/test-budget-impact.R asserts the module cannot reach the
# benchmark's exports at all.

BIA_UPTAKE_RAMP_PERIOD_YEARS <- 5 # L12; an analyst's assumption under O12, held fixed across every reported horizon
BIA_PMPM_PLAN_MEMBERS <- 1e6 # the stated hypothetical plan size behind every PMPM figure (SPEC.md section 2a)
BIA_MONTHS_PER_YEAR <- 12

#' Cumulative share of the eligible pool treated by the end of each ramp year:
#' a linear ramp over `ramp_period_years` to `terminal_uptake_share` (L12).
#'
#' SINGLE ADOPTION WAVE (L15). The returned vector has exactly
#' `ramp_period_years` entries and nothing after them, which is the whole of
#' the decision: cumulative treatment caps at the terminal share when the ramp
#' ends and nobody is treated later. The alternative reading -- the terminal
#' annual rate persisting for the full horizon -- would treat several times the
#' eligible pool over 30 years, which is incoherent with a pool held fixed
#' (L16) unless incidence replenishes it, and incidence is unsourced (O15).
#' L15 records that T16 does not discriminate between the two readings, so this
#' function's length is the only place the decision is visible. Read it here.
#'
#' The denominator is declared, not implied: the share is of the ELIGIBLE POOL
#' (guard 3).
uptake_cumulative_share <- function(terminal_uptake_share,
                                     ramp_period_years = BIA_UPTAKE_RAMP_PERIOD_YEARS) {
  stopifnot(terminal_uptake_share >= 0, terminal_uptake_share <= 1,
    ramp_period_years >= 1, ramp_period_years == round(ramp_period_years))
  with_denominator(seq_len(ramp_period_years) * (terminal_uptake_share / ramp_period_years),
    "eligible_population_patients")
}

#' Patients newly treated in each adoption year -- the first difference of the
#' cumulative share, times the eligible pool.
#'
#' `eligible_population_patients` is O11 and carries no default (guard 7): the
#' function refuses to run rather than assume a pool size.
uptake_newly_treated_patients <- function(eligible_population_patients, terminal_uptake_share,
                                           ramp_period_years = BIA_UPTAKE_RAMP_PERIOD_YEARS) {
  stopifnot(eligible_population_patients >= 0)
  cumulative <- uptake_cumulative_share(terminal_uptake_share, ramp_period_years)
  stopifnot(identical(denominator_of(cumulative), "eligible_population_patients"))
  eligible_population_patients * diff(c(0, as.numeric(cumulative)))
}

#' A per-cycle cost stream resolved into calendar years and truncated at the
#' reporting horizon, from t = 0.
#'
#' `reporting_horizon_years = Inf` keeps the whole stream, which is what the
#' lifetime reconciliation leg needs: the Treg arm's stream runs past the
#' cohort's own lifetime horizon, because a patient handed to standard care
#' near the end carries a course whose cycles continue past it, and T13's
#' identity holds only against the untruncated total.
#'
#' A finite horizon longer than the stream is padded with zeros rather than
#' returned short, so two worlds of different stream lengths still net year
#' against year.
truncated_cost_usd_per_year <- function(cost_stream_usd, reporting_horizon_years) {
  annual <- cost_stream_usd_per_cycle_to_usd_per_year(cost_stream_usd)
  if (!is.finite(reporting_horizon_years)) return(annual)
  n <- as.integer(round(reporting_horizon_years))
  c(annual, numeric(max(n - length(annual), 0L)))[seq_len(n)]
}

#' The payer's bill in each calendar year from a stack of overlapping adoption
#' cohorts (trap 2).
#'
#' Cohort `k` adopts at the start of calendar year `k`, so its own patient-year
#' `j` falls in calendar year `k + j - 1`, and its whole stream is brought to
#' the analysis's own t = 0 by the discount factor at `k - 1` years. That
#' factor is read from the rate in force rather than threaded through as an
#' argument, so the undiscounted leg is produced by running the whole
#' computation under `options(treg_value.discount_rate = 0)` -- the `disc-0`
#' idiom `analysis/run_scenarios.R` already uses -- and gets a factor of 1 for
#' every cohort without a second code path.
stacked_cohort_expenditure_usd_per_year <- function(per_patient_cost_usd_per_year,
                                                     newly_treated_patients,
                                                     reporting_horizon_years) {
  n_years <- if (is.finite(reporting_horizon_years)) {
    as.integer(round(reporting_horizon_years))
  } else {
    length(newly_treated_patients) - 1L + length(per_patient_cost_usd_per_year)
  }
  out <- numeric(max(n_years, 0L))
  for (k in seq_along(newly_treated_patients)) {
    if (k > n_years) break
    treated <- newly_treated_patients[k]
    if (treated == 0) next
    span <- min(n_years - k + 1L, length(per_patient_cost_usd_per_year))
    if (span <= 0) next
    at <- k - 1L + seq_len(span)
    out[at] <- out[at] + treated * discount_factor_years_to_discount_factor(k - 1) *
      per_patient_cost_usd_per_year[seq_len(span)]
  }
  out
}

#' The Treg world's annual expenditure: the course price, charged once in each
#' cohort's own adoption year, plus that cohort's ongoing medical cost.
#'
#' The price is stacked as a per-patient stream of length one (trap 1). Writing
#' it that way rather than as a separate special case is deliberate: a price
#' charged in year one and never again IS a one-element cost stream, and the
#' cohort stacker then places it in the right calendar year and discounts it to
#' t = 0 by the same rule it applies to everything else.
treg_world_expenditure_usd_per_year <- function(price_usd_per_course,
                                                 per_patient_cost_usd_per_year,
                                                 newly_treated_patients,
                                                 reporting_horizon_years) {
  ongoing <- stacked_cohort_expenditure_usd_per_year(per_patient_cost_usd_per_year,
    newly_treated_patients, reporting_horizon_years)
  course <- stacked_cohort_expenditure_usd_per_year(price_usd_per_course,
    newly_treated_patients, length(ongoing))
  ongoing + course
}

#' The current-care world's annual expenditure: the same patients, adopting a
#' standard-care course in the same calendar year, with no course price (trap
#' 3). This is the counterfactual the Treg world is netted against.
current_care_expenditure_usd_per_year <- function(per_patient_cost_usd_per_year,
                                                   newly_treated_patients,
                                                   reporting_horizon_years) {
  stacked_cohort_expenditure_usd_per_year(per_patient_cost_usd_per_year,
    newly_treated_patients, reporting_horizon_years)
}

#' Net budget impact by year. Positive when the Treg world costs the payer more
#' (SPEC.md section 2a, sign convention).
#'
#' The two worlds' streams have different lengths -- the Treg arm's runs past
#' the comparator's, because a relapser's own course continues past the cohort
#' horizon -- so the shorter is zero-extended rather than recycled.
net_budget_impact_usd_per_year <- function(treg_world_usd_per_year, current_care_usd_per_year) {
  n <- max(length(treg_world_usd_per_year), length(current_care_usd_per_year))
  extend <- function(v) c(v, numeric(n - length(v)))
  extend(treg_world_usd_per_year) - extend(current_care_usd_per_year)
}

#' `D(H)`: cumulative current-care-world-minus-Treg-world cost per treated
#' patient, excluding the course price, through each year (SPEC.md section 2a).
#'
#' This is a COST quantity. Willingness to pay does not enter it, because a
#' budget holds no QALYs -- the same logic T13 rests on. It is also independent
#' of the eligible population and of the uptake level, which is why the
#' progression built from it is the one A6 finding that survives O11 never
#' being sourced.
cost_offset_per_patient_usd <- function(current_care_usd_per_year, treg_usd_per_year) {
  n <- max(length(current_care_usd_per_year), length(treg_usd_per_year))
  extend <- function(v) c(v, numeric(n - length(v)))
  cumsum(extend(current_care_usd_per_year) - extend(treg_usd_per_year))
}

#' `offset_captured(H) = D(H) / D(lifetime)`, the share of the lifetime cost
#' offset that lands inside a window of length H.
#'
#' Neither monotone in H nor bounded above by 1. A dip between two horizons
#' means the intervening years contributed negative offset -- the Treg world
#' outspending the current-care world during that stretch, which is the
#' cap-clock or relapse window and is a finding rather than an artefact. The
#' division is guarded the way `analysis/run_aims.R` guards EVPI: near a cure
#' fraction of zero the denominator is `A(lambda = 0)`, which is small and may
#' be of either sign, and a ratio against a negative denominator would be
#' reported as a confident number rather than as the absence of one.
#'
#' Written to preserve the length of `cumulative_offset_usd` rather than as an
#' `ifelse()` over a scalar denominator: `ifelse()` returns a value shaped like
#' its TEST, so a scalar test silently collapses a whole progression to its
#' first year and then recycles that one number across every row of the output
#' table. That is a wrong answer that looks like a right one -- a flat
#' progression reads as a real finding -- and it is what
#' tests/testthat/test-budget-impact.R's length assertion exists to catch.
offset_captured_share <- function(cumulative_offset_usd, lifetime_offset_usd) {
  share <- cumulative_offset_usd / lifetime_offset_usd
  share[rep_len(!(lifetime_offset_usd > 0), length(share))] <- NA_real_
  share
}

#' Annual dollars expressed per member per month on a stated plan size. The
#' plan members are a different population from the eligible patients, and the
#' two carry different unit suffixes for exactly that reason.
usd_per_year_to_usd_pmpm <- function(budget_usd_per_year, plan_members = BIA_PMPM_PLAN_MEMBERS) {
  stopifnot(plan_members > 0)
  budget_usd_per_year / (plan_members * BIA_MONTHS_PER_YEAR)
}
