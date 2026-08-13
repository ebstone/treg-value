source_r("io_cache.R")
source_r("price_index.R")
source_r("denominator.R")
source_derive("health_state_costs.R")
source_r("transition_matrices.R")
source_r("refractory.R")
source_r("life_table.R")
source_r("dosing.R")
source_r("comparator_dosing.R")
source_r("costs_utilities.R")
source_r("markov_engine.R")

RAW_DIR <- repo_root_relative("data", "raw")

test_that("every therapy's dosing schedule sits inside its own induction window (trap 3)", {
  for (spec in list(list("IFX", 4), list("IFX", 8), list("UST", NULL), list("ADA", NULL))) {
    p <- dosing_plan(spec[[1]], spec[[2]], RAW_DIR)
    expect_true(all(p$induction_dose_cycles <= p$induction_cycles),
      label = sprintf("%s window %s", spec[[1]], p$induction_window_weeks))
    expect_equal(length(p$induction_dose_costs), length(p$induction_dose_cycles))
  }
})

test_that("secondary comparators use their own label windows, not infliximab's", {
  expect_equal(dosing_plan("UST", NULL, RAW_DIR)$induction_window_weeks, 6)
  expect_equal(dosing_plan("ADA", NULL, RAW_DIR)$induction_window_weeks, 4)
})

test_that("adalimumab's induction doses differ in size, ustekinumab's is a single dose", {
  ada <- dosing_plan("ADA", NULL, RAW_DIR)
  # 160 mg on day 1 is four syringes, 80 mg on day 15 is two: the first dose
  # must cost exactly twice the second.
  expect_equal(length(ada$induction_dose_costs), 2)
  expect_equal(ada$induction_dose_costs[1], 2 * ada$induction_dose_costs[2], tolerance = 1e-9)

  ust <- dosing_plan("UST", NULL, RAW_DIR)
  expect_equal(length(ust$induction_dose_costs), 1)
})

test_that("intravenous administration carries an infusion fee and subcutaneous does not", {
  # Ustekinumab: IV induction, SC maintenance. The induction dose must carry
  # the infusion fee its maintenance dose does not.
  reg <- comparator_regimen("UST", RAW_DIR)
  expect_equal(reg$induction_route, "intravenous")
  expect_equal(reg$maintenance_route, "subcutaneous")
  ind <- comparator_dose_cost_usd("UST", "induction", RAW_DIR)
  drug_only <- comparator_unit_cost_usd(reg$induction_unit_cost_item, RAW_DIR) * reg$induction_units
  expect_equal(ind - drug_only, ifx_administration_cost_usd_per_dose(RAW_DIR), tolerance = 1e-9)

  # Adalimumab is subcutaneous throughout, so no infusion fee anywhere.
  ada_reg <- comparator_regimen("ADA", RAW_DIR)
  ada_drug <- comparator_unit_cost_usd(ada_reg$maintenance_unit_cost_item, RAW_DIR) * ada_reg$maintenance_units
  expect_equal(comparator_dose_cost_usd("ADA", "maintenance", RAW_DIR), ada_drug, tolerance = 1e-9)
})

test_that("S4: the originator prices strictly above the biosimilar", {
  expect_gt(ifx_infusion_cost_usd_per_dose(RAW_DIR, product = "J1745"),
    ifx_infusion_cost_usd_per_dose(RAW_DIR, product = "Q5104"))
})

test_that("S7: the pre-pandemic vintage gives longer life expectancy, and the model reproduces it", {
  base <- load_life_table(RAW_DIR, "base")
  pre <- load_life_table(RAW_DIR, "pre_pandemic")
  expect_equal(nrow(pre), 101)
  expect_equal(pre$qx_prob_1yr[pre$age_years == 100], 1) # terminal row present and absorbing
  expect_gt(life_table_expectancy_years(MODEL_START_AGE_YEARS, pre),
    life_table_expectancy_years(MODEL_START_AGE_YEARS, base))

  # T8 must hold against whichever vintage is in use, not only the base one.
  tr <- run_comparator_trace("IFX", 8, TRUE, 100 - MODEL_START_AGE_YEARS, RAW_DIR,
    life_table_vintage = "pre_pandemic")
  expect_lt(abs(tr$undiscounted_life_years -
    life_table_expectancy_years(MODEL_START_AGE_YEARS, pre)), 1)
})

test_that("T7 holds for every scenario comparator arm", {
  for (spec in list(list("IFX", 8, "Q5104", "base"), list("IFX", 8, "J1745", "base"),
                    list("UST", NULL, "Q5104", "base"), list("ADA", NULL, "Q5104", "base"),
                    list("IFX", 8, "Q5104", "pre_pandemic"))) {
    tr <- run_comparator_trace(spec[[1]], spec[[2]], TRUE, 30, RAW_DIR,
      product = spec[[3]], life_table_vintage = spec[[4]])
    expect_equal(tr$state_sums, rep(1, length(tr$state_sums)), tolerance = 1e-10,
      label = paste(spec[[1]], spec[[3]], spec[[4]]))
  }
})
