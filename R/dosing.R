# Infliximab dosing schedule and per-dose cost.
#
# Two inputs here are provisional, clearly flagged, and distinct from the
# well-specified Markov mechanics this session's traps are about:
#
# - IFX_DOSE_MG assumes the standard 5 mg/kg dosing weight-scaled to the
#   SONIC trial's median body weight (69.6-72.0 kg across arms, Colombel
#   et al. NEJM 2010) -- not sourced from Aliyev, who doesn't state a
#   modeled body weight anywhere available this session.
# - IFX_PRICED_PRODUCT uses Q5104 (Renflexis) pending OPEN_QUESTIONS.md O8
#   (which biosimilar prices the base case is still open for Eric/co-author
#   sign-off). Renflexis matches what W2_sourcing_register.md flagged the
#   prior project as having used, kept here only for continuity, not
#   because it has been re-justified.

IFX_DOSE_MG_PER_KG <- 5
IFX_BODY_WEIGHT_KG <- 70 # SONIC median, rounded
IFX_DOSE_MG <- IFX_DOSE_MG_PER_KG * IFX_BODY_WEIGHT_KG
IFX_PRICED_PRODUCT <- "Q5104"

#' Cost of one infliximab infusion's drug (dose_mg * $/mg for the priced
#' product), read from data/raw/cms_asp_infliximab_2026.csv.
ifx_drug_cost_usd_per_dose <- function(dose_mg = IFX_DOSE_MG, product = IFX_PRICED_PRODUCT, raw_dir = "data/raw") {
  asp <- read.csv(file.path(raw_dir, "cms_asp_infliximab_2026.csv"), stringsAsFactors = FALSE)
  row <- asp[asp$hcpcs_code == product, ]
  stopifnot(nrow(row) == 1)
  dose_mg * row$usd_per_mg
}

#' Administration cost for one infusion visit: CPT 96365 (first hour) + one
#' unit of 96366 (each additional hour), read from
#' data/raw/cms_pfs_infusion_administration_2026.csv. Assumes a ~2-hour
#' infusion (one 96366 unit) -- W2_sourcing_register.md's own note that
#' "infliximab infusions run 2 hours or more, so 96365 alone understates
#' administration"; the PFS sidecar's U1 flags that 96366's additive billing
#' has not been separately confirmed against CMS policy.
ifx_administration_cost_usd_per_dose <- function(raw_dir = "data/raw") {
  pfs <- read.csv(file.path(raw_dir, "cms_pfs_infusion_administration_2026.csv"), stringsAsFactors = FALSE)
  first_hour <- pfs$national_payment_usd[pfs$hcpcs_code == "96365" & pfs$setting == "non-facility"][1]
  addl_hour <- pfs$national_payment_usd[pfs$hcpcs_code == "96366" & pfs$setting == "non-facility"][1]
  first_hour + addl_hour
}

#' Total cost of one infliximab infusion visit: drug + administration.
ifx_infusion_cost_usd_per_dose <- function(raw_dir = "data/raw") {
  ifx_drug_cost_usd_per_dose(raw_dir = raw_dir) + ifx_administration_cost_usd_per_dose(raw_dir)
}

#' Induction dose weeks for a given induction window, per SPEC.md L5 (S1:
#' week-4 vs week-8 readings run as a pair) and W3 trap 3 (the dosing
#' schedule and the transition window must describe the same number of
#' weeks -- a dose after the window closes is a mismatch). Standard IFX
#' induction is weeks 0, 2, 6; the week-6 dose is only included when the
#' window is wide enough to contain it.
ifx_induction_dose_weeks <- function(window_weeks) {
  stopifnot(window_weeks %in% c(4, 8))
  all_doses <- c(0, 2, 6)
  doses <- all_doses[all_doses < window_weeks]
  stopifnot(all(doses < window_weeks)) # trap 3, made explicit
  doses
}

#' Maintenance dose cycles (2-week cycles, 1-indexed from the first
#' maintenance cycle) up to and including `max_cycle`, at the standard IFX
#' q8week maintenance interval (every 4 cycles).
IFX_MAINTENANCE_DOSE_INTERVAL_CYCLES <- 4
ifx_maintenance_dose_cycles <- function(max_cycle) {
  seq(IFX_MAINTENANCE_DOSE_INTERVAL_CYCLES, max_cycle, by = IFX_MAINTENANCE_DOSE_INTERVAL_CYCLES)
}
