# W3: the lifetime infliximab comparator trace, under every combination
# SPEC.md requires -- both induction windows (L5), cap-on/cap-off (L6), and
# all three horizons (lifetime, 30-year, 40-year). Writes two intermediate
# artifacts through stamp_output(): the trace itself and a validation
# summary. Neither is an aim output (SPEC.md section 6) -- this session
# builds no Treg arm, no cure fraction, no price, no frontier (W4).

# Run from the repository root.
source("R/io_cache.R")
source("R/price_index.R")
source("derive/health_state_costs.R")
source("R/transition_matrices.R")
source("R/life_table.R")
source("R/dosing.R")
source("R/costs_utilities.R")
source("R/refractory.R")
source("R/markov_engine.R")
source("R/stamp.R")

LIFETIME_HORIZON_YEARS <- 100 - MODEL_START_AGE_YEARS # life table's max age is 100; guarantees full exhaustion
HORIZONS <- c(lifetime = LIFETIME_HORIZON_YEARS, `30yr` = 30, `40yr` = 40)
WINDOWS <- c(4, 8)
CAPS <- c(TRUE, FALSE)

trace_rows <- list()
validation_rows <- list()

for (horizon_name in names(HORIZONS)) {
  horizon_years <- HORIZONS[[horizon_name]]
  for (window in WINDOWS) {
    for (cap_on in CAPS) {
      result <- run_comparator_trace("IFX", window, cap_on, horizon_years)
      trace_rows[[length(trace_rows) + 1]] <- data.frame(
        therapy = "IFX",
        induction_window_weeks = window,
        maintenance_cap = if (cap_on) "on" else "off",
        horizon = horizon_name,
        horizon_years = horizon_years,
        discounted_cost_usd = result$discounted_cost_usd,
        discounted_qaly = result$discounted_qaly,
        undiscounted_life_years = result$undiscounted_life_years,
        dose_cycles_charged = result$dose_cycles_charged,
        stringsAsFactors = FALSE
      )
      validation_rows[[length(validation_rows) + 1]] <- data.frame(
        induction_window_weeks = window,
        maintenance_cap = if (cap_on) "on" else "off",
        horizon = horizon_name,
        max_state_sum_deviation = max(abs(result$state_sums - 1)),
        n_cycles_checked = length(result$state_sums),
        cohort_exhausted = abs(result$final_on_biologic[["Death"]] + result$final_on_ct[["Death"]] - 1) < 1e-6,
        stringsAsFactors = FALSE
      )
    }
  }
}

trace <- do.call(rbind, trace_rows)
validation <- do.call(rbind, validation_rows)

stamp_output(trace, "output/tables/comparator_ifx_trace.csv")
stamp_output(validation, "output/tables/comparator_ifx_validation.csv")

cat("Wrote output/tables/comparator_ifx_trace.csv and comparator_ifx_validation.csv\n")
print(trace[trace$horizon == "lifetime", c("induction_window_weeks", "maintenance_cap", "discounted_cost_usd", "discounted_qaly")])
