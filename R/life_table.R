# Background mortality from the NCHS 2023 US life table
# (data/raw/nchs_life_table_2023.csv), converted to this repo's native 2-week
# cycle length via the same DEALE-style hazard conversion Aliyev's own
# appendix uses for its trial-derived transition probabilities
# (phar2208-sup-0002-appendixs2.pdf, "Transition Probability Calculation"):
# rate = -ln(1 - p) / t_years; probability(cycle) = 1 - exp(-rate * cycle_years).

# Model cohort starting age -- SPEC_AMENDMENTS.md "Model starting age set to
# 35", 2026-08-13. Sourced from the SONIC trial (Colombel et al., NEJM 2010),
# not from Aliyev (whose own figure, if any, is behind a paywall this
# session couldn't reach).
MODEL_START_AGE_YEARS <- 35

# Cycles per year -- Aliyev's own stated figure (Suppl. Table 5, "Discount
# Rate" panel), not recomputed from 52/2 here so a change in the source
# stays authoritative.
ALIYEV_CYCLES_PER_YEAR <- 26

#' Convert an annual life-table probability of death (qx) to the equivalent
#' probability over a 2-week cycle, via a constant-hazard (DEALE-style)
#' conversion -- the same method Aliyev's own appendix uses.
annual_qx_prob_1yr_to_prob_2wk <- function(qx_prob_1yr, cycles_per_year = ALIYEV_CYCLES_PER_YEAR) {
  hazard_per_year <- -log(1 - qx_prob_1yr)
  1 - exp(-hazard_per_year / cycles_per_year)
}

# Life-table vintages. The base case uses the most recent NCHS publication;
# SPEC.md scenario S7 asks for a pre-pandemic vintage as a contrast.
LIFE_TABLE_VINTAGES <- c(base = "nchs_life_table_2023.csv", pre_pandemic = "nchs_life_table_2019.csv")

#' The NCHS life table, with a `qx_prob_2wk` column added. `vintage` selects
#' between the base case and SPEC.md scenario S7's pre-pandemic table.
load_life_table <- function(raw_dir = "data/raw", vintage = "base") {
  stopifnot(vintage %in% names(LIFE_TABLE_VINTAGES))
  lt <- read_csv_cached(file.path(raw_dir, LIFE_TABLE_VINTAGES[[vintage]]))
  lt$qx_prob_2wk <- annual_qx_prob_1yr_to_prob_2wk(lt$qx_prob_1yr)
  lt
}

#' Background-mortality 2-week death probability at a given age in
#' completed years (life-table single-year-of-age bands; ages above the
#' table's max are clamped to the oldest band, whose qx is 1).
background_mortality_prob_2wk <- function(age_years, life_table) {
  idx <- pmin(floor(age_years), max(life_table$age_years)) + 1L
  life_table$qx_prob_2wk[idx]
}

#' Undiscounted life expectancy (in years) from a given starting age,
#' computed directly from the life table's own lx column (person-years-lived
#' approach, matching NCHS's own ex column) -- independent of the Markov
#' engine, for T8's cross-check.
life_table_expectancy_years <- function(start_age_years, life_table) {
  from <- life_table[life_table$age_years >= start_age_years, ]
  # ex at the start age is already what NCHS publishes directly.
  from$ex_years[1]
}
