# W5: the manufacturing cost benchmark (SPEC.md section 8), and the
# required cure fraction it implies (aim A3).
#
# Run from the repository root.
#
# L8: the benchmark never enters the frontier. This script reads an
# already-computed frontier and holds the benchmark up against it. The
# causal direction is one-way and T12 asserts it.

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
source("R/manufacturing_benchmark.R")
source("R/stamp.R")

HAZARDS_PER_YEAR <- c(0, 0.05, 0.10)
LAMBDAS_USD_PER_QALY <- c(5e4, 1e5, 1.5e5)
WINDOW_WEEKS <- 8
CAP_ON <- TRUE

anchors <- tenham_analogy_anchors()
bench <- manufacturing_benchmark_usd_per_course()

benchmark_table <- data.frame(
  anchor = c("Allogeneic, batch-amortised (low)", "Allogeneic median",
    "Allogeneic, single-treatment batch (high)", "Autologous CAR-T cost of goods (upper)"),
  basis = c("ten Ham case 8, 22 treatments per batch", "ten Ham allogeneic cases",
    "ten Ham allogeneic cases", "reported per-dose COGS, autologous"),
  cost_usd_per_course = c(bench$low_usd, bench$allogeneic_median_usd,
    bench$allogeneic_high_usd, bench$high_usd),
  stringsAsFactors = FALSE
)

# --- Aim A3: required cure fraction at each benchmark --------------------
grid <- standard_care_grid(WINDOW_WEEKS, CAP_ON)
comparator <- run_comparator_trace("IFX", WINDOW_WEEKS, CAP_ON, 100 - MODEL_START_AGE_YEARS)

rows <- list()
for (lambda in LAMBDAS_USD_PER_QALY) {
  a <- frontier_intercept_from_model(0, lambda, comparator, grid, WINDOW_WEEKS, CAP_ON)
  for (h in HAZARDS_PER_YEAR) {
    b <- value_of_one_cure_usd(h, lambda, grid)
    for (k in seq_len(nrow(benchmark_table))) {
      price <- benchmark_table$cost_usd_per_course[k]
      pi_req <- required_cure_fraction(price, a, b)
      rows[[length(rows) + 1]] <- data.frame(
        benchmark_anchor = benchmark_table$anchor[k],
        benchmark_cost_usd_per_course = price,
        lambda_usd_per_qaly = lambda,
        h_per_year = h,
        intercept_a_usd_per_course = a,
        value_of_one_cure_b_usd = b,
        required_cure_fraction_all_treated = pi_req,
        achievable = pi_req <= 1,
        stringsAsFactors = FALSE
      )
    }
  }
}
required <- do.call(rbind, rows)

# SPEC.md section 7: A3 reports the analog comparison on matched timepoints,
# never on pi_cure itself. Evaluated at the required cure fraction implied by
# the allogeneic median benchmark.
central <- required[required$benchmark_anchor == "Allogeneic median" &
  required$lambda_usd_per_qaly == 1e5, ]
analogs <- do.call(rbind, lapply(seq_len(nrow(central)), function(i) {
  t <- analog_comparison_table(central$required_cure_fraction_all_treated[i], central$h_per_year[i])
  t$h_per_year <- central$h_per_year[i]
  t$required_cure_fraction_at_landmark <- central$required_cure_fraction_all_treated[i]
  t
}))

stamp_output(benchmark_table, "output/tables/manufacturing_benchmark.csv")
stamp_output(anchors, "output/tables/manufacturing_anchors.csv")
stamp_output(required, "output/tables/required_cure_fraction.csv")
stamp_output(analogs, "output/tables/required_cure_fraction_analogs.csv")

cat("\n--- Manufacturing benchmark, 2025 USD per course ---\n")
print(benchmark_table, row.names = FALSE)
cat("\n--- Required cure fraction (all-treated), lambda $100k ---\n")
show <- required[required$lambda_usd_per_qaly == 1e5,
  c("benchmark_anchor", "h_per_year", "required_cure_fraction_all_treated", "achievable")]
show$required_cure_fraction_all_treated <- round(100 * show$required_cure_fraction_all_treated, 1)
print(show, row.names = FALSE)
