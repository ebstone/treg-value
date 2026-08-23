# Alternative payment arrangements (A7): what a payer pays when the course
# price is re-timed or conditioned on the outcome, and the price that re-timing
# justifies. SPEC.md section 2a governs A7's budget leg, section 2 governs its
# per-cure frontier, and L17-L21 govern this file alone. No figure in A1-A6
# depends on anything here.
#
# THIS MODULE IS A PAYER-SIDE OVERLAY. It is computed downstream of cost
# streams the Treg arm produced without knowing a contract exists, and it never
# reaches back. Putting a rebate inside `run_treg_trace()` would make `B`
# contract-dependent and break T13, T14 and T17 at once, so no function here is
# referenced from R/treg_arm.R, R/frontier.R or R/markov_engine.R, and
# tests/testthat/test-payment-arrangements.R asserts that in both directions.
#
# Design notes, one per way this particular accounting goes wrong.
#
# Trap 1 (TWO RATES, and only one of them is the study's). A contract's
# financing rate is a term the two parties negotiate (O16). The analysis's
# discount rate is the rate in force, which
# `discount_factor_years_to_discount_factor()` reads from an option so a
# sensitivity can vary it for a whole run. They are different numbers with
# different owners, and the annuity factor is built from the CONTRACT's:
#
#   nominal payment  = price / a_c,  a_c = sum_j (1 + r_contract)^-(j-1)
#   stream element j = nominal payment * (1 + r_analysis)^-(j-1)
#
# `stacked_cohort_expenditure_usd_per_year()` applies only the cohort's own
# adoption-year factor `v^(k-1)` and does NOT discount within a per-patient
# stream, which is why the analysis-rate factor is applied here rather than
# left to the stacker. If `a_c` were built from the rate in force instead, then
# under `with_zero_discounting()` it would collapse to `N`, the undiscounted
# leg would silently report an interest-free contract and the discounted leg an
# interest-bearing one -- two different contracts under one row. That is why
# `installment_financing_rate_per_year` is an open item with no default, and it
# is what T19(b) and T19(d) both fail against.
#
# Trap 2 (A REBATE HAS A DATE, and carries that date's discount factor). A
# rebate triggered at observation point `T` measured from the landmark settles
# at patient-time `T + LANDMARK_CYCLES * CYCLE_YEARS` from adoption (L21). It
# is placed as a NEGATIVE element of the per-patient price stream at index
# `floor(tau) + 1`, scaled by `v^tau` -- both halves, not either. Placing it at
# index 1 makes the contract look costless at every horizon; omitting the
# factor makes it look 0.7% to 14% cheaper than it is, depending on `T`. The
# placement is also a finding rather than an inconvenience: cohort `k`'s rebate
# lands in calendar year `k + floor(tau)`, so a one-year budget impact of a
# two-year-observation contract shows the whole price and none of the rebate.
#
# Trap 3 (THE TWO SCHEDULE CONSTRUCTORS ARE BUILT BY OPPOSITE RULES and must
# not share a helper). `installment_price_stream_usd_per_year()` carries an
# explicit analysis-rate factor, because its payments are nominal amounts
# falling in future years. `offset_matched_price_stream_usd_per_year()` carries
# none, because the offset increments it is proportional to arrive already
# discounted -- they are differences of `cost_offset_per_patient_usd()`, which
# cumulates streams that were discounted to the patient's own start when they
# were built. The two look alike on the page. Applying a second discount factor
# to the offset-matched schedule breaks T20 at every horizon and reads like a
# rounding problem.
#
# Trap 4 (TWO DENOMINATORS UNDER ONE UNIT). At a full rebate the payer's
# nominal outlay is one price per success, so the figure is denominated per
# cure -- but "one success" is one patient in drug-free remission at the
# landmark when `T = 0` and one patient still in drug-free remission at `T`
# when `T > 0`, a strictly smaller population of size `pi * exp(-h*T)` of all
# treated. Those are two populations under one suffix, which is the exact shape
# of the failure CLAUDE.md records has happened twice. `with_denominator()`
# declares which one, the declaration tracks `T`, and the test file asserts
# both branches. At a partial rebate there is no per-cure figure at all: the
# invoice is neither per course nor per cure, so it keeps `_usd_per_course`.
#
# Trap 5 (THE OFFSET-MATCHED SCHEDULE'S TAIL CAN BE CLIPPED, on the lifetime
# leg). `arrangement_expenditure_usd_per_year()` stacks the price leg against
# the calendar the COST stream defines, exactly as
# `treg_world_expenditure_usd_per_year()` does, so an A7 budget cell and the A6
# cell under it cannot drift. On the lifetime leg that calendar runs
# `length(newly_treated) - 1 + length(cost_stream)` years, so a price stream of
# length `L` survives unclipped for the last cohort only while
# `L <= length(cost_stream)`. For a 3- or 5-year installment that is enormous
# slack; for the offset-matched schedule `L` EQUALS the cost stream's length
# and nothing survives a one-element mistake, so it is asserted rather than
# left to luck. At a finite horizon the opposite holds and is the mechanism
# T20 depends on: cohort `k` contributes `max(0, min(H - k + 1, L))` elements,
# truncated at the same index its offset is, which is why the identity closes
# at every horizon at once.

#' The contract's annuity factor `a_c`: the present value, at the CONTRACT's
#' own financing rate, of one dollar paid at the start of each of
#' `installment_length_years` years. Equal nominal annual payments of
#' `price / a_c` are present-value-neutral at that rate and at no other.
#'
#' `installment_financing_rate_per_year` is O16 and carries no default (guard
#' 7): the function refuses to run rather than assume a rate, and `rate =` is
#' passed explicitly so the option-borne analysis rate cannot leak in (trap 1).
installment_annuity_factor_discount_factor <- function(installment_length_years,
                                                        installment_financing_rate_per_year) {
  stopifnot(installment_length_years >= 1,
    installment_length_years == round(installment_length_years),
    installment_financing_rate_per_year >= 0)
  sum(discount_factor_years_to_discount_factor(seq_len(installment_length_years) - 1,
    rate = installment_financing_rate_per_year))
}

#' The per-patient price stream of an installment arrangement: equal nominal
#' annual payments over `installment_length_years`, first payment in the
#' adoption year, each brought to the patient's own start at the ANALYSIS rate
#' in force (trap 1).
#'
#' Handed to `stacked_cohort_expenditure_usd_per_year()`, this places payment
#' `j` of cohort `k` in calendar year `k + j - 1`, so the schedule seen inside
#' a window of length `H` is truncated at `H - k + 1` payments and differs
#' cohort by cohort. That per-cohort clock is the whole content of T19(b).
installment_price_stream_usd_per_year <- function(price_usd_per_course,
                                                   installment_length_years,
                                                   installment_financing_rate_per_year) {
  annuity <- installment_annuity_factor_discount_factor(installment_length_years,
    installment_financing_rate_per_year)
  nominal <- price_usd_per_course / annuity
  nominal * discount_factor_years_to_discount_factor(seq_len(installment_length_years) - 1)
}

#' The settlement date of a conditional payment, in years from adoption: the
#' observation point measured from the landmark, plus the landmark's own offset
#' from adoption (L21). Read from the model's own calendar rather than written
#' as a constant, so it moves if L1 ever does.
rebate_settlement_years <- function(outcome_observation_years) {
  stopifnot(outcome_observation_years >= 0)
  outcome_observation_years + LANDMARK_CYCLES * CYCLE_YEARS
}

#' The factor by which an outcomes-based contract's invoice is multiplied to
#' give the present value the payer actually parts with, per treated patient:
#'
#'     1 - rho * (1 - pi * exp(-h*T)) * v^tau
#'
#' The trigger is SPEC.md section 7's own derived quantity evaluated at `T`,
#' never `pi` itself (L19): at the landmark the two coincide exactly (T4), and
#' a contract triggered there rebates on a 12-week response rather than on a
#' durable cure. The factor lies in `[1 - rho*v^tau, 1]` and is strictly
#' positive, which is what makes the justified price below finite at every cure
#' fraction including zero.
rebate_price_discount_factor <- function(pi_cure, h_per_year, rebate_share,
                                          outcome_observation_years) {
  stopifnot(rebate_share >= 0, rebate_share <= 1)
  tau <- rebate_settlement_years(outcome_observation_years)
  failure <- 1 - still_in_drug_free_remission(pi_cure, h_per_year, outcome_observation_years)
  1 - rebate_share * failure * discount_factor_years_to_discount_factor(tau)
}

#' The per-patient price stream of an outcomes-based contract in form R: the
#' invoice paid in full at adoption, and a rebate of `rebate_share` of it
#' returned for each patient not in sustained drug-free remission at the
#' observation point.
#'
#' Form R is the base case (L19). Form M -- pay nothing at adoption and pay
#' per success at `tau`, present value `q * s(T) * v^tau` -- is a different
#' contract with a different justified price and is deliberately not built.
#'
#' The rebate is a negative element at index `floor(tau) + 1` carrying `v^tau`
#' (trap 2). At `T = 0` that index is 1, so the invoice and the rebate share a
#' calendar year and the element is their sum -- which is a placement, not the
#' coincident-settlement approximation L21 forbids: the factor `v^tau` is
#' applied either way.
outcomes_based_price_stream_usd_per_year <- function(price_usd_per_course, pi_cure, h_per_year,
                                                      rebate_share, outcome_observation_years) {
  tau <- rebate_settlement_years(outcome_observation_years)
  at <- floor(tau) + 1L
  stream <- numeric(at)
  stream[1] <- price_usd_per_course
  rebate <- price_usd_per_course *
    (1 - rebate_price_discount_factor(pi_cure, h_per_year, rebate_share, outcome_observation_years))
  stream[at] <- stream[at] - rebate
  stream
}

#' The year-by-year increments of a cumulative cost-offset progression:
#' `D(m) - D(m-1)`, with `D(0) = 0`.
#'
#' These arrive ALREADY DISCOUNTED to the patient's own start, because
#' `cost_offset_per_patient_usd()` cumulates streams that were discounted when
#' they were built. That is what makes the offset-matched schedule's
#' construction the opposite of the installment's (trap 3).
offset_increment_usd_per_year <- function(cumulative_offset_usd) {
  diff(c(0, cumulative_offset_usd))
}

#' The offset-matched reference schedule: the per-patient price stream paying,
#' in the patient's own year `m`, the share of the price that year contributes
#' to the lifetime cost offset.
#'
#' Supplied to the stacker WITHOUT a further discount factor (trap 3). The
#' domain restriction is not inherited by accident: `D(lifetime)` is
#' `P*(pi, h, lambda = 0)`, which is `A(lambda = 0)` at a cure fraction of zero
#' and may be of either sign, and `offset_captured_share()` NA-guards the same
#' quantity for the same reason.
#'
#' This is a REFERENCE schedule and not a contract proposal. It depends on the
#' cure fraction and the relapse hazard, which nobody knows at contract time,
#' and it presumes both parties accept this model. It answers what timing
#' budget-neutrality would require, not what anyone could sign.
offset_matched_price_stream_usd_per_year <- function(price_usd_per_course,
                                                      annual_offset_increment_usd_per_year,
                                                      lifetime_offset_usd) {
  stopifnot(lifetime_offset_usd > 0)
  price_usd_per_course * annual_offset_increment_usd_per_year / lifetime_offset_usd
}

#' The Treg world's annual expenditure under an arbitrary payment arrangement:
#' the cohort's ongoing medical cost, plus a price stream of any length placed
#' on each cohort's own clock.
#'
#' This composes `stacked_cohort_expenditure_usd_per_year()` for both legs
#' rather than routing the price leg through
#' `treg_world_expenditure_usd_per_year()`, so the calendar the price leg is
#' stacked against is explicit and the clipping margin can be asserted (trap
#' 5). At `reporting_horizon_years = 1` and a one-element price stream it
#' reproduces `treg_world_expenditure_usd_per_year()` exactly, which is what
#' makes the lump-sum arrangement A6's own arithmetic rather than a second
#' implementation of it.
arrangement_expenditure_usd_per_year <- function(price_stream_usd_per_year,
                                                  per_patient_cost_usd_per_year,
                                                  newly_treated_patients,
                                                  reporting_horizon_years) {
  ongoing <- stacked_cohort_expenditure_usd_per_year(per_patient_cost_usd_per_year,
    newly_treated_patients, reporting_horizon_years)
  if (!is.finite(reporting_horizon_years)) {
    stopifnot(length(newly_treated_patients) - 1L +
      length(price_stream_usd_per_year) <= length(ongoing))
  }
  ongoing + stacked_cohort_expenditure_usd_per_year(price_stream_usd_per_year,
    newly_treated_patients, length(ongoing))
}

#' The justified invoice per treated patient under an outcomes-based contract:
#' the price whose present value at t = 0, rebate included and each leg at its
#' own date, is exactly `P*(pi, h, lambda)` (L20).
#'
#'     q = (A + pi*B) / (1 - rho*(1 - pi*exp(-h*T))*v^tau)
#'
#' Deliberately written as a transform of `price_star_usd_per_course` rather
#' than as `(A + pi*B)/(...)`: the affine structure is T3's property of the
#' model, not an identity this function should impose, and taking `P*` as the
#' numerator is what keeps an A7 cell and the frontier cell under it from
#' drifting.
#'
#' It carries `_usd_per_course` at EVERY rebate share, including 1. A partial
#' rebate's invoice is neither per course nor per cure, and at a full rebate
#' the same number acquires a per-cure reading only once its denominator has
#' been declared -- which is what `justified_price_usd_per_cure()` below is
#' for.
justified_arrangement_price_usd_per_course <- function(price_star_usd_per_course, pi_cure,
                                                        h_per_year, rebate_share,
                                                        outcome_observation_years) {
  price_star_usd_per_course /
    rebate_price_discount_factor(pi_cure, h_per_year, rebate_share, outcome_observation_years)
}

#' The same quantity at a FULL rebate, where the payer's nominal outlay is one
#' invoice per success and the figure is therefore denominated per cure (L21).
#'
#' There is no `rebate_share` argument, because the per-cure unit applies at a
#' full rebate and nowhere else; asking for it at a partial rebate is a
#' question with no answer in this unit.
#'
#' NOT routed through `usd_per_course_to_usd_per_cure()`, and the distinction
#' matters. That converter restates a price the payer pays for every treated
#' patient as what it costs per cure, and divides by the success share. Here
#' the payer already pays once per success by construction, so the same
#' division would charge for the conditioning twice.
justified_price_usd_per_cure <- function(price_star_usd_per_course, pi_cure, h_per_year,
                                          outcome_observation_years) {
  q <- justified_arrangement_price_usd_per_course(price_star_usd_per_course, pi_cure,
    h_per_year, 1, outcome_observation_years)
  with_denominator(q, per_cure_denominator(outcome_observation_years))
}

#' The share of the price paid by the end of horizon `H` under an arrangement,
#' and how much of the gap between paying and being repaid it closes.
#'
#' Defined on the SINGLE-COHORT fixture, under one stated discounting
#' convention. Over a staggered stack "the share of the price paid by H" needs
#' a horizon-dependent denominator -- the patients treated by `H` -- so the
#' figure at one horizon and at another would be shares of different
#' populations, which is the L2 and guard-3 hazard in a new costume (L17).
#'
#' Under a lump sum `paid_share` is 1 and the gap closed is 0; under the
#' offset-matched schedule `paid_share` equals `offset_captured(H)` and the gap
#' closed is 1 by construction. Every real arrangement sits between.
timing_gap_closed_share <- function(paid_share, offset_captured) {
  (1 - paid_share) / (1 - offset_captured)
}
