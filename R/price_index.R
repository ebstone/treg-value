# Currency re-basing. SPEC.md section 2 fixes the currency year at 2025 USD,
# but cost inputs arrive on three bases: Aliyev's health-state and
# conventional-therapy costs in 2017 USD, and the CMS ASP and Physician Fee
# Schedule figures at current (2026) rates. Everything is brought onto 2025
# USD here, through one named index, before it reaches the engine.
#
# The index is medical-care CPI (BLS CPIMEDNS), the conventional US deflator
# for healthcare-sector costs -- data/raw/cpi_medical_care_annual.csv, whose
# sidecar records that the 2025 average covers eleven months (October 2025
# is absent from the published series) and the 2026 average seven.
#
# Re-basing happens in this layer, never inside derive/. derive/ reproduces
# Aliyev's own published per-cycle figures in Aliyev's own dollar year, and
# its re-derivation test depends on that staying true.

TARGET_CURRENCY_YEAR <- 2025

# Dollar years the model's inputs arrive on.
ALIYEV_COST_YEAR <- 2017 # Suppl. Table 5's stated basis
CMS_COST_YEAR <- 2026 # current ASP quarter and CY2026 fee schedule

#' Annual-average medical-care CPI for one year.
price_index_for_year <- function(year, raw_dir = "data/raw") {
  idx <- read_csv_cached(file.path(raw_dir, "cpi_medical_care_annual.csv"))
  row <- idx[idx$year == year, ]
  stopifnot(nrow(row) == 1)
  row$annual_average_index
}

#' Multiplicative factor taking a dollar figure from `from_year` to
#' `to_year` on the medical-care CPI.
rebasing_factor <- function(from_year, to_year = TARGET_CURRENCY_YEAR, raw_dir = "data/raw") {
  price_index_for_year(to_year, raw_dir) / price_index_for_year(from_year, raw_dir)
}

#' Re-base a dollar figure to the target currency year.
rebase_usd <- function(amount_usd, from_year, to_year = TARGET_CURRENCY_YEAR, raw_dir = "data/raw") {
  amount_usd * rebasing_factor(from_year, to_year, raw_dir)
}
