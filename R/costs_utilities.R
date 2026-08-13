# Per-cycle health-state cost and utility lookups, feeding the Markov engine.
# Costs come from derive/health_state_costs.R (which itself reads
# data/raw/); utilities come directly from Suppl. Table 5
# (aliyev2019_base_case_costs_utilities.csv) -- no colectomy cost anywhere
# (W3 trap 6): Surgery is priced through the same PMPM conversion as every
# other state, per SPEC_AMENDMENTS.md's "Surgery-state costing corrected".

#' Named vector of per-cycle, 2017 USD health-state costs, keyed by
#' MAINTENANCE_STATES in that exact order (Death = 0, added explicitly --
#' no cost accrues there -- so this vector is always the same length and
#' order as an occupancy vector over MAINTENANCE_STATES; a same-length but
#' Death-less vector would silently recycle against one, positionally
#' misaligned, instead of erroring).
health_state_costs_usd_per_cycle <- function(raw_dir = "data/raw") {
  costs <- health_state_cost_cycle_2017_usd(raw_dir)
  values <- setNames(costs$cost_usd_per_cycle, costs$state)
  values <- c(values, "Death" = 0)
  values[MAINTENANCE_STATES]
}

#' Named vector of EQ-5D utility weights, keyed by MAINTENANCE_STATES minus
#' Death (utility 0 there, added explicitly rather than sourced, since no
#' quality of life accrues after death).
health_state_utilities <- function(raw_dir = "data/raw") {
  adopted <- read.csv(file.path(raw_dir, "aliyev2019_base_case_costs_utilities.csv"), stringsAsFactors = FALSE)
  u <- adopted[adopted$category == "Utility (EQ-5D)", ]
  values <- setNames(as.numeric(u$value), u$item)
  # Suppl. Table 5 has no separate row for Remission; Suppl. Table 1
  # Quality of Life assumption #1 anchors M-SR utility, but Remission's own
  # EQ-5D value is on the same panel -- confirm present.
  stopifnot("Remission" %in% names(values))
  values <- c(values, "Death" = 0)
  values[MAINTENANCE_STATES]
}
