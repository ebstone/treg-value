source_r("io_cache.R")
source_r("price_index.R")
source_derive("health_state_costs.R")

test_that("provenance re-derivation: PMPM-to-cycle rule reproduces Aliyev's published per-cycle figures", {
  # Inputs: Aliyev 2019 Appendix S2, Supplementary Table 2 ("Direct Cost", PMPM
  # 2008 USD), read from data/raw/aliyev2019_source_parameters.csv (not
  # re-hardcoded here -- one source of truth).
  # Targets: the same paper's Supplementary Table 5, "Direct Costs" panel
  # (page 11), read from data/raw/aliyev2019_base_case_costs_utilities.csv.
  #
  # This is the one permitted value-snapshot comparison under guard 4: it is
  # a provenance re-derivation (does the stated rule reproduce the source's
  # own stated result?), not a pinned expectation about this repo's own
  # code. Moderate-Severe is excluded here -- it does not reconcile via this
  # rule (OPEN_QUESTIONS.md C8) and is covered by the adopted-directly test
  # below instead.
  raw_dir <- repo_root_relative("data", "raw")
  states <- c("Mild-Moderate", "Remission", "Severe-Fulminant")
  published_items <- c("Mild", "Remission", "Surgery")

  for (i in seq_along(states)) {
    pmpm <- aliyev_pmpm_2008_usd(states[i], raw_dir)
    published <- aliyev_adopted_cycle_2017_usd(published_items[i], raw_dir)
    derived <- pmpm_2008_usd_to_cycle_2017_usd(pmpm)
    expect_lt(
      abs(derived - published), 2,
      label = sprintf("%s: rule gives %.2f from PMPM %d, published figure is %d", states[i], derived, pmpm, published)
    )
  }
})

test_that("provenance re-derivation: C8's gap closes under the rule Appendix S2 states for Moderate-Severe", {
  # OPEN_QUESTIONS.md C8a. The plain PMPM rule leaves a $7.40 gap on this one
  # state, which C8 recorded without a cause. Appendix S2 page 3 ("Health State
  # Cost Calculations") gives the cause: Moderate-Severe is built as its own
  # PMPM mean TOTAL cost, minus its own mean PHARMACY cost, plus the
  # Mild-moderate mean PHARMACY cost -- then converted like every other state.
  #
  # Permitted value-snapshot under guard 4 on the same footing as the test
  # above: it asks whether the source's own stated rule reproduces the source's
  # own published figure. Every input is read from data/raw/, not restated here.
  raw_dir <- repo_root_relative("data", "raw")
  params <- read_csv_cached(file.path(raw_dir, "aliyev2019_source_parameters.csv"))

  pharmacy_pmpm <- function(state_match) {
    row <- params[grepl(state_match, params$parameter, fixed = TRUE) &
      grepl("Mean Pharmacy Cost", params$parameter, fixed = TRUE), ]
    expect_equal(nrow(row), 1)
    as.numeric(gsub("[$,]", "", row$base_case_value))
  }

  ms_total <- aliyev_pmpm_2008_usd("Moderate-Severe", raw_dir)
  combined <- ms_total - pharmacy_pmpm("Moderate-Severe") + pharmacy_pmpm("Mild-Moderate")
  derived <- pmpm_2008_usd_to_cycle_2017_usd(combined)
  published <- aliyev_adopted_cycle_2017_usd("Moderate-Severe", raw_dir)

  # The plain rule is the wrong rule here and must remain visibly worse, or
  # this test would pass for the wrong reason.
  plain <- pmpm_2008_usd_to_cycle_2017_usd(ms_total)
  expect_true(abs(derived - published) < abs(plain - published))
  expect_lt(
    abs(derived - published), 1,
    label = sprintf("appendix rule gives %.2f, published figure is %d", derived, published)
  )
})

test_that("health_state_cost_cycle_2017_usd() covers all five maintenance states with the right source per state", {
  raw_dir <- repo_root_relative("data", "raw")
  costs <- health_state_cost_cycle_2017_usd(raw_dir)

  expect_setequal(costs$state, c("Moderate-Severe", "Moderate-Severe Responder", "Mild", "Remission", "Surgery"))

  by_state <- setNames(costs$cost_usd_per_cycle, costs$state)
  by_source <- setNames(costs$source, costs$state)

  # Moderate-Severe / Moderate-Severe Responder: adopted directly from Suppl.
  # Table 5 (OPEN_QUESTIONS.md C8), not re-derived from PMPM.
  expect_equal(by_state[["Moderate-Severe"]], aliyev_adopted_cycle_2017_usd("Moderate-Severe", raw_dir))
  expect_equal(by_state[["Moderate-Severe Responder"]], aliyev_adopted_cycle_2017_usd("Moderate-Severe Responder", raw_dir))
  expect_equal(by_source[["Moderate-Severe"]], "adopted_directly")
  expect_equal(by_source[["Moderate-Severe Responder"]], "adopted_directly")

  # Mild, Remission, Surgery: derived from PMPM, matching Suppl. Table 5
  # within $2.
  for (state in c("Mild", "Remission", "Surgery")) {
    expect_lt(abs(by_state[[state]] - aliyev_adopted_cycle_2017_usd(state, raw_dir)), 2)
  }
  expect_true(all(by_source[c("Mild", "Remission", "Surgery")] == "derived_from_pmpm"))
})
