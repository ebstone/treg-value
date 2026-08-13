# Health-state costs in 2-week-cycle, 2017 USD -- the units this repo's
# Markov engine will consume.
#
# For Mild, Remission and Surgery, Aliyev's Suppl. Table 2 PMPM (2008 USD)
# figure converts to Suppl. Table 5's adopted per-cycle (2017 USD) figure via
# a single rule with no free parameters: PMPM -> 2-week cycle (14/30.44)
# times the 2008 -> 2017 cost trend (1.03^9). Validated in
# tests/testthat/test-health-state-costs.R, within $1 for all three.
#
# For Moderate-Severe (and Moderate-Severe Responder, which Suppl. Table 2
# does not even list a PMPM figure for), that rule does NOT reconcile --
# OPEN_QUESTIONS.md C8: Table 2's $374 PMPM converts to $224.43, not Table
# 5's adopted $217. Per Eric Stone's direction (2026-08-12), those two
# states use Suppl. Table 5's adopted per-cycle figure directly instead --
# replicating what Aliyev's model actually used takes priority over a
# reconciliation rule that appendix does not itself follow for this state.

PMPM_2008_USD_TO_CYCLE_2017_USD_FACTOR <- (14 / 30.44) * (1.03^9)

#' Convert a PMPM, 2008 USD health-state cost to a 2-week-cycle, 2017 USD
#' figure, via the single conversion rule above.
pmpm_2008_usd_to_cycle_2017_usd <- function(pmpm_2008_usd) {
  pmpm_2008_usd * PMPM_2008_USD_TO_CYCLE_2017_USD_FACTOR
}

#' Read a PMPM "Mean Total Cost" figure for a health state out of
#' data/raw/aliyev2019_source_parameters.csv's `parameter` column (which
#' carries the state name, e.g. "Mild-Moderate CD-related PMPM Mean Total
#' Cost, 2008 USD"), given a substring that identifies it uniquely.
aliyev_pmpm_2008_usd <- function(state_match, raw_dir = "data/raw") {
  params <- read_csv_cached(file.path(raw_dir, "aliyev2019_source_parameters.csv"))
  row <- params[grepl(state_match, params$parameter, fixed = TRUE) &
    grepl("Mean Total Cost", params$parameter, fixed = TRUE), ]
  stopifnot(nrow(row) == 1)
  as.numeric(gsub("[$,]", "", row$base_case_value))
}

#' Read an adopted per-cycle, 2017 USD figure for a health state out of
#' data/raw/aliyev2019_base_case_costs_utilities.csv's "Direct Cost per
#' Cycle (2017 USD)" category, by exact item name.
aliyev_adopted_cycle_2017_usd <- function(item, raw_dir = "data/raw") {
  adopted <- read_csv_cached(file.path(raw_dir, "aliyev2019_base_case_costs_utilities.csv"))
  row <- adopted[adopted$category == "Direct Cost per Cycle (2017 USD)" & adopted$item == item, ]
  stopifnot(nrow(row) == 1)
  as.numeric(row$value)
}

#' Health-state cost per 2-week cycle, 2017 USD, for every state in Aliyev's
#' maintenance Markov, read from data/raw/ (not re-hardcoded). `source`
#' records whether the figure is derived from Suppl. Table 2's PMPM via the
#' rule above, or adopted directly from Suppl. Table 5 (OPEN_QUESTIONS.md C8).
health_state_cost_cycle_2017_usd <- function(raw_dir = "data/raw") {
  data.frame(
    state = c("Moderate-Severe", "Moderate-Severe Responder", "Mild", "Remission", "Surgery"),
    cost_usd_per_cycle = c(
      aliyev_adopted_cycle_2017_usd("Moderate-Severe", raw_dir),
      aliyev_adopted_cycle_2017_usd("Moderate-Severe Responder", raw_dir),
      pmpm_2008_usd_to_cycle_2017_usd(aliyev_pmpm_2008_usd("Mild-Moderate", raw_dir)),
      pmpm_2008_usd_to_cycle_2017_usd(aliyev_pmpm_2008_usd("Remission", raw_dir)),
      pmpm_2008_usd_to_cycle_2017_usd(aliyev_pmpm_2008_usd("Severe-Fulminant", raw_dir))
    ),
    source = c("adopted_directly", "adopted_directly", "derived_from_pmpm", "derived_from_pmpm", "derived_from_pmpm"),
    stringsAsFactors = FALSE
  )
}
