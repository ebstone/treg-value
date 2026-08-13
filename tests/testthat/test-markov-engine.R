source_derive("health_state_costs.R")
source_r("transition_matrices.R")
source_r("life_table.R")
source_r("dosing.R")
source_r("costs_utilities.R")
source_r("markov_engine.R")

RAW_DIR <- repo_root_relative("data", "raw")

test_that("discount factor at an arbitrary late cycle equals 1.03^(-years) computed independently", {
  years <- 17.4 # an arbitrary, non-round figure
  expect_equal(discount_factor_years_to_discount_factor(years), 1.03^(-years), tolerance = 1e-12)
})

test_that("apply_background_mortality_to_row() preserves row sum and sets the requested Death probability", {
  row <- c(Remission = 0.9, Mild = 0.05, `Moderate-Severe Responder` = 0.02, `Moderate-Severe` = 0.01, Surgery = 0.01, Death = 0.01)
  adjusted <- apply_background_mortality_to_row(row, 0.05)
  expect_equal(unname(sum(adjusted)), 1, tolerance = 1e-12)
  expect_equal(unname(adjusted[["Death"]]), 0.05)
  # relative proportions among survivors preserved
  expect_equal(unname(adjusted[["Mild"]] / adjusted[["Remission"]]), unname(row[["Mild"]] / row[["Remission"]]), tolerance = 1e-10)
})

test_that("half-cycle correction increases cumulative cost and QALYs relative to end-of-cycle-only accounting, for a declining cohort", {
  # A toy two-state (Remission, Death) cohort losing 10% per cycle.
  v0 <- c(Remission = 1, Death = 0)
  v1 <- c(Remission = 0.9, Death = 0.1)
  utility <- c(Remission = 1, Death = 0)
  naive <- sum(v1 * utility) # end-of-cycle only
  corrected <- sum(half_cycle_weighted_occupancy(v0, v1) * utility)
  expect_gt(corrected, naive)
})

test_that("T7: state vectors sum to 1.00 +/- 1e-10 every cycle, both cap settings, week4 and week8", {
  for (cap_on in c(TRUE, FALSE)) {
    for (window in c(4, 8)) {
      result <- run_comparator_trace("IFX", window, cap_on, horizon_years = 5, raw_dir = RAW_DIR)
      expect_equal(result$state_sums, rep(1, length(result$state_sums)), tolerance = 1e-10, label = sprintf("cap=%s window=%s", cap_on, window))
    }
  }
})

test_that("cohort is fully exhausted (all mass in Death) at the terminal cycle of a long horizon", {
  result <- run_comparator_trace("IFX", 8, cap_on = TRUE, horizon_years = 90, raw_dir = RAW_DIR)
  total_death <- result$final_on_biologic[["Death"]] + result$final_on_ct[["Death"]]
  expect_equal(total_death, 1, tolerance = 1e-6)
})

test_that("trap 2: number of maintenance dose cycles charged equals the dosing schedule's own count, both cap settings", {
  capped <- run_comparator_trace("IFX", 8, cap_on = TRUE, horizon_years = 10, raw_dir = RAW_DIR)
  expect_equal(capped$dose_cycles_charged, length(ifx_maintenance_dose_cycles(2 * ALIYEV_CYCLES_PER_YEAR)))
  expect_equal(capped$dose_cycles_charged, 13) # 4, 8, ..., 52

  uncapped <- run_comparator_trace("IFX", 8, cap_on = FALSE, horizon_years = 10, raw_dir = RAW_DIR)
  expect_equal(uncapped$dose_cycles_charged, length(ifx_maintenance_dose_cycles(10 * ALIYEV_CYCLES_PER_YEAR)))
  expect_true(uncapped$dose_cycles_charged > capped$dose_cycles_charged)
})

test_that("trap 3: induction dosing schedule never has a dose outside its own window", {
  for (window in c(4, 8)) {
    doses <- ifx_induction_dose_weeks(window)
    expect_true(all(doses < window))
  }
  expect_length(ifx_induction_dose_weeks(4), 2)
  expect_length(ifx_induction_dose_weeks(8), 3)
})

test_that("trap 1: induction accrues nonzero cost and QALYs (not a free window)", {
  short_horizon <- run_comparator_trace("IFX", 4, cap_on = TRUE, horizon_years = 1 / ALIYEV_CYCLES_PER_YEAR * 2, raw_dir = RAW_DIR)
  # a near-zero maintenance horizon still carries the full induction accrual
  expect_gt(short_horizon$discounted_cost_usd, 0)
  expect_gt(short_horizon$discounted_qaly, 0)
})

test_that("trap 6: no colectomy-scale cost anywhere -- Surgery per-cycle cost is Aliyev's PMPM-derived figure, not an episode cost", {
  costs <- health_state_costs_usd_per_cycle(RAW_DIR)
  # A colectomy episode cost (the retired workbook's mistake) is on the
  # order of tens of thousands of dollars; Aliyev's per-cycle figure is
  # under $1,000.
  expect_lt(costs[["Surgery"]], 999)
})
