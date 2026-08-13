source_r("io_cache.R")
source_r("life_table.R")

RAW_DIR <- repo_root_relative("data", "raw")

test_that("annual_qx_prob_1yr_to_prob_2wk() round-trips exactly against its own inverse", {
  p_annual <- 0.05
  p_2wk <- annual_qx_prob_1yr_to_prob_2wk(p_annual)
  implied_annual <- 1 - (1 - p_2wk)^ALIYEV_CYCLES_PER_YEAR
  expect_equal(implied_annual, p_annual, tolerance = 1e-12)
})

test_that("load_life_table() has one row per age 0-100 with a qx_prob_2wk column added", {
  lt <- load_life_table(RAW_DIR)
  expect_equal(nrow(lt), 101)
  expect_true("qx_prob_2wk" %in% names(lt))
  expect_true(all(lt$qx_prob_2wk >= 0 & lt$qx_prob_2wk <= 1))
})

test_that("background_mortality_prob_2wk() looks up the right age band and clamps above the table's max age", {
  lt <- load_life_table(RAW_DIR)
  expect_equal(background_mortality_prob_2wk(35, lt), lt$qx_prob_2wk[lt$age_years == 35])
  expect_equal(background_mortality_prob_2wk(35.9, lt), lt$qx_prob_2wk[lt$age_years == 35])
  expect_equal(background_mortality_prob_2wk(150, lt), lt$qx_prob_2wk[lt$age_years == 100])
})

test_that("T8: undiscounted life-years from the model's start age match the life-table expectation within 1 year", {
  source_r("io_cache.R")
  source_r("price_index.R")
  source_derive("health_state_costs.R")
  source_r("transition_matrices.R")
  source_r("dosing.R")
  source_r("costs_utilities.R")
  source_r("refractory.R")
source_r("comparator_dosing.R")
source_r("markov_engine.R")

  lt <- load_life_table(RAW_DIR)
  expected <- life_table_expectancy_years(MODEL_START_AGE_YEARS, lt)

  # A lifetime-length horizon, long enough the cohort is fully exhausted
  # well before the end (verified separately in test-markov-engine.R).
  result <- run_comparator_trace("IFX", 8, cap_on = TRUE, horizon_years = 90, raw_dir = RAW_DIR)

  expect_lt(abs(result$undiscounted_life_years - expected), 1)
})
