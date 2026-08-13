source_r("io_cache.R")
source_r("price_index.R")
source_r("denominator.R")
source_derive("health_state_costs.R")
source_r("transition_matrices.R")
source_r("life_table.R")
source_r("dosing.R")
source_r("costs_utilities.R")
source_r("refractory.R")
source_r("comparator_dosing.R")
source_r("markov_engine.R")
source_r("treg_arm.R")
source_r("frontier.R")
source_r("psa.R")

RAW_DIR <- repo_root_relative("data", "raw")

test_that("rdirichlet_row() returns a valid probability row", {
  set.seed(1)
  for (i in 1:20) {
    p <- rdirichlet_row(c(0.5, 0.2, 0.2, 0.1) * 90)
    expect_equal(sum(p), 1, tolerance = 1e-12)
    expect_true(all(p >= 0))
  }
})

test_that("transition rows sampled whole still sum to 1, and Death stays absorbing", {
  set.seed(2)
  df <- read.csv(file.path(RAW_DIR, "aliyev2019_maintenance_transitions.csv"), stringsAsFactors = FALSE)
  ct <- df[df$therapy == "CT", ]
  sampled <- sample_maintenance_transitions(ct, dirichlet_effective_n(RAW_DIR))
  cols <- c("to_moderate_severe", "to_moderate_severe_responder", "to_mild",
    "to_remission", "to_surgery", "to_death")
  expect_equal(unname(rowSums(sampled[, cols])), rep(1, nrow(sampled)), tolerance = 1e-10)
  death <- sampled[sampled$from_state == "Death", ]
  expect_equal(death$to_death, 1)
})

test_that("the effective sample size behind a Dirichlet draw comes from Aliyev's own Beta precision", {
  p <- read.csv(file.path(RAW_DIR, "aliyev2019_source_parameters.csv"), stringsAsFactors = FALSE)
  b <- p[grepl("Beta", p$distribution), ]
  expect_equal(dirichlet_effective_n(RAW_DIR), median(as.numeric(b$alpha) + as.numeric(b$beta)))
})

test_that("a PSA draw writes a complete, self-consistent raw directory", {
  set.seed(3)
  scratch <- file.path(tempdir(), "psa_test_draw")
  write_psa_draw(scratch, RAW_DIR)
  on.exit(unlink(scratch, recursive = TRUE), add = TRUE)
  clear_csv_cache()

  # Every file the base directory has, the draw has.
  expect_true(all(basename(list.files(RAW_DIR)) %in% basename(list.files(scratch))))

  # Utilities keep their ordering: a draw must not put Moderate-Severe above
  # Remission, which rescaling by a single factor guarantees.
  u <- health_state_utilities(scratch)
  expect_gt(u[["Remission"]], u[["Mild"]])
  expect_gt(u[["Mild"]], u[["Moderate-Severe Responder"]])
  expect_gt(u[["Moderate-Severe Responder"]], u[["Moderate-Severe"]])

  # Sampled costs stay positive and finite.
  costs <- health_state_costs_usd_per_cycle(scratch)
  expect_true(all(is.finite(costs)))
  expect_true(all(costs >= 0))
  clear_csv_cache()
})

test_that("the sampled comparator price stays inside the observed biosimilar range", {
  set.seed(4)
  scratch <- file.path(tempdir(), "psa_price_draw")
  asp_base <- read.csv(file.path(RAW_DIR, "cms_asp_infliximab_2026.csv"), stringsAsFactors = FALSE)
  biosimilars <- asp_base$usd_per_mg[grepl("^Q", asp_base$hcpcs_code)]
  on.exit(unlink(scratch, recursive = TRUE), add = TRUE)
  for (i in 1:5) {
    write_psa_draw(scratch, RAW_DIR)
    drawn <- read.csv(file.path(scratch, "cms_asp_infliximab_2026.csv"),
      stringsAsFactors = FALSE)$usd_per_mg[asp_base$hcpcs_code == IFX_PRICED_PRODUCT]
    expect_gte(drawn, min(biosimilars))
    expect_lte(drawn, max(biosimilars))
  }
  clear_csv_cache()
})

test_that("run_psa() returns every requested combination per draw, with B decreasing in h within a draw", {
  hs <- c(0, 0.05, 0.10)
  lams <- c(5e4, 1e5)
  draws <- run_psa(2, hs, lams, 8, TRUE, RAW_DIR, age_step_years = 15, seed = 5)
  expect_equal(nrow(draws), 2 * length(hs) * length(lams))
  expect_true(all(is.finite(draws$intercept_a_usd_per_course)))
  expect_true(all(is.finite(draws$value_of_one_cure_b_usd)))

  # T5's monotonicity must hold inside every individual draw, not merely on
  # average across them.
  for (d in unique(draws$draw)) {
    for (l in lams) {
      b <- draws$value_of_one_cure_b_usd[draws$draw == d & draws$lambda_usd_per_qaly == l]
      expect_true(all(diff(b) < 0), label = sprintf("draw %s lambda %s", d, l))
    }
  }

  # A does not depend on h -- nobody is cured at pi_cure = 0.
  for (d in unique(draws$draw)) {
    a <- draws$intercept_a_usd_per_course[draws$draw == d & draws$lambda_usd_per_qaly == lams[1]]
    expect_equal(length(unique(round(a, 9))), 1)
  }
  clear_csv_cache()
})
