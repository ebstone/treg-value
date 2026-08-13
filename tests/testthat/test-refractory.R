source_r("io_cache.R")
source_r("price_index.R")
source_r("denominator.R")
source_derive("health_state_costs.R")
source_r("transition_matrices.R")
source_r("refractory.R")
source_r("life_table.R")
source_r("dosing.R")
source_r("costs_utilities.R")
source_r("markov_engine.R")

RAW_DIR <- repo_root_relative("data", "raw")

test_that("multipliers are computed from the trials' own counts, not stored pre-divided", {
  d <- read.csv(file.path(RAW_DIR, "uniti_induction_outcomes.csv"), stringsAsFactors = FALSE)
  arm <- d[d$arm == REFRACTORY_ACTIVE_ARM, ]
  r <- arm[arm$trial == "UNITI-1", ]
  c2 <- arm[arm$trial == "UNITI-2", ]
  m <- refractory_multipliers(REFRACTORY_ACTIVE_ARM, RAW_DIR)
  expect_equal(m$response,
    (r$n_clinical_response_week6 / r$n_randomised) / (c2$n_clinical_response_week6 / c2$n_randomised))
  expect_equal(m$remission,
    (r$n_clinical_remission_week8 / r$n_randomised) / (c2$n_clinical_remission_week8 / c2$n_randomised))
})

test_that("a refractory population does strictly worse on both endpoints", {
  for (arm in c(REFRACTORY_ACTIVE_ARM, REFRACTORY_PLACEBO_ARM)) {
    m <- refractory_multipliers(arm, RAW_DIR)
    expect_lt(m$response, 1)
    expect_lt(m$remission, 1)
    expect_gt(m$response, 0)
    expect_gt(m$remission, 0)
  }
})

test_that("the base case this repo inherited is UNITI-2: Aliyev's Beta parameters are that arm's raw counts", {
  # Aliyev's UST week-6 response carries Beta(116, 93). UNITI-2's ~6 mg/kg
  # arm reports 116 responders of 209, leaving 93 non-responders. This is a
  # provenance check on the whole naive/refractory split, not a coincidence
  # worth leaving unasserted.
  d <- read.csv(file.path(RAW_DIR, "uniti_induction_outcomes.csv"), stringsAsFactors = FALSE)
  u2 <- d[d$trial == "UNITI-2" & d$arm == REFRACTORY_ACTIVE_ARM, ]
  params <- read.csv(file.path(RAW_DIR, "aliyev2019_source_parameters.csv"), stringsAsFactors = FALSE)
  row <- params[params$parameter == "UST Week 6 Response Probability", ]
  expect_equal(as.numeric(row$alpha), u2$n_clinical_response_week6)
  expect_equal(as.numeric(row$beta), u2$n_randomised - u2$n_clinical_response_week6)
})

test_that("refractory induction rows remain valid probability rows (T7 precondition)", {
  for (tx in c("UST", "IFX", "ADA")) {
    m <- load_induction_matrix_for_population(tx, "refractory", RAW_DIR)
    expect_equal(unname(rowSums(m)), rep(1, nrow(m)), tolerance = 1e-10, label = tx)
    expect_true(all(m >= 0), label = tx)
  }
})

test_that("refractory shifts mass toward Moderate-Severe and away from Remission", {
  naive <- load_induction_matrix_for_population("IFX", "naive", RAW_DIR)
  refr <- load_induction_matrix_for_population("IFX", "refractory", RAW_DIR)
  expect_gt(refr["Moderate-Severe", "Moderate-Severe"], naive["Moderate-Severe", "Moderate-Severe"])
  expect_lt(refr["Moderate-Severe", "Remission"], naive["Moderate-Severe", "Remission"])
  # Aliyev's 50/50 responder split (Induction assumption #7) survives.
  expect_equal(refr["Moderate-Severe", "Mild"], refr["Moderate-Severe", "Moderate-Severe Responder"])
})

test_that("population = 'naive' returns Aliyev's matrix untouched", {
  expect_identical(
    load_induction_matrix_for_population("IFX", "naive", RAW_DIR),
    load_induction_matrix("IFX", RAW_DIR)
  )
})

test_that("T7 holds in a refractory comparator trace, every cycle", {
  tr <- run_comparator_trace("IFX", 8, TRUE, 30, RAW_DIR, population = "refractory")
  expect_equal(tr$state_sums, rep(1, length(tr$state_sums)), tolerance = 1e-10)
})

test_that("a refractory cohort accrues fewer QALYs than a naive one, all else equal", {
  naive <- run_comparator_trace("IFX", 8, TRUE, 30, RAW_DIR, population = "naive")
  refr <- run_comparator_trace("IFX", 8, TRUE, 30, RAW_DIR, population = "refractory")
  expect_lt(refr$discounted_qaly, naive$discounted_qaly)
})
