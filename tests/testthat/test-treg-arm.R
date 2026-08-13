source_r("io_cache.R")
source_r("price_index.R")
source_derive("health_state_costs.R")
source_r("denominator.R")
source_r("transition_matrices.R")
source_r("life_table.R")
source_r("dosing.R")
source_r("costs_utilities.R")
source_r("refractory.R")
source_r("comparator_dosing.R")
source_r("markov_engine.R")
source_r("treg_arm.R")
source_r("frontier.R")
source_r("analog_comparison.R")

RAW_DIR <- repo_root_relative("data", "raw")

# Built once and shared: 66 comparator runs, ~10s. Every test below reuses it.
WINDOW <- 8
CAP_ON <- TRUE
LAMBDA <- 1e5
SC_GRID <- standard_care_grid(WINDOW, CAP_ON, RAW_DIR)
COMPARATOR <- run_comparator_trace("IFX", WINDOW, CAP_ON, 100 - MODEL_START_AGE_YEARS, RAW_DIR)

price_at <- function(pi_cure, h) {
  price_star_usd_per_course(pi_cure, h, LAMBDA, COMPARATOR, SC_GRID, WINDOW, CAP_ON, RAW_DIR)
}

test_that("T4: at pi_cure = 1 the share of the TREATED COHORT in drug-free remission at cycle 6 equals 1.00", {
  # Asserted against the trace, not against the parameter's declared
  # attribute -- the attribute records intent, the trace records what the
  # split actually did. This is the denominator defect's own test.
  trace <- run_treg_trace(1, 0.05, WINDOW, CAP_ON, SC_GRID, RAW_DIR)
  expect_equal(trace$cycle6_drug_free_remission_share, 1, tolerance = 1e-12)
})

test_that("the cure peels from the whole cohort, not from a subset: cycle-6 share tracks pi_cure exactly", {
  for (p in c(0, 0.25, 0.5, 0.75, 1)) {
    trace <- run_treg_trace(p, 0.05, WINDOW, CAP_ON, SC_GRID, RAW_DIR)
    expect_equal(trace$cycle6_drug_free_remission_share, p, tolerance = 1e-12, label = paste("pi =", p))
  }
})

test_that("pi_cure is declared on the all_treated denominator (guard 3)", {
  expect_identical(denominator_of(pi_cure), "all_treated")
})

test_that("T7: Treg-arm state vectors sum to 1.00 +/- 1e-10, every cycle, at every cure fraction", {
  for (p in c(0, 0.5, 1)) {
    for (h in c(0, 0.10)) {
      trace <- run_treg_trace(p, h, WINDOW, CAP_ON, SC_GRID, RAW_DIR)
      expect_equal(trace$state_sums, rep(1, length(trace$state_sums)),
        tolerance = 1e-10, label = sprintf("pi=%s h=%s", p, h))
    }
  }
})

test_that("T1: P*(0) equals independently computed A to within $1, whatever its sign", {
  a_model <- frontier_intercept_from_model(0.05, LAMBDA, COMPARATOR, SC_GRID, WINDOW, CAP_ON, RAW_DIR)
  a_independent <- frontier_intercept_independent(LAMBDA, COMPARATOR, SC_GRID, RAW_DIR)
  expect_lt(abs(a_model - a_independent), 1)
})

test_that("A does not depend on the relapse hazard: at pi_cure = 0 nobody is cured, so h cannot bite", {
  a_h0 <- frontier_intercept_from_model(0, LAMBDA, COMPARATOR, SC_GRID, WINDOW, CAP_ON, RAW_DIR)
  a_h10 <- frontier_intercept_from_model(0.10, LAMBDA, COMPARATOR, SC_GRID, WINDOW, CAP_ON, RAW_DIR)
  expect_lt(abs(a_h0 - a_h10), 1e-9)
})

test_that("T2: (P*(1) - P*(0)) equals B computed directly as the cured-vs-standard-care NMB difference, to within $1", {
  for (h in c(0, 0.05, 0.10)) {
    slope <- price_at(1, h) - price_at(0, h)
    b_direct <- value_of_one_cure_usd(h, LAMBDA, SC_GRID, RAW_DIR)
    expect_lt(abs(slope - b_direct), 1, label = paste("h =", h))
  }
})

test_that("T3: P*(pi) is linear across a 101-point grid, deviation under $0.01", {
  pis <- seq(0, 1, length.out = 101)
  h <- 0.05
  observed <- vapply(pis, function(p) price_at(p, h), numeric(1))
  intercept <- observed[1]
  slope <- observed[length(observed)] - intercept
  affine <- intercept + pis * slope
  expect_lt(max(abs(observed - affine)), 0.01)
})

test_that("T5: P* strictly decreasing in h, strictly increasing in lambda; B decreasing in h", {
  hs <- c(0, 0.05, 0.10)
  prices_by_h <- vapply(hs, function(h) price_at(0.5, h), numeric(1))
  expect_true(all(diff(prices_by_h) < 0))

  b_by_h <- vapply(hs, function(h) value_of_one_cure_usd(h, LAMBDA, SC_GRID, RAW_DIR), numeric(1))
  expect_true(all(diff(b_by_h) < 0))

  lambdas <- c(5e4, 1e5, 1.5e5)
  prices_by_lambda <- vapply(lambdas, function(l) {
    price_star_usd_per_course(0.5, 0.05, l, COMPARATOR, SC_GRID, WINDOW, CAP_ON, RAW_DIR)
  }, numeric(1))
  expect_true(all(diff(prices_by_lambda) > 0))
})

test_that("T11: the analog comparison decays pi_cure to each analog's own timepoint, never compares pi_cure itself", {
  pi_cure_value <- 0.4
  h <- 0.10

  # PolTREG reads out at 24 months, well after the 12-week landmark, so its
  # comparable share must be strictly below pi_cure -- never pi_cure itself.
  tbl <- analog_comparison_table(pi_cure_value, h)
  poltreg <- tbl[tbl$analog == "PolTREG PTG-007", ]
  expect_true(poltreg$comparable)
  expect_lt(poltreg$drug_free_remission_share, pi_cure_value)

  expected <- pi_cure_value * exp(-h * poltreg$years_from_landmark)
  expect_equal(poltreg$drug_free_remission_share, expected, tolerance = 1e-12)

  # At zero hazard the share is flat, and only then equals pi_cure.
  flat <- analog_comparison_table(pi_cure_value, 0)
  expect_equal(flat$drug_free_remission_share[flat$analog == "PolTREG PTG-007"], pi_cure_value, tolerance = 1e-12)
})

test_that("T11: an analog reading out before the landmark is marked incomparable rather than back-extrapolated", {
  tbl <- analog_comparison_table(0.4, 0.10)
  ovasave <- tbl[tbl$analog == "Ovasave/CATS1", ]
  expect_false(ovasave$comparable)
  expect_true(is.na(ovasave$drug_free_remission_share))
})

test_that("T12: no pricing function reads a manufacturing benchmark -- zero call sites", {
  pricing_files <- c(
    repo_root_relative("R", "frontier.R"),
    repo_root_relative("R", "treg_arm.R")
  )
  benchmark_pattern <- "manufactur|cogs|benchmark_cost|tenham"
  for (f in pricing_files) {
    code <- readLines(f, warn = FALSE)
    code <- code[!grepl("^\\s*#", code)] # comments may discuss it; code may not read it
    expect_false(any(grepl(benchmark_pattern, code, ignore.case = TRUE)), label = basename(f))
  }
})

test_that("required_cure_fraction() inverts the frontier on the all-treated denominator", {
  a <- price_at(0, 0.05)
  b <- price_at(1, 0.05) - a
  price <- 2e4
  pi_required <- required_cure_fraction(price, a, b)
  # Round-trip: pricing at the required fraction returns the price asked for.
  expect_lt(abs(price_at(pi_required, 0.05) - price), 0.01)
})
