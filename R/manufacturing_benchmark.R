# The manufacturing cost benchmark (SPEC.md section 8, "TO BUILD (W5)"):
# triangulated from analogy anchors, a techno-economic bottom-up, and
# revealed prices, with margin sourced rather than invented.
#
# L8 IS THE POINT OF THIS FILE. The benchmark is a benchmark, never a model
# input. No pricing function may read anything here; the frontier is solved
# from value alone and the benchmark is held up against the answer
# afterwards. T12 asserts this by grep over the pricing path, and nothing in
# R/frontier.R or R/treg_arm.R references this file.
#
# WHY A RANGE AND NOT A POINT. W2_sourcing_register.md S-5 identified the
# Treg dose in cells per kilogram as the single most important input, since
# published allogeneic cell-therapy cost of goods spans two orders of
# magnitude driven mainly by dose size and lot size. That dose is not
# publicly available: all three registered TRX103 trials (NCT06721962,
# NCT06462365, NCT07427628) describe their arms only as "Dose level 1/2/3"
# and disclose no cells-per-kilogram figure. The techno-economic bottom-up
# leg is therefore not built here, and the benchmark is the range the other
# two legs support -- which is what SPEC.md section 8 asks for ("Range").

#' Annual-average USD per EUR, for converting a euro-denominated source
#' figure at its own year's rate.
usd_per_eur <- function(year, raw_dir = "data/raw") {
  fx <- read_csv_cached(file.path(raw_dir, "fx_usd_per_eur_annual.csv"))
  row <- fx[fx$year == year, ]
  stopifnot(nrow(row) == 1)
  row$usd_per_eur_annual_average
}

TENHAM_COST_YEAR <- 2018 # ten Ham et al. 2020 report in 2018 euros

#' Convert a ten Ham euro figure to target-year USD: convert at the source
#' year's exchange rate, then inflate in dollars. Converting at today's rate
#' after inflating in euros would blend two countries' price paths.
tenham_eur_to_usd <- function(amount_eur, raw_dir = "data/raw") {
  rebase_usd(amount_eur * usd_per_eur(TENHAM_COST_YEAR, raw_dir), TENHAM_COST_YEAR, raw_dir = raw_dir)
}

#' Per-treatment manufacturing cost for each ten Ham case study, in
#' target-year USD, with the case's product origin and batch yield attached.
#'
#' For case studies 1-7 one batch is one treatment, so the
#' failure-rate-adjusted per-batch figure IS the per-treatment cost -- the
#' article states this directly. Case study 8 yields 22 treatments per batch
#' and reports its own per-treatment figure, which is used as printed.
tenham_analogy_anchors <- function(raw_dir = "data/raw") {
  cs <- read_csv_cached(file.path(raw_dir, "tenham2020_case_studies.csv"))
  per_treatment_eur <- ifelse(
    is.na(cs$total_per_treatment_eur),
    cs$total_per_batch_after_failure_eur,
    cs$total_per_treatment_eur
  )
  data.frame(
    case_study = cs$case_study_id,
    product_origin = cs$product_origin,
    allogeneic = grepl("Allogeneic", cs$product_origin, ignore.case = TRUE),
    treatments_per_batch = cs$treatment_yield_per_batch,
    cost_per_treatment_usd = tenham_eur_to_usd(per_treatment_eur, raw_dir),
    stringsAsFactors = FALSE
  )
}

#' Reported per-dose cost of goods for approved autologous CAR-T, in
#' target-year USD. An upper anchor only: autologous manufacturing runs one
#' batch per patient and cannot amortise across doses, so it bounds a
#' different production model rather than matching this one.
revealed_price_cogs_anchors <- function(raw_dir = "data/raw", cogs_report_year = 2023) {
  rp <- read_csv_cached(file.path(raw_dir, "cell_therapy_revealed_prices_2025.csv"))
  have <- !is.na(rp$cogs_low_usd)
  data.frame(
    product = rp$product[have],
    cogs_low_usd = rebase_usd(rp$cogs_low_usd[have], cogs_report_year, raw_dir = raw_dir),
    cogs_high_usd = rebase_usd(rp$cogs_high_usd[have], cogs_report_year, raw_dir = raw_dir),
    list_price_usd = rp$us_list_price_usd[have],
    stringsAsFactors = FALSE
  )
}

#' The triangulated benchmark: a range of plausible manufacturing cost per
#' treatment for an allogeneic Treg course, in target-year USD.
#'
#' The lower bound is the cheapest allogeneic ten Ham case -- the one whose
#' batch actually amortises across many treatments, which is the production
#' model an allogeneic Treg product would use. The upper bound is the top of
#' the reported autologous CAR-T cost-of-goods range, a manufacturing model
#' that cannot amortise at all. The middle is where the remaining allogeneic
#' anchors sit.
manufacturing_benchmark_usd_per_course <- function(raw_dir = "data/raw") {
  anchors <- tenham_analogy_anchors(raw_dir)
  allo <- anchors$cost_per_treatment_usd[anchors$allogeneic]
  cogs <- revealed_price_cogs_anchors(raw_dir)
  list(
    low_usd = min(allo),
    allogeneic_median_usd = stats::median(allo),
    allogeneic_high_usd = max(allo),
    high_usd = max(cogs$cogs_high_usd),
    n_allogeneic_anchors = length(allo)
  )
}
