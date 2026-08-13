source_r("transition_matrices.R")

RAW_DIR <- repo_root_relative("data", "raw")

test_that("Aliyev's raw transition rows do not all sum to exactly 1 (source rounding)", {
  df <- read.csv(file.path(RAW_DIR, "aliyev2019_maintenance_transitions.csv"), stringsAsFactors = FALSE)
  raw_sums <- rowSums(df[, c("to_moderate_severe", "to_moderate_severe_responder", "to_mild", "to_remission", "to_surgery", "to_death")])
  expect_true(any(abs(raw_sums - 1) > 1e-10))
})

test_that("renormalize_transition_matrix() corrects rows to sum to exactly 1", {
  raw <- matrix(c(0.5, 0.501, 0.3, 0.2), nrow = 2, byrow = TRUE)
  normalized <- renormalize_transition_matrix(raw)
  expect_equal(unname(rowSums(normalized)), c(1, 1), tolerance = 1e-12)
})

test_that("every loaded induction and maintenance matrix row (T7) sums to exactly 1", {
  for (tx in c("UST", "IFX", "ADA")) {
    m <- load_induction_matrix(tx, RAW_DIR)
    expect_equal(unname(rowSums(m)), rep(1, nrow(m)), tolerance = 1e-10, label = paste("induction", tx))
  }
  for (tx in c("UST", "IFX", "ADA", "CT")) {
    m <- load_maintenance_matrix(tx, RAW_DIR)
    defined <- !is.na(m[, 1])
    expect_equal(unname(rowSums(m[defined, , drop = FALSE])), rep(1, sum(defined)), tolerance = 1e-10, label = paste("maintenance", tx))
  }
})

test_that("biologic maintenance matrices have no from-Moderate-Severe row; CT does", {
  for (tx in c("UST", "IFX", "ADA")) {
    m <- load_maintenance_matrix(tx, RAW_DIR)
    expect_true(all(is.na(m["Moderate-Severe", ])), label = tx)
  }
  m_ct <- load_maintenance_matrix("CT", RAW_DIR)
  expect_false(any(is.na(m_ct["Moderate-Severe", ])))
})

test_that("trap 5: the maintenance Moderate-Severe row (CT) is not the induction Moderate-Severe row for the same therapy", {
  # The retired workbook's bug: the maintenance Moderate-Severe row got
  # populated with induction-phase values instead of Suppl. Table 4's own
  # (CT) figures. Assert they differ -- induction is a one-shot outcome
  # distribution over a 4-8 week window; maintenance is a steady-state
  # 2-week transition. They should not coincide.
  m_induction_ifx <- load_induction_matrix("IFX", RAW_DIR)
  m_maintenance_ct <- load_maintenance_matrix("CT", RAW_DIR)
  expect_false(isTRUE(all.equal(
    unname(m_induction_ifx["Moderate-Severe", ]),
    unname(m_maintenance_ct["Moderate-Severe", INDUCTION_STATES])
  )))
})
