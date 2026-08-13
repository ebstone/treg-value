# The comparator Markov engine: induction decision tree feeding a 6-state,
# 2-week-cycle cohort Markov, with background mortality, half-cycle
# correction and discounting. SPEC.md section 3.
#
# Design notes, one per trap this session is built against:
#
# Trap 1 (induction must accrue cost/QALY): induction is modeled as
# `window_weeks / 2` explicit cycles, cohort fully in Moderate-Severe,
# before the decision-tree split is applied. Not a free window.
#
# Trap 2 (cap timing): the 2-year cap applies at the END of the cap cycle --
# that cycle's biologic transition, cost and dose are all charged normally;
# only cycles *after* the cap cycle redirect to CT. See the `t == cap_cycles`
# block inside `run_comparator_trace()`'s maintenance loop.
#
# Trap 3 (window/dosing consistency): `run_comparator_trace()` asserts the
# dosing schedule's last dose week is inside the induction window before
# running -- see the `stopifnot` right after computing `induction_cycles`.
#
# Trap 4 (renormalisation): handled in R/transition_matrices.R, not here.
#
# Trap 5 (maintenance Moderate-Severe row): handled by construction -- the
# maintenance loop inside `run_comparator_trace()` never reads a
# from-Moderate-Severe row off the *biologic* matrix (it has none, by
# design; see aliyev2019_maintenance_transitions.csv.source.yaml). Mass
# that lands in Moderate-Severe under a biologic is moved to the CT cohort
# before the next cycle's transition is applied, so it is always the CT
# matrix's own Moderate-Severe row that governs it from there.
#
# Trap 6 (no colectomy cost): costs come from
# R/costs_utilities.R::health_state_costs_usd_per_cycle(), which is Aliyev's
# PMPM-derived per-cycle figure for every state including Surgery -- no
# episode cost anywhere in this file.
#
# Background mortality applies only during maintenance, not induction --
# matching Aliyev's own Induction assumption #2 ("No chance of Surgery or
# Death during induction... low risk of bias due to short length of
# induction phases"), a deliberate, sourced simplification this engine
# respects rather than overrides.

CYCLE_YEARS <- 1 / ALIYEV_CYCLES_PER_YEAR
DISCOUNT_RATE_PER_YEAR <- 0.03 # SPEC.md section 2; matches Suppl. Table 5's own Discount Rate panel

#' The discount rate in force. Reads an option so a sensitivity analysis can
#' vary it for a whole run without threading a rate argument through every
#' function that discounts something -- CHEERS 2022 item 24 asks for the
#' effect of the choice of discount rate, and the base case is the 3% SPEC.md
#' section 2 fixes. Callers that vary it are responsible for restoring it;
#' analysis/run_scenarios.R does so with on.exit().
discount_rate_per_year <- function() {
  getOption("treg_value.discount_rate", DISCOUNT_RATE_PER_YEAR)
}

#' Discount factor for a value realised `years_from_start` years into the
#' trace, at whichever rate is in force (SPEC.md section 2 fixes 3% annual).
discount_factor_years_to_discount_factor <- function(years_from_start, rate = discount_rate_per_year()) {
  (1 + rate)^(-years_from_start)
}

#' Replace a maintenance transition row's Death probability with the
#' life-table-derived, age-specific 2-week background mortality
#' probability, rescaling every other entry in the row proportionally so
#' the row still sums to exactly 1. This is how age-varying background
#' mortality (SPEC.md section 3) enters a Markov built on Aliyev's own
#' (near-zero, age-flat) Death column -- Maintenance assumption #6, "No
#' excess mortality due to CD", already treats that column as background
#' mortality, just at the low, flat rate appropriate to Aliyev's own young,
#' short-horizon cohort. This engine's lifetime horizon needs it age-varying.
apply_background_mortality_to_row <- function(row_prob_2wk, age_death_prob_2wk) {
  old_death <- row_prob_2wk[["Death"]]
  survival_scale <- (1 - age_death_prob_2wk) / (1 - old_death)
  adjusted <- row_prob_2wk * survival_scale
  adjusted[["Death"]] <- age_death_prob_2wk
  adjusted
}

#' Apply background mortality to every defined row of a maintenance matrix,
#' except Death itself: Death -> Death = 1 is already absorbing, and
#' `apply_background_mortality_to_row()`'s rescaling divides by
#' `1 - old_death`, which is exactly 0 for that row.
age_adjust_maintenance_matrix <- function(m, age_death_prob_2wk) {
  defined <- !is.na(m[, 1]) & rownames(m) != "Death"
  m[defined, ] <- t(apply(m[defined, , drop = FALSE], 1, apply_background_mortality_to_row, age_death_prob_2wk = age_death_prob_2wk))
  m
}

#' Cost accrued in one maintenance cycle: state-occupancy cost (half-cycle
#' corrected -- pass the half-cycle-weighted occupancy vectors) plus, for
#' whoever was on the biologic at the *start* of the cycle, a dose cost on
#' dose cycles. Dose cost deliberately uses start-of-cycle occupancy, not
#' the half-cycle-weighted figure: a dose is a one-time event tied to who
#' was on therapy when the cycle's dose was due, not a duration to average
#' over (the file header's half-cycle correction note).
one_cycle_cost_usd <- function(hc_occupancy_biologic, hc_occupancy_ct, occupancy_start_biologic, is_dose_cycle, costs, dose_cost_usd, ct_drug_cost_usd_per_cycle) {
  state_cost <- sum(hc_occupancy_biologic * costs) + sum(hc_occupancy_ct * costs)
  dose_cost <- if (is_dose_cycle) sum(occupancy_start_biologic) * dose_cost_usd else 0
  # Conventional-therapy drug cost, charged to living CT-cohort mass only.
  ct_alive <- sum(hc_occupancy_ct) - hc_occupancy_ct[["Death"]]
  state_cost + dose_cost + ct_alive * ct_drug_cost_usd_per_cycle
}

#' Trapezoidal half-cycle correction: the value accrued in a cycle is the
#' average of the occupancy vector at the start and at the end of that
#' cycle, not the end-of-cycle occupancy alone. Applied to state-occupancy-
#' driven cost/QALY only, never to one-time dose costs (a dose is an event,
#' not an occupied duration). Direction, asserted in
#' tests/testthat/test-markov-engine.R: relative to using end-of-cycle
#' occupancy alone for every cycle, half-cycle correction always INCREASES
#' cumulative cost and QALYs for a cohort that nets out of higher-value
#' states over time (this entire cohort, monotonically driven toward Death)
#' -- end-of-cycle-only accounting effectively assumes each cycle's
#' transition happens instantaneously at the cycle's start, understating
#' the value the cohort held during the cycle.
half_cycle_weighted_occupancy <- function(occupancy_start, occupancy_end) {
  0.5 * (occupancy_start + occupancy_end)
}

#' Run the full induction-then-maintenance comparator trace for one therapy,
#' induction window, cap setting and horizon. Returns discounted lifetime
#' cost and QALYs, plus validation series for T7/T8 and the trap tests.
run_comparator_trace <- function(therapy, window_weeks, cap_on, horizon_years,
                                  raw_dir = "data/raw", start_age_years = MODEL_START_AGE_YEARS,
                                  population = "naive", product = IFX_PRICED_PRODUCT, life_table_vintage = "base") {
  plan <- dosing_plan(therapy, window_weeks, raw_dir, product = product)
  induction_cycles <- plan$induction_cycles

  costs <- health_state_costs_usd_per_cycle(raw_dir)
  utilities <- health_state_utilities(raw_dir)
  lt <- load_life_table(raw_dir, life_table_vintage)
  induction_matrix <- load_induction_matrix_for_population(therapy, population, raw_dir)
  biologic_matrix_base <- load_maintenance_matrix(therapy, raw_dir)
  ct_matrix_base <- load_maintenance_matrix("CT", raw_dir)
  dose_cost_usd <- plan$maintenance_dose_cost_usd
  ct_drug_cost_usd_per_cycle <- conventional_therapy_cost_usd_per_cycle(raw_dir)
  cap_cycles <- if (cap_on) 2 * ALIYEV_CYCLES_PER_YEAR else Inf

  total_cycles <- round(horizon_years * ALIYEV_CYCLES_PER_YEAR)

  discounted_cost_usd <- 0
  discounted_qaly <- 0
  undiscounted_life_years <- 0
  state_sum_log <- numeric(induction_cycles + total_cycles)
  log_i <- 0L
  age <- start_age_years

  # --- Induction: explicit cycles, cohort fully Moderate-Severe (trap 1) ---
  induction_state_cost <- costs[["Moderate-Severe"]]
  induction_state_utility <- utilities[["Moderate-Severe"]]
  induction_dose_cycles <- plan$induction_dose_cycles
  years_elapsed <- 0
  for (t in seq_len(induction_cycles)) {
    hit <- match(t, induction_dose_cycles)
    cycle_cost <- induction_state_cost + if (!is.na(hit)) plan$induction_dose_costs[hit] else 0
    years_elapsed <- years_elapsed + CYCLE_YEARS
    df <- discount_factor_years_to_discount_factor(years_elapsed)
    discounted_cost_usd <- discounted_cost_usd + cycle_cost * df
    discounted_qaly <- discounted_qaly + induction_state_utility * CYCLE_YEARS * df
    undiscounted_life_years <- undiscounted_life_years + CYCLE_YEARS
    log_i <- log_i + 1L; state_sum_log[log_i] <- 1 # induction cohort is 100% Moderate-Severe
    age <- age + CYCLE_YEARS
  }

  # --- Decision tree: induction outcome distribution, per SPEC.md L1/Fig 1 ---
  outcome <- induction_matrix["Moderate-Severe", ]
  on_biologic <- setNames(numeric(length(MAINTENANCE_STATES)), MAINTENANCE_STATES)
  on_ct <- setNames(numeric(length(MAINTENANCE_STATES)), MAINTENANCE_STATES)
  for (s in INDUCTION_STATES) {
    if (s == "Moderate-Severe") {
      on_ct[["Moderate-Severe"]] <- outcome[[s]] # non-responders: straight to CT (Induction assumption #6)
    } else {
      on_biologic[[s]] <- outcome[[s]] # responders: enter the biologic maintenance Markov in that state
    }
  }

  dose_cycles <- seq(plan$maintenance_interval_cycles,
    if (is.finite(cap_cycles)) cap_cycles else total_cycles, by = plan$maintenance_interval_cycles)

  # Background mortality is constant within an integer age band, so the
  # age-adjusted matrices only change 65 times across a lifetime horizon,
  # not once per cycle. Caching them by age band leaves results identical
  # and removes the engine's dominant cost.
  bio_cache <- list()
  bio_cache_safe <- list()
  ct_cache <- list()

  for (t in seq_len(total_cycles)) {
    occupancy_start_bio <- on_biologic
    occupancy_start_ct <- on_ct
    age_band <- as.character(floor(age))
    if (is.null(bio_cache[[age_band]])) {
      age_death_prob_2wk <- background_mortality_prob_2wk(age, lt)
      bio_cache[[age_band]] <- age_adjust_maintenance_matrix(biologic_matrix_base, age_death_prob_2wk)
      ct_cache[[age_band]] <- age_adjust_maintenance_matrix(ct_matrix_base, age_death_prob_2wk)
      safe <- bio_cache[[age_band]]
      safe[is.na(safe)] <- 0
      bio_cache_safe[[age_band]] <- safe
    }
    biologic_matrix <- bio_cache[[age_band]]
    ct_matrix <- ct_cache[[age_band]]

    # Biologic mass: only the 5 defined rows are ever "from" states here --
    # Moderate-Severe mass in on_biologic is always exactly 0 at cycle start
    # (trap 5's structural guarantee; see file header).
    # One BLAS call per cohort rather than a per-state R loop. The biologic
    # matrix's undefined from-Moderate-Severe row is zeroed for the multiply
    # (see bio_matrix_safe below); on_biologic's Moderate-Severe entry is
    # always exactly 0 here by the trap-5 mechanic, so zeroing that row is
    # arithmetically identical to skipping it.
    next_from_bio <- setNames(as.vector(on_biologic %*% bio_cache_safe[[age_band]]), MAINTENANCE_STATES)
    next_from_ct <- setNames(as.vector(on_ct %*% ct_matrix), MAINTENANCE_STATES)

    # Trap 5 mechanic: mass that just landed in Moderate-Severe under the
    # biologic redirects to CT for the *next* cycle (Maintenance
    # assumption #2 -- switched at the end of the cycle they lost response).
    redirected <- next_from_bio[["Moderate-Severe"]]
    next_from_bio[["Moderate-Severe"]] <- 0
    on_biologic <- next_from_bio
    on_ct <- next_from_ct
    on_ct[["Moderate-Severe"]] <- on_ct[["Moderate-Severe"]] + redirected

    # Trap 2: the cap applies at the END of cap_cycles -- this cycle's
    # transition, cost and dose (just computed/about to be computed) are
    # charged normally; only cycles *after* this one see the sweep.
    if (t == cap_cycles) {
      on_ct <- on_ct + on_biologic
      on_biologic <- setNames(numeric(length(MAINTENANCE_STATES)), MAINTENANCE_STATES)
    }

    occupancy_end_bio <- on_biologic
    occupancy_end_ct <- on_ct

    hc_bio <- half_cycle_weighted_occupancy(occupancy_start_bio, occupancy_end_bio)
    hc_ct <- half_cycle_weighted_occupancy(occupancy_start_ct, occupancy_end_ct)

    is_dose_cycle <- t %in% dose_cycles
    years_elapsed <- years_elapsed + CYCLE_YEARS
    df <- discount_factor_years_to_discount_factor(years_elapsed)

    cycle_cost <- one_cycle_cost_usd(hc_bio, hc_ct, occupancy_start_bio, is_dose_cycle, costs, dose_cost_usd, ct_drug_cost_usd_per_cycle)
    cycle_qaly <- (sum(hc_bio * utilities) + sum(hc_ct * utilities)) * CYCLE_YEARS

    discounted_cost_usd <- discounted_cost_usd + cycle_cost * df
    discounted_qaly <- discounted_qaly + cycle_qaly * df

    # Alive fraction this cycle (half-cycle corrected, same convention as
    # cost/QALY): total occupancy across both cohorts, less Death, averaged
    # start-to-end.
    hc_alive <- sum(hc_bio) + sum(hc_ct) - hc_bio[["Death"]] - hc_ct[["Death"]]
    undiscounted_life_years <- undiscounted_life_years + hc_alive * CYCLE_YEARS
    log_i <- log_i + 1L; state_sum_log[log_i] <- sum(occupancy_end_bio) + sum(occupancy_end_ct)
    age <- age + CYCLE_YEARS
  }

  list(
    discounted_cost_usd = discounted_cost_usd,
    discounted_qaly = discounted_qaly,
    undiscounted_life_years = undiscounted_life_years,
    state_sums = state_sum_log,
    final_on_biologic = on_biologic,
    final_on_ct = on_ct,
    dose_cycles_charged = length(dose_cycles)
  )
}
