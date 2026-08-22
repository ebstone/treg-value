# A6 -- the payer budget impact analysis. SPEC.md section 2a, L10-L16.
#
# Run from the repository root, AFTER analysis/run_aims.R: the price axis is
# this study's own frontier, read from output/tables/price_frontier.csv rather
# than recomputed, so a budget cell and the frontier cell it rests on can never
# drift apart.
#
# WHAT IS COMMITTED HERE, AND WHY THE GRID IS THE SHAPE IT IS.
#
# A6 needs four commitments A1-A5 refuse: a price, a cure fraction, an uptake
# path and a horizon. Price and cure fraction come off the frontier; uptake is
# swept; the horizon is a stated choice with a 3-year base case (L10). Every
# row is therefore a cell conditional on all four, and no row is an estimate of
# what will happen.
#
# The grid is deliberately narrower than the frontier's:
#
#   * Induction window fixed at 8 weeks. The window pair is scenario S1 and
#     moves every figure in this study by under 1.6%; the readout's own central
#     case is 8 weeks. The maintenance-cap pair (L6) IS carried, because it is
#     more load-bearing here than anywhere else in the study -- with the cap on,
#     both worlds are on conventional therapy after two years and nearly the
#     whole drug-cost offset falls inside even a short window.
#
#   * Cure fraction at four points rather than 101. Net budget impact is exactly
#     affine in the cure fraction (T14), so four points over-determine the line
#     and a 101-point sweep would multiply the file by 25 for no information.
#
#   * The eligible population and the uptake level are a labelled SCHEDULE
#     rather than a full cross. Net budget impact scales exactly linearly in the
#     number treated (T16), so the population schedule is shown at the central
#     uptake level and the uptake sweep at the central population; the missing
#     cells are the product of two columns that are already printed.
#
# THE POPULATION IS NOT SOURCED (O11). The schedule below is a set of round
# illustrative sizes chosen for legibility, in the same spirit as
# `assumed_trial_cost_usd` in A4, and is labelled that way in the column name.
# It estimates nothing.

source("R/io_cache.R")
source("R/price_index.R")
source("R/denominator.R")
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
source("R/budget_impact.R")
source("R/stamp.R")

INDUCTION_WINDOW_WEEKS <- 8
CAPS <- c(TRUE, FALSE)
HAZARDS_PER_YEAR <- c(0, 0.05, 0.10)
PI_GRID <- c(0.25, 0.50, 0.75, 1.00)
LAMBDA_USD_PER_QALY <- 1e5
LIFETIME_YEARS <- 100 - MODEL_START_AGE_YEARS

# (terminal uptake share, assumed eligible pool). 0 and 1 are both present, as
# SPEC.md section 5 requires of the uptake grid.
#
# The pool sizes are a decade ladder rather than a linear one, and that is the
# only choice here with any content. PMPM is stated on a 1,000,000-member plan
# (SPEC.md section 2a), so the top of the ladder is a national-scale pool whose
# PMPM restatement implies an eligibility rate no single plan would see, and the
# bottom is a plan-scale pool where the PMPM column reads as a payer would read
# it. Spanning both ends is what lets a reader tell which of the two a given
# figure is. The sizes estimate nothing.
UPTAKE_SCHEDULE <- list(
  list(u = 0.00, n = 1e5),
  list(u = 0.25, n = 1e3),
  list(u = 0.25, n = 1e4),
  list(u = 0.25, n = 1e5),
  list(u = 1.00, n = 1e5)
)

# Year-resolved reporting horizons. The lifetime leg is the T13 reconciliation
# fixture and the offset-capture denominator, and is never reported as a budget
# impact (L10) -- it appears in budget_impact_reconciliation.csv as a total,
# alongside the 40-year leg, and carries no year rows here.
HORIZONS <- list(
  list(id = "1yr", years = 1, class = "bia"),
  list(id = "3yr", years = 3, class = "bia"),
  list(id = "5yr", years = 5, class = "bia"),
  list(id = "10yr", years = 10, class = "extended_projection"),
  list(id = "30yr", years = 30, class = "extended_projection")
)
BASE_CASE_HORIZON <- "3yr" # L10
RECONCILIATION_HORIZONS <- list(
  list(id = "3yr", years = 3),
  list(id = "30yr", years = 30),
  list(id = "40yr", years = 40),
  list(id = "lifetime", years = Inf)
)

# L11: the base-case discounting convention follows the horizon's CLASS, not a
# rate. A budget forecast is nominal cash flow; a cost-accrual projection is
# discounted like everything else in this study.
discounting_base_case_for <- function(horizon_class, discounted) {
  (horizon_class == "bia" && !discounted) || (horizon_class != "bia" && discounted)
}

with_zero_discounting <- function(expr) {
  old <- getOption("treg_value.discount_rate")
  options(treg_value.discount_rate = 0)
  on.exit(options(treg_value.discount_rate = old), add = TRUE)
  force(expr)
}

# --- Price axes ----------------------------------------------------------
# Axis 1: this study's own frontier. Zero new assumptions -- every value is
# already a published A2 output.
frontier <- read.csv("output/tables/price_frontier.csv", comment.char = "#", stringsAsFactors = FALSE)
price_star_of <- function(cap_on, h, pi_cure) {
  row <- frontier$induction_window_weeks == INDUCTION_WINDOW_WEEKS &
    frontier$maintenance_cap == (if (cap_on) "on" else "off") &
    frontier$lambda_usd_per_qaly == LAMBDA_USD_PER_QALY &
    frontier$h_per_year == h & abs(frontier$pi_cure - pi_cure) < 1e-9
  stopifnot(sum(row) == 1)
  frontier$price_star_usd_per_course[row]
}

# Axis 2: externally observed analog list prices, read straight from raw and
# labelled separately. These are what payers already pay for one-time cell
# therapies in other indications; they are not a claim about this product, and
# nothing derived from the manufacturing benchmark enters either axis (L8).
analogs <- read.csv("data/raw/cell_therapy_revealed_prices_2025.csv", stringsAsFactors = FALSE)
ANALOG_LIST_PRICE_USD_PER_COURSE <- median(analogs$us_list_price_usd, na.rm = TRUE)

# --- Per-patient cost streams, computed once at the lifetime horizon ------
rows <- list()
recon_rows <- list()

for (cap_on in CAPS) {
  cap_label <- if (cap_on) "on" else "off"

  grid <- standard_care_grid(INDUCTION_WINDOW_WEEKS, cap_on)
  stream_grid <- standard_care_cost_stream_grid(INDUCTION_WINDOW_WEEKS, cap_on)
  comparator <- run_comparator_trace("IFX", INDUCTION_WINDOW_WEEKS, cap_on, LIFETIME_YEARS)

  # The undiscounted leg is the same computation at a zero rate, not the same
  # numbers read differently: the standard-care grids are discounted to each
  # patient's own start, so an undiscounted Treg world needs the arm re-run
  # against undiscounted grids.
  zero <- with_zero_discounting(list(
    grid = standard_care_grid(INDUCTION_WINDOW_WEEKS, cap_on),
    stream_grid = standard_care_cost_stream_grid(INDUCTION_WINDOW_WEEKS, cap_on)
  ))
  # The comparator's undiscounted stream is returned alongside the discounted
  # one by the same run, so it costs nothing.
  comparator_undiscounted_stream <- comparator$undiscounted_cost_stream_usd

  intercept_a <- frontier_intercept_from_model(0, LAMBDA_USD_PER_QALY, comparator, grid,
    INDUCTION_WINDOW_WEEKS, cap_on)

  for (h in HAZARDS_PER_YEAR) {
    slope_b <- value_of_one_cure_usd(h, LAMBDA_USD_PER_QALY, grid)

    for (pi_cure_value in PI_GRID) {
      treg <- run_treg_trace(pi_cure_value, h, INDUCTION_WINDOW_WEEKS, cap_on, grid,
        sc_cost_stream_grid = stream_grid)
      treg_undiscounted <- with_zero_discounting(
        run_treg_trace(pi_cure_value, h, INDUCTION_WINDOW_WEEKS, cap_on, zero$grid,
          sc_cost_stream_grid = zero$stream_grid))

      # D(lifetime), the offset-capture denominator: the frontier's own route,
      # P*(pi, h, lambda = 0). A budget holds no QALYs (SPEC.md section 2a).
      lifetime_offset <- price_star_usd_per_course(pi_cure_value, h, 0, comparator, grid,
        INDUCTION_WINDOW_WEEKS, cap_on)

      streams <- list(
        list(discounted = TRUE, treg = treg$discounted_cost_stream_usd,
          comparator = comparator$discounted_cost_stream_usd),
        list(discounted = FALSE, treg = treg_undiscounted$discounted_cost_stream_usd,
          comparator = comparator_undiscounted_stream)
      )

      prices <- list(
        list(source = "frontier_P_star",
          price = price_star_of(cap_on, h, pi_cure_value)),
        list(source = "observed_analog_list_price",
          price = ANALOG_LIST_PRICE_USD_PER_COURSE)
      )

      # --- T13's evidence: the reconciliation legs ------------------------
      # One cohort of one patient treated at t = 0, 3% discounting, so the
      # BIA's own arithmetic must reproduce `price - P*(pi, h, lambda = 0)` at
      # the lifetime horizon and nowhere else.
      for (pr in prices) {
        for (rh in RECONCILIATION_HORIZONS) {
          treg_annual <- truncated_cost_usd_per_year(treg$discounted_cost_stream_usd, rh$years)
          comp_annual <- truncated_cost_usd_per_year(comparator$discounted_cost_stream_usd, rh$years)
          one_patient <- 1
          bia_route <- sum(net_budget_impact_usd_per_year(
            treg_world_expenditure_usd_per_year(pr$price, treg_annual, one_patient, rh$years),
            current_care_expenditure_usd_per_year(comp_annual, one_patient, rh$years)))
          frontier_route <- if (is.infinite(rh$years)) pr$price - lifetime_offset else NA_real_
          recon_rows[[length(recon_rows) + 1]] <- data.frame(
            maintenance_cap = cap_label, induction_window_weeks = INDUCTION_WINDOW_WEEKS,
            pi_cure = pi_cure_value, h_per_year = h, price_source = pr$source,
            price_usd_per_course = pr$price,
            reporting_horizon = rh$id,
            reporting_horizon_years = if (is.infinite(rh$years)) LIFETIME_YEARS else rh$years,
            bia_route_usd = bia_route, frontier_route_usd = frontier_route,
            agreement_usd = bia_route - frontier_route,
            stringsAsFactors = FALSE)
        }
      }

      # --- The grid ------------------------------------------------------
      for (hz in HORIZONS) {
        # D(H) per treated patient, discounted at 3% whatever the row's own
        # convention: the offset-capture progression is defined at 3% (L10).
        offset_cumulative <- cost_offset_per_patient_usd(
          truncated_cost_usd_per_year(comparator$discounted_cost_stream_usd, hz$years),
          truncated_cost_usd_per_year(treg$discounted_cost_stream_usd, hz$years))

        for (st in streams) {
          treg_annual <- truncated_cost_usd_per_year(st$treg, hz$years)
          comp_annual <- truncated_cost_usd_per_year(st$comparator, hz$years)

          for (pr in prices) {
            required_pi <- required_cure_fraction(pr$price, intercept_a, slope_b)
            for (sched in UPTAKE_SCHEDULE) {
              newly <- uptake_newly_treated_patients(sched$n, sched$u)
              newly_in_window <- c(newly, numeric(max(hz$years - length(newly), 0L)))[seq_len(hz$years)]

              treg_world <- treg_world_expenditure_usd_per_year(pr$price, treg_annual, newly, hz$years)
              current_care <- current_care_expenditure_usd_per_year(comp_annual, newly, hz$years)
              net <- net_budget_impact_usd_per_year(treg_world, current_care)

              rows[[length(rows) + 1]] <- data.frame(
                scenario_id = sprintf("cap%s-h%02.0f-pi%03.0f-%s-u%03.0f-n%.0f",
                  cap_label, 100 * h, 100 * pi_cure_value,
                  if (pr$source == "frontier_P_star") "pstar" else "analog",
                  100 * sched$u, sched$n),
                uptake_shape = "linear_ramp",
                uptake_ramp_period_years = BIA_UPTAKE_RAMP_PERIOD_YEARS,
                maintenance_cap = cap_label,
                induction_window_weeks = INDUCTION_WINDOW_WEEKS,
                price_source = pr$source,
                price_usd_per_course = pr$price,
                pi_cure = pi_cure_value,
                h_per_year = h,
                lambda_usd_per_qaly = LAMBDA_USD_PER_QALY,
                terminal_uptake_share = sched$u,
                assumed_eligible_population_patients = sched$n,
                reporting_horizon = hz$id,
                reporting_horizon_years = hz$years,
                horizon_class = hz$class,
                is_base_case_horizon = hz$id == BASE_CASE_HORIZON,
                discounted = st$discounted,
                discounting_base_case = discounting_base_case_for(hz$class, st$discounted),
                year = seq_len(hz$years),
                patients_newly_treated_patients = newly_in_window,
                patients_ever_treated_patients = cumsum(newly_in_window),
                treg_world_expenditure_usd_per_year = treg_world,
                current_care_expenditure_usd_per_year = current_care,
                net_budget_impact_usd_per_year = net,
                net_budget_impact_usd_pmpm = usd_per_year_to_usd_pmpm(net),
                cumulative_net_budget_impact_usd = cumsum(net),
                offset_captured_share = if (st$discounted) {
                  offset_captured_share(offset_cumulative, lifetime_offset)
                } else {
                  NA_real_
                },
                required_cure_fraction_all_treated = required_pi,
                # Compared with a tolerance, not bit for bit. On the frontier
                # price axis the required fraction IS this row's own pi by
                # construction, and an exact `>=` reports that identity as FALSE
                # at whichever grid points happen to land a unit in the last
                # place low -- an artefact that reads as a substantive claim.
                pi_at_or_above_required = pi_cure_value >= required_pi - 1e-9,
                stringsAsFactors = FALSE)
            }
          }
        }
      }
    }
  }
}

bia <- do.call(rbind, rows)
# Money to the cent. A payer's cheque has two decimal places, and 15 significant
# figures on a per-year expenditure would state a precision the eligible
# population alone denies it by three orders of magnitude.
for (col in grep("_usd$|_usd_per_year$|_usd_pmpm$|_usd_per_course$", names(bia), value = TRUE)) {
  bia[[col]] <- round(bia[[col]], 2)
}
bia$offset_captured_share <- round(bia$offset_captured_share, 6)
bia$required_cure_fraction_all_treated <- round(bia$required_cure_fraction_all_treated, 6)
stamp_output(bia, "output/tables/budget_impact.csv")

recon <- do.call(rbind, recon_rows)
stamp_output(recon, "output/tables/budget_impact_reconciliation.csv")

lifetime_leg <- recon[recon$reporting_horizon == "lifetime", ]
cat(sprintf("Wrote budget_impact.csv (%d rows) and budget_impact_reconciliation.csv (%d rows).\n",
  nrow(bia), nrow(recon)))
cat(sprintf("T13 reconciliation, lifetime leg: worst |bia route - frontier route| = $%.6f over %d legs.\n",
  max(abs(lifetime_leg$agreement_usd)), nrow(lifetime_leg)))
