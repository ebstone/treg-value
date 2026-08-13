# Produces SPEC.md section 6's five aim outputs under their designated
# filenames. Run from the repository root, after analysis/run_psa.R (A5
# reads that run's draws rather than repeating them).
#
# L5 and L6 are bounding pairs reported on every primary output, so A1 and
# A2 carry all four induction-window/cap combinations.

source("R/io_cache.R")
source("R/price_index.R")
source("R/denominator.R")
source("derive/health_state_costs.R")
source("R/transition_matrices.R")
source("R/life_table.R")
source("R/dosing.R")
source("R/costs_utilities.R")
source("R/refractory.R")
source("R/markov_engine.R")
source("R/treg_arm.R")
source("R/frontier.R")
source("R/analog_comparison.R")
source("R/manufacturing_benchmark.R")
source("R/stamp.R")

HAZARDS_PER_YEAR <- c(0, 0.05, 0.10)
LAMBDAS_USD_PER_QALY <- c(5e4, 1e5, 1.5e5)
PI_GRID <- seq(0, 1, length.out = 101) # SPEC.md section 5
WINDOWS <- c(4, 8)
CAPS <- c(TRUE, FALSE)

value_rows <- list()
frontier_rows <- list()

for (window in WINDOWS) {
  for (cap_on in CAPS) {
    grid <- standard_care_grid(window, cap_on)
    comparator <- run_comparator_trace("IFX", window, cap_on, 100 - MODEL_START_AGE_YEARS)
    for (lambda in LAMBDAS_USD_PER_QALY) {
      a <- frontier_intercept_from_model(0, lambda, comparator, grid, window, cap_on)
      for (h in HAZARDS_PER_YEAR) {
        b <- value_of_one_cure_usd(h, lambda, grid)
        value_rows[[length(value_rows) + 1]] <- data.frame(
          induction_window_weeks = window, maintenance_cap = if (cap_on) "on" else "off",
          lambda_usd_per_qaly = lambda, h_per_year = h,
          intercept_a_usd_per_course = a, value_of_one_cure_b_usd = b,
          stringsAsFactors = FALSE)
        frontier_rows[[length(frontier_rows) + 1]] <- data.frame(
          induction_window_weeks = window, maintenance_cap = if (cap_on) "on" else "off",
          lambda_usd_per_qaly = lambda, h_per_year = h, pi_cure = PI_GRID,
          price_star_usd_per_course = vapply(PI_GRID, function(p) {
            price_star_usd_per_course(p, h, lambda, comparator, grid, window, cap_on)
          }, numeric(1)),
          stringsAsFactors = FALSE)
      }
    }
  }
}

# --- A1: what one durable cure is worth ---------------------------------
stamp_output(do.call(rbind, value_rows), "output/tables/value_of_one_cure.csv")

# --- A2: the price frontier ---------------------------------------------
stamp_output(do.call(rbind, frontier_rows), "output/tables/price_frontier.csv")

# --- A4: per-patient EVPI and break-even eligible population ------------
# SPEC.md section 9 O1 states A4 reports the break-even threshold only until
# an eligible-population figure is sourced, and O2 leaves the confirmatory
# trial cost unsourced too. The break-even population is therefore reported
# as the arithmetic A4 asks to show -- N = trial cost / per-patient EVPI --
# across a schedule of trial costs, rather than as a single number resting
# on an unsourced input.
evpi <- read.csv("output/tables/evpi_per_patient_w6.csv", comment.char = "#", stringsAsFactors = FALSE)
trial_costs <- c(2.5e7, 5e7, 1e8)
voi_rows <- list()
for (i in seq_len(nrow(evpi))) {
  for (tc in trial_costs) {
    voi_rows[[length(voi_rows) + 1]] <- data.frame(
      lambda_usd_per_qaly = evpi$lambda_usd_per_qaly[i],
      h_per_year = evpi$h_per_year[i],
      pi_cure = evpi$pi_cure[i],
      price_usd_per_course = evpi$price_usd_per_course[i],
      evpi_per_patient_usd = evpi$evpi_per_patient_usd[i],
      assumed_trial_cost_usd = tc,
      breakeven_eligible_population =
        ifelse(evpi$evpi_per_patient_usd[i] > 0, tc / evpi$evpi_per_patient_usd[i], NA_real_),
      stringsAsFactors = FALSE)
  }
}
stamp_output(do.call(rbind, voi_rows), "output/tables/voi_breakeven.csv")

# --- A5: probabilistic analysis -----------------------------------------
psa <- read.csv("output/tables/psa_summary_w6.csv", comment.char = "#", stringsAsFactors = FALSE)
stamp_output(psa, "output/tables/psa_summary.csv")

cat("Wrote all five aim outputs.\n")
