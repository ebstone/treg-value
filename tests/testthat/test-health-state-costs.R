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
