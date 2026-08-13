# W4: the price frontier. Assembles A, B and P*(pi, h, lambda) across the
# grids SPEC.md section 5 specifies, plus the analog comparison (section 7)
# and the required cure fraction at a hypothetical benchmark price.
#
# Run from the repository root.
#
# No probabilistic analysis, no EVPI/EVPPI (W6). No manufacturing benchmark
# (W5) -- the $20,000 course price below is a stated hypothetical used to
# invert an already-computed frontier, never an input to it.

source("R/io_cache.R")
source("R/price_index.R")
source("R/denominator.R")
source("derive/health_state_costs.R")
source("R/transition_matrices.R")
source("R/life_table.R")
source("R/dosing.R")
source("R/costs_utilities.R")
source("R/markov_engine.R")
source("R/treg_arm.R")
source("R/frontier.R")
source("R/analog_comparison.R")
source("R/stamp.R")

HAZARDS_PER_YEAR <- c(0, 0.05, 0.10)
LAMBDAS_USD_PER_QALY <- c(5e4, 1e5, 1.5e5)
REPORT_PI <- c(0, 0.25, 0.5, 0.75, 1)
HYPOTHETICAL_COURSE_PRICE_USD <- 2e4
CENTRAL_WINDOW_WEEKS <- 8
CENTRAL_CAP_ON <- TRUE
CENTRAL_HAZARD <- 0.05

# L5 and L6 are bounding pairs reported on every primary output.
frontier_rows <- list()
value_rows <- list()

for (window in c(4, 8)) {
  for (cap_on in c(TRUE, FALSE)) {
    grid <- standard_care_grid(window, cap_on)
    comparator <- run_comparator_trace("IFX", window, cap_on, 100 - MODEL_START_AGE_YEARS)

    for (lambda in LAMBDAS_USD_PER_QALY) {
      a_model <- frontier_intercept_from_model(0, lambda, comparator, grid, window, cap_on)
      a_independent <- frontier_intercept_independent(lambda, comparator, grid)

      for (h in HAZARDS_PER_YEAR) {
        b <- value_of_one_cure_usd(h, lambda, grid)
        value_rows[[length(value_rows) + 1]] <- data.frame(
          induction_window_weeks = window,
          maintenance_cap = if (cap_on) "on" else "off",
          lambda_usd_per_qaly = lambda,
          h_per_year = h,
          intercept_a_usd_per_course = a_model,
          intercept_a_independent_usd_per_course = a_independent,
          intercept_agreement_usd = a_model - a_independent,
          value_of_one_cure_b_usd = b,
          required_cure_fraction_at_hypothetical_price =
            required_cure_fraction(HYPOTHETICAL_COURSE_PRICE_USD, a_model, b),
          stringsAsFactors = FALSE
        )
        for (p in REPORT_PI) {
          frontier_rows[[length(frontier_rows) + 1]] <- data.frame(
            induction_window_weeks = window,
            maintenance_cap = if (cap_on) "on" else "off",
            lambda_usd_per_qaly = lambda,
            h_per_year = h,
            pi_cure = p,
            price_star_usd_per_course =
              price_star_usd_per_course(p, h, lambda, comparator, grid, window, cap_on),
            stringsAsFactors = FALSE
          )
        }
      }
    }
  }
}

frontier <- do.call(rbind, frontier_rows)
value <- do.call(rbind, value_rows)

# Section 7: the analog comparison, on the decayed quantity, never on pi_cure.
analogs <- do.call(rbind, lapply(HAZARDS_PER_YEAR, function(h) {
  tbl <- analog_comparison_table(0.5, h)
  tbl$h_per_year <- h
  tbl$pi_cure_assessed_at_landmark <- 0.5
  tbl
}))

stamp_output(frontier, "output/tables/price_frontier_w4.csv")
stamp_output(value, "output/tables/value_of_one_cure_w4.csv")
stamp_output(analogs, "output/tables/analog_comparison_w4.csv")

central <- value[value$induction_window_weeks == CENTRAL_WINDOW_WEEKS &
  value$maintenance_cap == "on", ]
cat("\n--- A (intercept), both routes, central case ---\n")
print(unique(central[, c("lambda_usd_per_qaly", "intercept_a_usd_per_course",
  "intercept_a_independent_usd_per_course", "intercept_agreement_usd")]))
cat("\n--- B (value of one cure) by h and lambda, central case ---\n")
print(central[, c("lambda_usd_per_qaly", "h_per_year", "value_of_one_cure_b_usd")])
cat("\n--- P* by pi, central case (h = 0.05) ---\n")
print(frontier[frontier$induction_window_weeks == CENTRAL_WINDOW_WEEKS &
  frontier$maintenance_cap == "on" & frontier$h_per_year == CENTRAL_HAZARD,
c("lambda_usd_per_qaly", "pi_cure", "price_star_usd_per_course")])
cat("\n--- Required cure fraction at $20,000/course, central case ---\n")
print(central[, c("lambda_usd_per_qaly", "h_per_year", "required_cure_fraction_at_hypothetical_price")])
