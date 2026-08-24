# A7 -- alternative payment arrangements. SPEC.md section 2a (A7's budget leg),
# section 2 (its per-cure frontier), L17-L21, S10 and S11.
#
# Run from the repository root, AFTER analysis/run_bia.R: the price axis is
# this study's own frontier, read from output/tables/price_frontier.csv rather
# than recomputed, exactly as run_bia.R reads it, so an A7 cell and the A6 cell
# and frontier cell under it cannot drift apart. The reconciliation file also
# reads output/tables/budget_impact.csv to check A7's lump-sum arrangement
# against A6's own published figure on both discounting columns, which is the
# strongest available statement that this aim moved nothing -- and, read the
# other way, a standing check that A6's two columns are still produced under the
# conventions they claim.
#
# A7 IS NOT A SECOND BUDGET IMPACT ANALYSIS. Its budget leg is A6's budget
# impact analysis under different payment terms and inherits every one of A6's
# limitations -- the unsourced population (O11), the unsourced uptake (O12), the
# single adoption wave (L15), the fixed pool (L16), the ASP-versus-net-price gap
# (O14). A7 resolves none of them.
#
# WHAT DOES NOT MOVE, AND IT IS MOST OF THIS. `offset_captured(H)` is printed on
# every budget row and is identical across arrangements by construction: section
# 2a defines D(H) as excluding the course price, and a payment arrangement
# changes only the price leg. A reader arriving at this file expecting the
# offset-capture progression to improve under an installment has misread what it
# measures, and the column is carried here so that misreading fails visibly.
#
# TWO ROW FAMILIES IN ONE FILE, and the `result_family` column says which.
# SPEC.md section 6 gives aim A7 one output file for two objects, because they
# answer one question from two directions. `per_cure_frontier` rows are frontier
# objects: no time axis, no population, no uptake path, no reporting horizon.
# `budget_arrangement` rows are A6's cohort stack under a re-timed or
# re-conditioned price leg. Columns belonging to one family are NA on the other.
#
# THE LADDERS LIVE HERE, NOT IN R/. `unsuffixed_numerics()` sweeps top-level
# numeric objects in R/, and a rebate-share ladder is a dimensionless share of a
# price with no natural unit suffix; routing it through `with_denominator()` to
# quiet the guard would trade guard-2 coverage for a guard-3 declaration as a
# side effect rather than as a choice. So the ladders sit beside the price axes
# and the population schedule, in the analysis layer, for the reason
# run_bia.R's own grid sits there.

source("R/io_cache.R")
source("R/price_index.R")
source("R/denominator.R")
source("R/units.R")
source("derive/health_state_costs.R")
source("R/transition_matrices.R")
source("R/life_table.R")
source("R/dosing.R")
source("R/costs_utilities.R")
source("R/refractory.R")
source("R/comparator_dosing.R")
source("R/markov_engine.R")
source("R/treg_arm.R")
source("R/frontier.R")
source("R/analog_comparison.R")
source("R/budget_impact.R")
source("R/payment_arrangements.R")
source("R/stamp.R")

INDUCTION_WINDOW_WEEKS <- 8
CAPS <- c(TRUE, FALSE)
HAZARDS_PER_YEAR <- c(0, 0.05, 0.10)
BUDGET_PI_GRID <- c(0.25, 0.50, 0.75, 1.00)
LAMBDAS_USD_PER_QALY <- c(5e4, 1e5, 1.5e5)
BUDGET_LAMBDA_USD_PER_QALY <- 1e5
LIFETIME_YEARS <- 100 - MODEL_START_AGE_YEARS

# --- Contract ladders (L17, L19) -----------------------------------------
# Normative terms a negotiator picks, stated with base cases and reported
# ladders rather than swept -- L10's epistemic/normative distinction, applied
# to a contract instead of to a reporting horizon. None of them is an open
# item; all of them are required arguments with no defaults.
INSTALLMENT_LENGTHS_YEARS <- c(5, 3) # base case first (L17)
# The present-value-neutral financing rate is the study's own analytic discount
# rate and is NOT a cost of capital (O16). It is read from the CONSTANT, not
# from `discount_rate_per_year()`: under `with_zero_discounting()` the rate in
# force is zero while the contract term is unchanged, and conflating the two is
# what makes one row describe two different contracts (R/payment_arrangements.R,
# trap 1).
PV_NEUTRAL_FINANCING_RATE_PER_YEAR <- DISCOUNT_RATE_PER_YEAR
INTEREST_FREE_FINANCING_RATE_PER_YEAR <- 0
FRONTIER_REBATE_SHARES <- c(0, 0.50, 1.00)
OUTCOME_OBSERVATION_LADDER_YEARS <- c(2, 0, 5) # base case first (L19)
BASE_CASE_OUTCOME_OBSERVATION_YEARS <- 2

UPTAKE_SCHEDULE <- list(
  list(u = 0.00, n = 1e5),
  list(u = 0.25, n = 1e3),
  list(u = 0.25, n = 1e4),
  list(u = 0.25, n = 1e5),
  list(u = 1.00, n = 1e5)
)

HORIZONS <- list(
  list(id = "1yr", years = 1, class = "bia"),
  list(id = "3yr", years = 3, class = "bia"),
  list(id = "5yr", years = 5, class = "bia"),
  list(id = "10yr", years = 10, class = "extended_projection"),
  list(id = "30yr", years = 30, class = "extended_projection")
)
BASE_CASE_HORIZON <- "3yr" # L10

discounting_base_case_for <- function(horizon_class, discounted) {
  (horizon_class == "bia" && !discounted) || (horizon_class != "bia" && discounted)
}

# Not a library function: `analysis/run_bia.R` defines its own copy for the same
# reason, and sourcing that script here would re-run the whole budget impact
# analysis as a side effect.
with_zero_discounting <- function(expr) {
  old <- getOption("treg_value.discount_rate")
  options(treg_value.discount_rate = 0)
  on.exit(options(treg_value.discount_rate = old), add = TRUE)
  force(expr)
}

# THE WHOLE CELL RUNS AT ONE RATE, STACKING AND PRICE STREAM ALIKE -- A6's
# CONVENTION, APPLIED WHERE A7 NEEDS IT TO REACH FURTHER.
#
# `stacked_cohort_expenditure_usd_per_year()` reads the cohort's own
# adoption-year factor `v^(k-1)` from the rate in force, and its docstring
# states in terms how the undiscounted leg is meant to be produced: "by running
# the whole computation under `options(treg_value.discount_rate = 0)` ... and
# gets a factor of 1 for every cohort without a second code path".
# `analysis/run_bia.R` produces A6's undiscounted leg exactly that way, through
# `treg_world_undiscounted_expenditure_usd_per_year()` and
# `current_care_undiscounted_expenditure_usd_per_year()`, which carry the
# convention in their names so a leg's streams and the rate its stack runs at
# cannot drift apart.
#
# A7 CANNOT USE THOSE TWO FUNCTIONS, and the reason is not a disagreement about
# the convention. The rate in force enters an A7 row twice -- once across
# cohorts, and once WITHIN one, in the per-patient price stream an installment's
# payments or a rebate's settlement date sit inside. A named stacker can only
# fix the first. `at_rate_in_force()` puts the entire cell inside one rate, the
# price stream's construction included, so a single row cannot describe two
# different contracts: that is the failure R/payment_arrangements.R's trap 1
# exists to prevent, and applying 3% within the stream while calling the column
# undiscounted would collapse T19(d)'s four cells onto the origin. Every row
# carries the rate that produced it in `analysis_discount_rate_per_year`.
#
# One convention, therefore, across both aims, and it is checked rather than
# assumed: the reconciliation file's `A6_lump_sum_agreement` leg checks A7's
# lump sum against A6's own published figure on BOTH columns, and on each of
# them the agreement is limited only by A6's rounding to the cent. Nothing in
# R/budget_impact.R or analysis/run_bia.R is touched here and no A6 figure
# moves.
at_rate_in_force <- function(discounted, expr) if (discounted) expr else with_zero_discounting(expr)

# --- The arrangements ----------------------------------------------------
# Each carries its own contract terms. The lump sum is the base case (L7) and
# every other row is a labelled alternative that never replaces it.
ARRANGEMENTS <- c(
  list(list(id = "lump_sum", kind = "lump")),
  unlist(lapply(INSTALLMENT_LENGTHS_YEARS, function(n) list(
    list(id = sprintf("installment_pv_neutral_%dyr", n), kind = "installment",
      n = n, rate = PV_NEUTRAL_FINANCING_RATE_PER_YEAR),
    list(id = sprintf("installment_interest_free_%dyr", n), kind = "installment",
      n = n, rate = INTEREST_FREE_FINANCING_RATE_PER_YEAR)
  )), recursive = FALSE),
  list(list(id = "offset_matched", kind = "offset_matched")),
  unlist(lapply(OUTCOME_OBSERVATION_LADDER_YEARS, function(t) list(
    list(id = sprintf("outcomes_based_rho100_T%dyr", t), kind = "outcomes",
      rho = 1.00, t = t)
  )), recursive = FALSE),
  list(list(id = "outcomes_based_rho050_T2yr", kind = "outcomes",
    rho = 0.50, t = BASE_CASE_OUTCOME_OBSERVATION_YEARS))
)

price_stream_for <- function(arr, price, pi_cure_value, h, offset_increment, lifetime_offset) {
  if (arr$kind == "lump") return(price)
  if (arr$kind == "installment") {
    return(installment_price_stream_usd_per_year(price, arr$n, arr$rate))
  }
  if (arr$kind == "outcomes") {
    return(outcomes_based_price_stream_usd_per_year(price, pi_cure_value, h, arr$rho, arr$t))
  }
  offset_matched_price_stream_usd_per_year(price, offset_increment, lifetime_offset)
}

na_or <- function(x) if (is.null(x)) NA_real_ else x

# --- Price axes ----------------------------------------------------------
frontier <- read.csv("output/tables/price_frontier.csv", comment.char = "#", stringsAsFactors = FALSE)
price_star_of <- function(cap_on, h, pi_cure_value, lambda) {
  row <- frontier$induction_window_weeks == INDUCTION_WINDOW_WEEKS &
    frontier$maintenance_cap == (if (cap_on) "on" else "off") &
    frontier$lambda_usd_per_qaly == lambda &
    frontier$h_per_year == h & abs(frontier$pi_cure - pi_cure_value) < 1e-9
  stopifnot(sum(row) == 1)
  frontier$price_star_usd_per_course[row]
}

analogs <- read.csv("data/raw/cell_therapy_revealed_prices_2025.csv", stringsAsFactors = FALSE)
ANALOG_LIST_PRICE_USD_PER_COURSE <- median(analogs$us_list_price_usd, na.rm = TRUE)

# ==========================================================================
# The per-cure frontier (SPEC.md section 2; L20, L21)
# ==========================================================================
frontier_rows <- list()
for (cap_on in CAPS) {
  cap_label <- if (cap_on) "on" else "off"
  for (lambda in LAMBDAS_USD_PER_QALY) {
    for (h in HAZARDS_PER_YEAR) {
      sub <- frontier[frontier$induction_window_weeks == INDUCTION_WINDOW_WEEKS &
        frontier$maintenance_cap == cap_label &
        frontier$lambda_usd_per_qaly == lambda &
        frontier$h_per_year == h, ]
      sub <- sub[order(sub$pi_cure), ]
      # The sign condition, read off the study's own affine relation rather
      # than asserted: P*_cure carries the sign of A + pi*B at every cure
      # fraction, because its denominator is strictly positive, so no positive
      # price per cure is justified below pi = -A/B. The threshold is the
      # frontier's own root and is inherited, not introduced.
      fit <- stats::lm(price_star_usd_per_course ~ pi_cure, data = sub)
      threshold_pi <- -coef(fit)[[1]] / coef(fit)[[2]]

      for (rho in FRONTIER_REBATE_SHARES) {
        for (t in OUTCOME_OBSERVATION_LADDER_YEARS) {
          factor_df <- rebate_price_discount_factor(sub$pi_cure, h, rho, t)
          q <- justified_arrangement_price_usd_per_course(sub$price_star_usd_per_course,
            sub$pi_cure, h, rho, t)
          # L21: the per-cure unit applies at a full rebate and nowhere else.
          per_cure <- if (rho == 1) {
            as.numeric(justified_price_usd_per_cure(sub$price_star_usd_per_course,
              sub$pi_cure, h, t))
          } else {
            rep(NA_real_, nrow(sub))
          }
          share <- still_in_drug_free_remission(sub$pi_cure, h, t)
          lump_per_cure <- ifelse(share > 0,
            suppressWarnings(as.numeric(usd_per_course_to_usd_per_cure(
              sub$price_star_usd_per_course, ifelse(share > 0, share, NA_real_), t))),
            NA_real_)
          frontier_rows[[length(frontier_rows) + 1]] <- data.frame(
            result_family = "per_cure_frontier",
            scenario_id = sprintf("cap%s-h%02.0f-lam%03.0f-rho%03.0f-T%02.0f",
              cap_label, 100 * h, lambda / 1e3, 100 * rho, t),
            maintenance_cap = cap_label,
            induction_window_weeks = INDUCTION_WINDOW_WEEKS,
            lambda_usd_per_qaly = lambda,
            h_per_year = h,
            pi_cure = sub$pi_cure,
            arrangement = "outcomes_based",
            installment_length_years = NA_real_,
            installment_financing_rate_per_year = NA_real_,
            rebate_share = rho,
            outcome_observation_years = t,
            is_base_case_contract = (rho == 1 & t == BASE_CASE_OUTCOME_OBSERVATION_YEARS),
            price_source = "frontier_P_star",
            price_usd_per_course = sub$price_star_usd_per_course,
            drug_free_remission_share_at_observation = share,
            rebate_price_discount_factor = factor_df,
            justified_price_usd_per_course = q,
            justified_price_usd_per_cure = per_cure,
            per_cure_denominator = if (rho == 1) per_cure_denominator(t) else NA_character_,
            lump_sum_cost_usd_per_cure = lump_per_cure,
            positive_price_threshold_pi_cure = threshold_pi,
            uptake_shape = NA_character_,
            uptake_ramp_period_years = NA_real_,
            terminal_uptake_share = NA_real_,
            assumed_eligible_population_patients = NA_real_,
            reporting_horizon = NA_character_,
            reporting_horizon_years = NA_real_,
            horizon_class = NA_character_,
            is_base_case_horizon = NA,
            discounted = NA,
            discounting_base_case = NA,
            analysis_discount_rate_per_year = DISCOUNT_RATE_PER_YEAR,
            arrangement_price_leg_usd = NA_real_,
            lump_sum_price_leg_usd = NA_real_,
            price_leg_share_of_lump_sum = NA_real_,
            lump_minus_arrangement_usd = NA_real_,
            cumulative_net_budget_impact_usd = NA_real_,
            cumulative_net_budget_impact_usd_pmpm = NA_real_,
            offset_captured_share = NA_real_,
            stringsAsFactors = FALSE)
        }
      }
    }
  }
}

# ==========================================================================
# The budget leg (SPEC.md section 2a; L17, L19, S10, S11)
# ==========================================================================
budget_rows <- list()
recon_rows <- list()

add_recon <- function(leg, cap_label, h, pi_cure_value, price_source, price, arrangement,
                      n_years_arg, rate_arg, rho_arg, t_arg, horizon_id, horizon_years,
                      discounted, model_usd = NA_real_, independent_usd = NA_real_,
                      model_share = NA_real_, independent_share = NA_real_) {
  recon_rows[[length(recon_rows) + 1]] <<- data.frame(
    leg = leg, maintenance_cap = cap_label, induction_window_weeks = INDUCTION_WINDOW_WEEKS,
    h_per_year = h, pi_cure = pi_cure_value, lambda_usd_per_qaly = BUDGET_LAMBDA_USD_PER_QALY,
    price_source = price_source, price_usd_per_course = price,
    arrangement = arrangement, installment_length_years = n_years_arg,
    installment_financing_rate_per_year = rate_arg,
    rebate_share = rho_arg, outcome_observation_years = t_arg,
    reporting_horizon = horizon_id, reporting_horizon_years = horizon_years,
    discounted = discounted,
    route_model_usd = model_usd, route_independent_usd = independent_usd,
    agreement_usd = model_usd - independent_usd,
    route_model_share = model_share, route_independent_share = independent_share,
    agreement_share = model_share - independent_share,
    # Only the gap leg fills this: it is not an agreement between two routes
    # but a reported quantity in its own right -- the share of the
    # pay-ahead-of-benefit gap an arrangement closes, 0 under a lump sum and 1
    # under the offset-matched schedule by construction.
    timing_gap_closed_share = if (leg == "gap_closed_single_cohort") {
      timing_gap_closed_share(model_share, independent_share)
    } else {
      NA_real_
    },
    stringsAsFactors = FALSE)
}

for (cap_on in CAPS) {
  cap_label <- if (cap_on) "on" else "off"

  grid <- standard_care_grid(INDUCTION_WINDOW_WEEKS, cap_on)
  stream_grid <- standard_care_cost_stream_grid(INDUCTION_WINDOW_WEEKS, cap_on)
  comparator <- run_comparator_trace("IFX", INDUCTION_WINDOW_WEEKS, cap_on, LIFETIME_YEARS)
  zero <- with_zero_discounting(list(
    grid = standard_care_grid(INDUCTION_WINDOW_WEEKS, cap_on),
    stream_grid = standard_care_cost_stream_grid(INDUCTION_WINDOW_WEEKS, cap_on)
  ))
  comparator_undiscounted_stream <- comparator$undiscounted_cost_stream_usd

  for (h in HAZARDS_PER_YEAR) {
    for (pi_cure_value in BUDGET_PI_GRID) {
      treg <- run_treg_trace(pi_cure_value, h, INDUCTION_WINDOW_WEEKS, cap_on, grid,
        sc_cost_stream_grid = stream_grid)
      treg_undiscounted <- with_zero_discounting(
        run_treg_trace(pi_cure_value, h, INDUCTION_WINDOW_WEEKS, cap_on, zero$grid,
          sc_cost_stream_grid = zero$stream_grid))

      lifetime_offset <- price_star_usd_per_course(pi_cure_value, h, 0, comparator, grid,
        INDUCTION_WINDOW_WEEKS, cap_on)

      # The offset-matched schedule is a DISCOUNTED-leg construct and only that
      # (T20): D(lifetime) = P*(pi, h, lambda = 0) is a present value at t = 0,
      # so the schedule is built from the discounted progression whatever a
      # row's own convention, and is left undefined on the undiscounted column.
      lifetime_cumulative_offset <- cost_offset_per_patient_usd(
        truncated_cost_usd_per_year(comparator$discounted_cost_stream_usd, Inf),
        truncated_cost_usd_per_year(treg$discounted_cost_stream_usd, Inf))
      offset_increment <- offset_increment_usd_per_year(lifetime_cumulative_offset)

      streams <- list(
        list(discounted = TRUE, treg = treg$discounted_cost_stream_usd,
          comparator = comparator$discounted_cost_stream_usd),
        list(discounted = FALSE, treg = treg_undiscounted$discounted_cost_stream_usd,
          comparator = comparator_undiscounted_stream)
      )
      prices <- list(
        list(source = "frontier_P_star",
          price = price_star_of(cap_on, h, pi_cure_value, BUDGET_LAMBDA_USD_PER_QALY)),
        list(source = "observed_analog_list_price", price = ANALOG_LIST_PRICE_USD_PER_COURSE)
      )

      for (hz in HORIZONS) {
        offset_cumulative <- cost_offset_per_patient_usd(
          truncated_cost_usd_per_year(comparator$discounted_cost_stream_usd, hz$years),
          truncated_cost_usd_per_year(treg$discounted_cost_stream_usd, hz$years))
        captured <- offset_captured_share(offset_cumulative, lifetime_offset)
        captured_at_horizon <- captured[length(captured)]

        for (st in streams) {
          treg_annual <- truncated_cost_usd_per_year(st$treg, hz$years)
          comp_annual <- truncated_cost_usd_per_year(st$comparator, hz$years)

          for (pr in prices) {
            for (sched in UPTAKE_SCHEDULE) {
              newly <- uptake_newly_treated_patients(sched$n, sched$u)
              cell <- at_rate_in_force(st$discounted, {
                current_care <- current_care_expenditure_usd_per_year(comp_annual, newly, hz$years)
                lump_leg <- sum(stacked_cohort_expenditure_usd_per_year(pr$price, newly, hz$years))
                leg <- numeric(0); total <- numeric(0)
                for (arr in ARRANGEMENTS) {
                  defined <- !(arr$kind == "offset_matched" && (!st$discounted || lifetime_offset <= 0))
                  if (defined) {
                    stream <- price_stream_for(arr, pr$price, pi_cure_value, h,
                      offset_increment, lifetime_offset)
                    treg_world <- arrangement_expenditure_usd_per_year(stream, treg_annual,
                      newly, hz$years)
                    leg <- c(leg, sum(stacked_cohort_expenditure_usd_per_year(stream, newly, hz$years)))
                    total <- c(total, sum(net_budget_impact_usd_per_year(treg_world, current_care)))
                  } else {
                    leg <- c(leg, NA_real_)
                    total <- c(total, NA_real_)
                  }
                }
                list(lump_price_leg = lump_leg, price_leg = leg, net_total = total)
              })
              lump_price_leg <- cell$lump_price_leg
              price_leg <- cell$price_leg
              net_total <- cell$net_total
              ids <- vapply(ARRANGEMENTS, function(a) a$id, character(1))
              n_arg <- vapply(ARRANGEMENTS, function(a) na_or(a$n), numeric(1))
              rate_arg <- vapply(ARRANGEMENTS, function(a) na_or(a$rate), numeric(1))
              rho_arg <- vapply(ARRANGEMENTS, function(a) na_or(a$rho), numeric(1))
              t_arg <- vapply(ARRANGEMENTS, function(a) na_or(a$t), numeric(1))

              budget_rows[[length(budget_rows) + 1]] <- data.frame(
                result_family = "budget_arrangement",
                scenario_id = sprintf("cap%s-h%02.0f-pi%03.0f-%s-u%03.0f-n%.0f-%s",
                  cap_label, 100 * h, 100 * pi_cure_value,
                  if (pr$source == "frontier_P_star") "pstar" else "analog",
                  100 * sched$u, sched$n, hz$id),
                maintenance_cap = cap_label,
                induction_window_weeks = INDUCTION_WINDOW_WEEKS,
                lambda_usd_per_qaly = BUDGET_LAMBDA_USD_PER_QALY,
                h_per_year = h,
                pi_cure = pi_cure_value,
                arrangement = ids,
                installment_length_years = n_arg,
                installment_financing_rate_per_year = rate_arg,
                rebate_share = rho_arg,
                outcome_observation_years = t_arg,
                is_base_case_contract = ids == "lump_sum",
                price_source = pr$source,
                price_usd_per_course = pr$price,
                drug_free_remission_share_at_observation = NA_real_,
                rebate_price_discount_factor = NA_real_,
                justified_price_usd_per_course = NA_real_,
                justified_price_usd_per_cure = NA_real_,
                per_cure_denominator = NA_character_,
                lump_sum_cost_usd_per_cure = NA_real_,
                positive_price_threshold_pi_cure = NA_real_,
                uptake_shape = "linear_ramp",
                uptake_ramp_period_years = BIA_UPTAKE_RAMP_PERIOD_YEARS,
                terminal_uptake_share = sched$u,
                assumed_eligible_population_patients = sched$n,
                reporting_horizon = hz$id,
                reporting_horizon_years = hz$years,
                horizon_class = hz$class,
                is_base_case_horizon = hz$id == BASE_CASE_HORIZON,
                discounted = st$discounted,
                discounting_base_case = discounting_base_case_for(hz$class, st$discounted),
                analysis_discount_rate_per_year = if (st$discounted) DISCOUNT_RATE_PER_YEAR else 0,
                arrangement_price_leg_usd = price_leg,
                lump_sum_price_leg_usd = lump_price_leg,
                price_leg_share_of_lump_sum = if (lump_price_leg > 0) price_leg / lump_price_leg else NA_real_,
                lump_minus_arrangement_usd = lump_price_leg - price_leg,
                cumulative_net_budget_impact_usd = net_total,
                cumulative_net_budget_impact_usd_pmpm = usd_per_year_to_usd_pmpm(net_total),
                offset_captured_share = if (st$discounted) captured_at_horizon else NA_real_,
                stringsAsFactors = FALSE)
            }
          }
        }
      }

      # ---------------------------------------------------------------
      # Reconciliation legs, on the central uptake schedule and the
      # single-cohort fixture. Narrow by design: these check identities,
      # and an identity checked on the whole grid is the same identity.
      # ---------------------------------------------------------------
      if (pi_cure_value %in% c(0.25, 0.50)) {
        newly <- uptake_newly_treated_patients(1e5, 0.25)
        for (pr in prices) {
          for (st in streams) {
            va <- if (st$discounted) DISCOUNT_RATE_PER_YEAR else 0
            for (hz in HORIZONS) {
              treg_annual <- truncated_cost_usd_per_year(st$treg, hz$years)
              comp_annual <- truncated_cost_usd_per_year(st$comparator, hz$years)
              for (arr in ARRANGEMENTS[vapply(ARRANGEMENTS, function(a) a$kind == "installment", logical(1))]) {
                # Built AND summed at the rate that produced this row: the
                # annuity factor is a contract term, the within-stream factor
                # is the rate in force, and separating them is trap 1.
                observed <- at_rate_in_force(st$discounted, {
                  current_care <- current_care_expenditure_usd_per_year(comp_annual, newly, hz$years)
                  stream <- installment_price_stream_usd_per_year(pr$price, arr$n, arr$rate)
                  sum(net_budget_impact_usd_per_year(
                    arrangement_expenditure_usd_per_year(pr$price, treg_annual, newly, hz$years),
                    current_care)) -
                    sum(net_budget_impact_usd_per_year(
                      arrangement_expenditure_usd_per_year(stream, treg_annual, newly, hz$years),
                      current_care))
                })
                # T19(b)'s independent route, computed from the schedule, the
                # two rates and the uptake vector alone -- no cost stream is
                # touched, and the arithmetic is written out rather than routed
                # through the module.
                annuity <- sum((1 + arr$rate)^-(seq_len(arr$n) - 1))
                delta <- 0
                for (k in seq_len(min(length(newly), hz$years))) {
                  span <- min(arr$n, hz$years - k + 1)
                  delta <- delta + newly[k] * (1 + va)^-(k - 1) *
                    (1 - sum((1 + va)^-(seq_len(span) - 1)) / annuity)
                }
                add_recon("T19b_installment_delta", cap_label, h, pi_cure_value, pr$source,
                  pr$price, arr$id, arr$n, arr$rate, NA_real_, NA_real_, hz$id, hz$years,
                  st$discounted, observed, pr$price * delta)
              }
            }
          }
        }
      }
    }
  }
}

# --- T20's identity and T21's two routes, on the reconciliation grid ------
for (cap_on in CAPS) {
  cap_label <- if (cap_on) "on" else "off"
  grid <- standard_care_grid(INDUCTION_WINDOW_WEEKS, cap_on)
  stream_grid <- standard_care_cost_stream_grid(INDUCTION_WINDOW_WEEKS, cap_on)
  comparator <- run_comparator_trace("IFX", INDUCTION_WINDOW_WEEKS, cap_on, LIFETIME_YEARS)
  # No window/cap arguments: this route prices the 12-week window and the
  # deferred comparator course directly and takes neither.
  intercept_a_zero <- frontier_intercept_independent(0, comparator, grid)
  for (h in HAZARDS_PER_YEAR) {
    slope_b_zero <- value_of_one_cure_usd(h, 0, grid)
    for (pi_cure_value in c(0.25, 0.50, 1.00)) {
      treg <- run_treg_trace(pi_cure_value, h, INDUCTION_WINDOW_WEEKS, cap_on, grid,
        sc_cost_stream_grid = stream_grid)
      lifetime_offset <- price_star_usd_per_course(pi_cure_value, h, 0, comparator, grid,
        INDUCTION_WINDOW_WEEKS, cap_on)
      comp_lifetime <- truncated_cost_usd_per_year(comparator$discounted_cost_stream_usd, Inf)
      treg_lifetime <- truncated_cost_usd_per_year(treg$discounted_cost_stream_usd, Inf)
      offset_increment <- offset_increment_usd_per_year(
        cost_offset_per_patient_usd(comp_lifetime, treg_lifetime))
      newly <- uptake_newly_treated_patients(1e5, 0.25)

      for (pr in list(
        list(source = "frontier_P_star_lambda_zero", price = lifetime_offset),
        list(source = "observed_analog_list_price", price = ANALOG_LIST_PRICE_USD_PER_COURSE))) {
        if (lifetime_offset <= 0) next
        stream <- offset_matched_price_stream_usd_per_year(pr$price, offset_increment, lifetime_offset)
        for (hz in HORIZONS) {
          treg_annual <- truncated_cost_usd_per_year(treg$discounted_cost_stream_usd, hz$years)
          comp_annual <- truncated_cost_usd_per_year(comparator$discounted_cost_stream_usd, hz$years)
          current_care <- current_care_expenditure_usd_per_year(comp_annual, newly, hz$years)
          model <- sum(net_budget_impact_usd_per_year(
            arrangement_expenditure_usd_per_year(stream, treg_annual, newly, hz$years),
            current_care))
          stacked_offset <- sum(current_care) -
            sum(stacked_cohort_expenditure_usd_per_year(treg_annual, newly, hz$years))
          independent <- (pr$price / lifetime_offset - 1) * stacked_offset
          add_recon("T20_offset_matched_identity", cap_label, h, pi_cure_value, pr$source,
            pr$price, "offset_matched", NA_real_, NA_real_, NA_real_, NA_real_,
            hz$id, hz$years, TRUE, model, independent)
        }
      }

      # T21(a): the present value of the price leg per treated patient, by the
      # budget machinery and by L21's closed form. One cohort at t = 0 -- the
      # only cohort shape in which "per treated patient" is unambiguous.
      for (rho in c(0.50, 1.00)) {
        for (t in OUTCOME_OBSERVATION_LADDER_YEARS) {
          q <- ANALOG_LIST_PRICE_USD_PER_COURSE
          stream <- outcomes_based_price_stream_usd_per_year(q, pi_cure_value, h, rho, t)
          model <- sum(stacked_cohort_expenditure_usd_per_year(stream, 1, Inf))
          independent <- q * rebate_price_discount_factor(pi_cure_value, h, rho, t)
          add_recon("T21a_outcomes_price_leg", cap_label, h, pi_cure_value,
            "observed_analog_list_price", q, "outcomes_based", NA_real_, NA_real_,
            rho, t, "lifetime", LIFETIME_YEARS, TRUE, model, independent)
        }
      }

      # T21(b)/(c): the risk-neutralising per-cure price, where the payer's
      # net budget impact stops depending on the cure fraction, and the level
      # there against a second route to A.
      for (t in OUTCOME_OBSERVATION_LADDER_YEARS) {
        tau <- rebate_settlement_years(t)
        q_flat <- slope_b_zero * exp(h * t) / discount_factor_years_to_discount_factor(tau)
        stream <- outcomes_based_price_stream_usd_per_year(q_flat, pi_cure_value, h, 1, t)
        model <- sum(net_budget_impact_usd_per_year(
          arrangement_expenditure_usd_per_year(stream, treg_lifetime, 1, Inf),
          current_care_expenditure_usd_per_year(comp_lifetime, 1, Inf)))
        independent <- slope_b_zero * exp(h * t) *
          (1 / discount_factor_years_to_discount_factor(tau) - 1) - intercept_a_zero
        add_recon("T21c_risk_neutral_level", cap_label, h, pi_cure_value,
          "risk_neutralising_q_flat", q_flat, "outcomes_based", NA_real_, NA_real_,
          1, t, "lifetime", LIFETIME_YEARS, TRUE, model, independent)
      }

      # The timing gap an arrangement closes, on the single-cohort fixture and
      # under one stated discounting convention (3%). Under a lump sum the
      # share paid by H is 1 and the gap closed is 0; under the offset-matched
      # schedule the two coincide and the gap closed is 1 by construction.
      if (lifetime_offset > 0) {
        for (hz in HORIZONS) {
          treg_annual <- truncated_cost_usd_per_year(treg$discounted_cost_stream_usd, hz$years)
          comp_annual <- truncated_cost_usd_per_year(comparator$discounted_cost_stream_usd, hz$years)
          captured <- offset_captured_share(
            cost_offset_per_patient_usd(comp_annual, treg_annual), lifetime_offset)
          captured_at <- captured[length(captured)]
          price <- ANALOG_LIST_PRICE_USD_PER_COURSE
          for (arr in ARRANGEMENTS) {
            if (arr$kind == "outcomes") next
            stream <- price_stream_for(arr, price, pi_cure_value, h, offset_increment, lifetime_offset)
            paid <- sum(stacked_cohort_expenditure_usd_per_year(stream, 1, hz$years)) / price
            add_recon("gap_closed_single_cohort", cap_label, h, pi_cure_value,
              "observed_analog_list_price", price, arr$id, na_or(arr$n), na_or(arr$rate),
              NA_real_, NA_real_, hz$id, hz$years, TRUE, NA_real_, NA_real_,
              paid, captured_at)
          }
        }
      }
    }
  }
}

# --- A6 agreement: A7's lump sum IS A6's budget impact --------------------
bia <- read.csv("output/tables/budget_impact.csv", comment.char = "#", stringsAsFactors = FALSE)
a6_totals <- stats::aggregate(cumulative_net_budget_impact_usd ~ scenario_id + reporting_horizon +
  discounted, data = bia, FUN = function(x) x[length(x)])
pa_lump <- do.call(rbind, budget_rows)
pa_lump <- pa_lump[pa_lump$arrangement == "lump_sum", ]
pa_lump$a6_scenario_id <- sub("-[0-9]+yr$", "", pa_lump$scenario_id)
merged <- merge(pa_lump, a6_totals,
  by.x = c("a6_scenario_id", "reporting_horizon", "discounted"),
  by.y = c("scenario_id", "reporting_horizon", "discounted"))
stopifnot(nrow(merged) == nrow(pa_lump))
for (i in seq_len(nrow(merged))) {
  # ONE LEG, BOTH COLUMNS. A7's lump sum and A6's own figure are the same
  # arithmetic under the same convention on each column: on the discounted rows
  # both stack at 3%, and on the undiscounted rows both stack at a zero rate --
  # A6 through `treg_world_undiscounted_expenditure_usd_per_year()`, A7 through
  # `at_rate_in_force()`. The two agree EXACTLY at every cell before rounding,
  # so what this leg reports is A6's rounding to the cent in the file it reads
  # and nothing else. It is an identity on both columns, not an identity on one
  # and a published discrepancy on the other.
  add_recon("A6_lump_sum_agreement", merged$maintenance_cap[i], merged$h_per_year[i],
    merged$pi_cure[i], merged$price_source[i], merged$price_usd_per_course[i], "lump_sum",
    NA_real_, NA_real_, NA_real_, NA_real_, merged$reporting_horizon[i],
    merged$reporting_horizon_years[i], merged$discounted[i],
    merged$cumulative_net_budget_impact_usd.x[i], merged$cumulative_net_budget_impact_usd.y[i])
}

# --- Write ---------------------------------------------------------------
pa <- rbind(do.call(rbind, frontier_rows), do.call(rbind, budget_rows))
for (col in grep("_usd$|_usd_per_year$|_usd_pmpm$|_usd_per_course$|_usd_per_cure$", names(pa), value = TRUE)) {
  pa[[col]] <- round(pa[[col]], 2)
}
for (col in c("offset_captured_share", "price_leg_share_of_lump_sum",
              "rebate_price_discount_factor", "drug_free_remission_share_at_observation",
              "positive_price_threshold_pi_cure")) {
  pa[[col]] <- round(pa[[col]], 6)
}
stamp_output(pa, "output/tables/payment_arrangements.csv")

recon <- do.call(rbind, recon_rows)
stamp_output(recon, "output/tables/payment_arrangements_reconciliation.csv")

cat(sprintf("Wrote payment_arrangements.csv (%d rows: %d per-cure frontier, %d budget) and payment_arrangements_reconciliation.csv (%d rows).\n",
  nrow(pa), sum(pa$result_family == "per_cure_frontier"),
  sum(pa$result_family == "budget_arrangement"), nrow(recon)))
for (lg in setdiff(unique(recon$leg), "gap_closed_single_cohort")) {
  sub <- recon[recon$leg == lg, ]
  cat(sprintf("  %-32s worst |agreement| = $%.10g over %d legs\n", lg,
    max(abs(sub$agreement_usd), na.rm = TRUE), nrow(sub)))
}
gap <- recon[recon$leg == "gap_closed_single_cohort", ]
cat(sprintf("  %-32s lump sum %.4f, offset-matched %.4f (by construction 0 and 1)\n",
  "gap_closed_single_cohort",
  max(abs(gap$timing_gap_closed_share[gap$arrangement == "lump_sum"])),
  min(gap$timing_gap_closed_share[gap$arrangement == "offset_matched"])))
three_year <- gap$reporting_horizon == "3yr" & gap$arrangement == "installment_pv_neutral_5yr"
cat(sprintf("  gap_closed(3yr), 5-year present-value-neutral installment, single cohort, 3%%: %.4f to %.4f\n",
  min(gap$timing_gap_closed_share[three_year]), max(gap$timing_gap_closed_share[three_year])))
