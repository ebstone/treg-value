# Dosing and per-dose cost for the secondary comparators (SPEC.md scenario
# S5; section 2 scopes them as "frontier checks only").
#
# Infliximab's own schedule stays in R/dosing.R, because L5's week-4 versus
# week-8 induction-window pair is specific to it and is a bounding pair on
# every primary output rather than a scenario. Ustekinumab and adalimumab
# are read from data/raw/biologic_dosing_regimens.csv, transcribed from the
# FDA labels.
#
# Their induction windows are each drug's own readout in Aliyev's parameter
# table -- week 6 for ustekinumab, week 4 for adalimumab -- not infliximab's.
# Using infliximab's window for another drug would repeat the W3 trap where
# the dosing schedule and the transition window described different numbers
# of weeks.

#' The label regimen for one secondary comparator.
comparator_regimen <- function(therapy, raw_dir = "data/raw") {
  d <- read_csv_cached(file.path(raw_dir, "biologic_dosing_regimens.csv"))
  row <- d[d$therapy == therapy, ]
  stopifnot(nrow(row) == 1)
  split_num <- function(x) as.numeric(strsplit(as.character(x), ";", fixed = TRUE)[[1]])
  items <- strsplit(as.character(row$unit_cost_item), "|", fixed = TRUE)[[1]]
  list(
    induction_window_weeks = row$induction_window_weeks,
    induction_dose_weeks = split_num(row$induction_dose_weeks),
    induction_units = split_num(row$induction_units_per_dose),
    induction_route = row$induction_route,
    maintenance_interval_cycles = row$maintenance_interval_cycles,
    maintenance_units = row$maintenance_units_per_dose,
    maintenance_route = row$maintenance_route,
    induction_unit_cost_item = items[1],
    maintenance_unit_cost_item = items[2]
  )
}

#' A unit cost from Aliyev's Suppl. Table 5, re-based to the target year.
comparator_unit_cost_usd <- function(item, raw_dir = "data/raw") {
  adopted <- read_csv_cached(file.path(raw_dir, "aliyev2019_base_case_costs_utilities.csv"))
  row <- adopted[adopted$category == "Unit Cost (2017 USD)" & adopted$item == item, ]
  stopifnot(nrow(row) == 1)
  rebase_usd(as.numeric(row$value), ALIYEV_COST_YEAR, raw_dir = raw_dir)
}

#' Cost of one administration for a secondary comparator, by phase.
#' Intravenous administration carries the infusion fee; subcutaneous
#' self-injection does not.
comparator_dose_cost_usd <- function(therapy, phase, raw_dir = "data/raw") {
  stopifnot(phase %in% c("induction", "maintenance"))
  reg <- comparator_regimen(therapy, raw_dir)
  if (phase == "induction") {
    drug <- comparator_unit_cost_usd(reg$induction_unit_cost_item, raw_dir) * reg$induction_units
    admin <- if (reg$induction_route == "intravenous") {
      ifx_administration_cost_usd_per_dose(raw_dir)
    } else {
      0
    }
    return(drug + admin)
  }
  drug <- comparator_unit_cost_usd(reg$maintenance_unit_cost_item, raw_dir) * reg$maintenance_units
  admin <- if (reg$maintenance_route == "intravenous") ifx_administration_cost_usd_per_dose(raw_dir) else 0
  drug + admin
}

#' A therapy's complete dosing plan in engine terms: which induction cycles
#' carry a dose and what each costs, and the maintenance interval and its
#' per-dose cost.
#'
#' Infliximab's doses all cost the same, so a single figure suffices there.
#' Adalimumab's do not -- 160 mg on day 1 is four syringes and 80 mg on day
#' 15 is two -- so induction cost is returned per cycle rather than as one
#' number. `window_weeks` applies to infliximab only, where L5 makes it a
#' bounding pair; the secondary comparators use their own label windows.
dosing_plan <- function(therapy, window_weeks = NULL, raw_dir = "data/raw",
                         product = IFX_PRICED_PRODUCT) {
  if (therapy == "IFX") {
    stopifnot(!is.null(window_weeks))
    dose_weeks <- ifx_induction_dose_weeks(window_weeks)
    per_dose <- ifx_infusion_cost_usd_per_dose(raw_dir, product = product)
    return(list(
      induction_window_weeks = window_weeks,
      induction_cycles = window_weeks / 2,
      induction_dose_cycles = ceiling((dose_weeks + 1) / 2),
      induction_dose_costs = rep(per_dose, length(dose_weeks)),
      maintenance_interval_cycles = IFX_MAINTENANCE_DOSE_INTERVAL_CYCLES,
      maintenance_dose_cost_usd = per_dose
    ))
  }
  reg <- comparator_regimen(therapy, raw_dir)
  unit <- comparator_unit_cost_usd(reg$induction_unit_cost_item, raw_dir)
  admin <- if (reg$induction_route == "intravenous") ifx_administration_cost_usd_per_dose(raw_dir) else 0
  stopifnot(all(reg$induction_dose_weeks < reg$induction_window_weeks)) # trap 3
  list(
    induction_window_weeks = reg$induction_window_weeks,
    induction_cycles = reg$induction_window_weeks / 2,
    induction_dose_cycles = ceiling((reg$induction_dose_weeks + 1) / 2),
    induction_dose_costs = unit * reg$induction_units + admin,
    maintenance_interval_cycles = reg$maintenance_interval_cycles,
    maintenance_dose_cost_usd = comparator_dose_cost_usd(therapy, "maintenance", raw_dir)
  )
}
