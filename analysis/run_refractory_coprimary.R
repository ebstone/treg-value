# The refractory co-primary population (SPEC.md section 2; also scenario S2
# in section 5). Run from the repository root.
#
# "Run identically to base case" is taken literally: the same bounding
# pairs, the same hazard and willingness-to-pay grids, the same benchmark
# anchors. The only difference is the induction transition matrix, which
# carries the UNITI-1 / UNITI-2 refractory adjustment.

source("R/io_cache.R")
source("R/price_index.R")
source("R/denominator.R")
source("derive/health_state_costs.R")
source("R/transition_matrices.R")
source("R/refractory.R")
source("R/life_table.R")
source("R/dosing.R")
source("R/costs_utilities.R")
source("R/markov_engine.R")
source("R/treg_arm.R")
source("R/frontier.R")
source("R/manufacturing_benchmark.R")
source("R/stamp.R")

HAZARDS_PER_YEAR <- c(0, 0.05, 0.10)
LAMBDAS_USD_PER_QALY <- c(5e4, 1e5, 1.5e5)
POPULATIONS <- c("naive", "refractory")
WINDOWS <- c(4, 8)
CAPS <- c(TRUE, FALSE)

rows <- list()
for (population in POPULATIONS) {
  for (window in WINDOWS) {
    for (cap_on in CAPS) {
      grid <- standard_care_grid(window, cap_on, population = population)
      comparator <- run_comparator_trace("IFX", window, cap_on,
        100 - MODEL_START_AGE_YEARS, population = population)
      for (lambda in LAMBDAS_USD_PER_QALY) {
        a <- frontier_intercept_from_model(0, lambda, comparator, grid, window, cap_on)
        for (h in HAZARDS_PER_YEAR) {
          b <- value_of_one_cure_usd(h, lambda, grid)
          rows[[length(rows) + 1]] <- data.frame(
            population = population,
            induction_window_weeks = window,
            maintenance_cap = if (cap_on) "on" else "off",
            lambda_usd_per_qaly = lambda, h_per_year = h,
            comparator_discounted_qaly = comparator$discounted_qaly,
            comparator_discounted_cost_usd = comparator$discounted_cost_usd,
            intercept_a_usd_per_course = a,
            value_of_one_cure_b_usd = b,
            stringsAsFactors = FALSE)
        }
      }
    }
  }
}
coprimary <- do.call(rbind, rows)

# Required cure fraction at each manufacturing benchmark, both populations.
bench <- manufacturing_benchmark_usd_per_course()
anchors <- data.frame(
  benchmark_anchor = c("Allogeneic, batch-amortised (low)", "Allogeneic median",
    "Allogeneic, single-treatment batch (high)", "Autologous CAR-T cost of goods (upper)"),
  benchmark_cost_usd_per_course = c(bench$low_usd, bench$allogeneic_median_usd,
    bench$allogeneic_high_usd, bench$high_usd),
  stringsAsFactors = FALSE)

central <- coprimary[coprimary$induction_window_weeks == 8 & coprimary$maintenance_cap == "on", ]
req <- do.call(rbind, lapply(seq_len(nrow(central)), function(i) {
  data.frame(
    population = central$population[i],
    lambda_usd_per_qaly = central$lambda_usd_per_qaly[i],
    h_per_year = central$h_per_year[i],
    benchmark_anchor = anchors$benchmark_anchor,
    benchmark_cost_usd_per_course = anchors$benchmark_cost_usd_per_course,
    required_cure_fraction_all_treated = required_cure_fraction(
      anchors$benchmark_cost_usd_per_course,
      central$intercept_a_usd_per_course[i], central$value_of_one_cure_b_usd[i]),
    stringsAsFactors = FALSE)
}))
req$achievable <- req$required_cure_fraction_all_treated <= 1

stamp_output(coprimary, "output/tables/refractory_coprimary.csv")
stamp_output(req, "output/tables/required_cure_fraction_by_population.csv")

cat("\n--- A and B by population, central case, lambda $100k ---\n")
s <- central[central$lambda_usd_per_qaly == 1e5,
  c("population", "h_per_year", "intercept_a_usd_per_course", "value_of_one_cure_b_usd")]
print(s, row.names = FALSE, digits = 6)

cat("\n--- Required cure fraction, allogeneic median benchmark, lambda $100k ---\n")
m <- req[req$benchmark_anchor == "Allogeneic median" & req$lambda_usd_per_qaly == 1e5, ]
m$pct <- round(100 * m$required_cure_fraction_all_treated, 1)
print(m[, c("population", "h_per_year", "pct", "achievable")], row.names = FALSE)
