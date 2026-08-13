# SPEC.md section 5 scenarios. Run from the repository root.
#
#   S1  induction window, week 4 vs week 8  -- a bounding pair on every
#       primary output, not run here
#   S2  refractory population               -- analysis/run_refractory_coprimary.R
#   S3  redosing on post-cure relapse       -- not built, see SPEC_AMENDMENTS.md
#   S4  originator infliximab pricing       -- here
#   S5  ustekinumab / adalimumab as reference comparator -- here
#   S6  administration bundle               -- blocked on O3 and O4
#   S7  pre-pandemic life-table vintage     -- here

source("R/io_cache.R")
source("R/price_index.R")
source("R/denominator.R")
source("derive/health_state_costs.R")
source("R/transition_matrices.R")
source("R/refractory.R")
source("R/life_table.R")
source("R/dosing.R")
source("R/comparator_dosing.R")
source("R/costs_utilities.R")
source("R/markov_engine.R")
source("R/treg_arm.R")
source("R/frontier.R")
source("R/manufacturing_benchmark.R")
source("R/stamp.R")

HAZARDS_PER_YEAR <- c(0, 0.05, 0.10)
LAMBDAS_USD_PER_QALY <- c(5e4, 1e5, 1.5e5)
CAP_ON <- TRUE

# Each scenario is one deviation from the base case, named and otherwise
# identical, so a difference is attributable to the deviation alone.
SCENARIOS <- list(
  list(id = "base", label = "Base case (IFX biosimilar, 2023 life table)",
       therapy = "IFX", window = 8, product = "Q5104", vintage = "base"),
  list(id = "S4", label = "S4: originator infliximab pricing",
       therapy = "IFX", window = 8, product = "J1745", vintage = "base"),
  list(id = "S5-UST", label = "S5: ustekinumab as reference comparator",
       therapy = "UST", window = NULL, product = "Q5104", vintage = "base"),
  list(id = "S5-ADA", label = "S5: adalimumab as reference comparator",
       therapy = "ADA", window = NULL, product = "Q5104", vintage = "base"),
  list(id = "S7", label = "S7: pre-pandemic (2019) life table",
       therapy = "IFX", window = 8, product = "Q5104", vintage = "pre_pandemic"),
  # CHEERS 2022 item 24 asks for the effect of the choice of discount rate.
  # SPEC.md section 2 fixes 3%; 0% and 5% bracket conventional practice.
  list(id = "disc-0", label = "Discount rate 0% (CHEERS item 24)",
       therapy = "IFX", window = 8, product = "Q5104", vintage = "base", discount = 0),
  list(id = "disc-5", label = "Discount rate 5% (CHEERS item 24)",
       therapy = "IFX", window = 8, product = "Q5104", vintage = "base", discount = 0.05)
)

bench <- manufacturing_benchmark_usd_per_course()
rows <- list()

for (sc in SCENARIOS) {
  if (!is.null(sc$discount)) {
    old <- getOption("treg_value.discount_rate")
    options(treg_value.discount_rate = sc$discount)
    on.exit(options(treg_value.discount_rate = old), add = TRUE)
  }
  grid <- standard_care_grid(sc$window, CAP_ON, product = sc$product,
    life_table_vintage = sc$vintage, therapy = sc$therapy)
  comparator <- run_comparator_trace(sc$therapy, sc$window, CAP_ON,
    100 - MODEL_START_AGE_YEARS, product = sc$product, life_table_vintage = sc$vintage)
  for (lambda in LAMBDAS_USD_PER_QALY) {
    a <- frontier_intercept_from_model(0, lambda, comparator, grid, sc$window, CAP_ON)
    for (h in HAZARDS_PER_YEAR) {
      b <- value_of_one_cure_usd(h, lambda, grid)
      rows[[length(rows) + 1]] <- data.frame(
        scenario = sc$id, label = sc$label, comparator_therapy = sc$therapy,
        lambda_usd_per_qaly = lambda, h_per_year = h,
        comparator_discounted_cost_usd = comparator$discounted_cost_usd,
        comparator_discounted_qaly = comparator$discounted_qaly,
        intercept_a_usd_per_course = a,
        value_of_one_cure_b_usd = b,
        required_cure_fraction_at_median_benchmark =
          required_cure_fraction(bench$allogeneic_median_usd, a, b),
        stringsAsFactors = FALSE)
    }
  }
  if (!is.null(sc$discount)) options(treg_value.discount_rate = NULL)
}
scenarios <- do.call(rbind, rows)
stamp_output(scenarios, "output/tables/scenarios.csv")

cat("\n--- Comparator arm by scenario (lifetime, discounted) ---\n")
u <- unique(scenarios[, c("scenario", "label", "comparator_discounted_cost_usd", "comparator_discounted_qaly")])
u$comparator_discounted_cost_usd <- round(u$comparator_discounted_cost_usd)
u$comparator_discounted_qaly <- round(u$comparator_discounted_qaly, 4)
print(u[, c("scenario", "comparator_discounted_cost_usd", "comparator_discounted_qaly")], row.names = FALSE)

cat("\n--- B and required cure fraction at median benchmark, lambda $100k, h 5% ---\n")
s <- scenarios[scenarios$lambda_usd_per_qaly == 1e5 & scenarios$h_per_year == 0.05, ]
s$B <- round(s$value_of_one_cure_b_usd)
s$required_pct <- round(100 * s$required_cure_fraction_at_median_benchmark, 1)
s$A <- round(s$intercept_a_usd_per_course)
print(s[, c("scenario", "A", "B", "required_pct")], row.names = FALSE)
