# The price frontier: P*(pi, h, lambda) = A(lambda) + pi * B(h, lambda).
#
# THE INTERCEPT. P*(0) must equal A and nothing else. `A` is computed here
# by two deliberately different routes -- `frontier_intercept_from_model()`
# runs the whole Treg arm at pi_cure = 0, while
# `frontier_intercept_independent()` never touches the Treg arm at all and
# instead prices the 12-week window directly and defers one comparator
# course. T1 requires them to agree to $1. A previous build carried a few
# thousand dollars of unexplained savings at the intercept; two routes that
# share no code is how that stops being possible to miss.
#
# A MAY BE NEGATIVE. Under L9 a therapy that cures nobody has spent the
# patient's rescue window on conventional therapy and then started the
# induction course anyway. SPEC.md section 4 records this explicitly. No
# clamping, no flooring, no absolute value anywhere in this file.
#
# T12: nothing here reads a manufacturing benchmark. Price is solved from
# value; the benchmark (W5) is compared against the answer afterwards and
# never enters it.

#' Net monetary benefit of a (cost, QALY) pair at a willingness-to-pay
#' threshold. NMB = lambda * QALYs - cost.
nmb_usd <- function(cost_usd, qaly, lambda_usd_per_qaly) {
  lambda_usd_per_qaly * qaly - cost_usd
}

#' Maximum justifiable price of one Treg course at a given cure fraction,
#' relapse hazard and willingness to pay: the price at which the Treg arm's
#' net monetary benefit equals the comparator's.
#'
#' Deliberately evaluated by running the arm at this `pi_cure`, NOT by
#' assembling `A + pi * B`. The affine structure is a property of the model
#' that T3 verifies, not an identity this function imposes -- writing it as
#' `A + pi * B` here would make T3 vacuous and hide exactly the kind of
#' pi-dependence downstream of the split that T3 exists to catch.
price_star_usd_per_course <- function(pi_cure, h_per_year, lambda_usd_per_qaly,
                                       comparator, sc_grid, window_weeks, cap_on, raw_dir = "data/raw",
                                       life_table_vintage = "base") {
  treg <- run_treg_trace(pi_cure, h_per_year, window_weeks, cap_on, sc_grid, raw_dir,
    life_table_vintage = life_table_vintage)
  nmb_treg <- nmb_usd(treg$discounted_cost_usd, treg$discounted_qaly, lambda_usd_per_qaly)
  nmb_comparator <- nmb_usd(comparator$discounted_cost_usd, comparator$discounted_qaly, lambda_usd_per_qaly)
  nmb_treg - nmb_comparator
}

#' `A`, the intercept, from the model: the frontier evaluated at a cure
#' fraction of zero.
frontier_intercept_from_model <- function(h_per_year, lambda_usd_per_qaly, comparator, sc_grid,
                                          window_weeks, cap_on, raw_dir = "data/raw",
                                          life_table_vintage = "base") {
  price_star_usd_per_course(0, h_per_year, lambda_usd_per_qaly, comparator, sc_grid, window_weeks, cap_on, raw_dir,
    life_table_vintage = life_table_vintage)
}

#' `A`, the intercept, computed independently of the Treg arm: price the
#' 12-week conventional-therapy window directly, add one full comparator
#' course deferred to the landmark, and subtract the comparator course begun
#' at time zero. Shares no code path with `run_treg_trace()`.
#'
#' This is SPEC.md section 1's own definition of A read literally -- the
#' deferral of the comparator induction course across the rescue window,
#' less the health and non-drug cost penalty of that window.
frontier_intercept_independent <- function(lambda_usd_per_qaly, comparator, sc_grid,
                                           raw_dir = "data/raw", start_age_years = MODEL_START_AGE_YEARS) {
  costs <- health_state_costs_usd_per_cycle(raw_dir)
  utilities <- health_state_utilities(raw_dir)
  ct_drug_cost <- conventional_therapy_cost_usd_per_cycle(raw_dir)
  ct_matrix <- age_adjust_maintenance_matrix(load_maintenance_matrix("CT", raw_dir), 0)

  cohort <- setNames(numeric(length(MAINTENANCE_STATES)), MAINTENANCE_STATES)
  cohort[["Moderate-Severe"]] <- 1

  window_cost <- 0
  window_qaly <- 0
  years_elapsed <- 0
  for (t in seq_len(LANDMARK_CYCLES)) {
    start <- cohort
    end <- setNames(numeric(length(MAINTENANCE_STATES)), MAINTENANCE_STATES)
    for (s in MAINTENANCE_STATES) end <- end + cohort[[s]] * ct_matrix[s, ]
    cohort <- end
    hc <- half_cycle_weighted_occupancy(start, end)
    years_elapsed <- years_elapsed + CYCLE_YEARS
    df <- discount_factor_years_to_discount_factor(years_elapsed)
    alive <- sum(hc) - hc[["Death"]]
    window_cost <- window_cost + (sum(hc * costs) + alive * ct_drug_cost) * df
    window_qaly <- window_qaly + sum(hc * utilities) * CYCLE_YEARS * df
  }

  landmark_age <- start_age_years + LANDMARK_CYCLES * CYCLE_YEARS
  landmark_discount <- discount_factor_years_to_discount_factor(years_elapsed)
  deferred <- standard_care_at_age(sc_grid, landmark_age)

  nmb_window <- nmb_usd(window_cost, window_qaly, lambda_usd_per_qaly)
  nmb_deferred_course <- landmark_discount * nmb_usd(deferred$cost, deferred$qaly, lambda_usd_per_qaly)
  nmb_comparator <- nmb_usd(comparator$discounted_cost_usd, comparator$discounted_qaly, lambda_usd_per_qaly)

  nmb_window + nmb_deferred_course - nmb_comparator
}

#' The independent route's cost, resolved by cycle: the 12-week conventional-
#' therapy window priced directly, then one full comparator course deferred to
#' the landmark, discounted to t = 0 and indexed from t = 0.
#'
#' This is the only genuinely independent check available on the Treg arm's
#' cost stream. `run_treg_trace()` has no horizon argument to vary, so T18's
#' two-independent-routes construction has no Treg-side analogue; what this
#' gives instead is a second construction of the same quantity. At a cure
#' fraction of zero the Treg arm is exactly this -- everyone spends the window
#' on conventional therapy and is then handed one standard-care course at the
#' landmark, with no drug-free-remission mass and no relapsers -- so the two
#' streams must agree cycle by cycle, and they are built by different code
#' reading the same inputs.
#'
#' The window loop below duplicates `frontier_intercept_independent()`'s rather
#' than sharing a helper with it, for the reason stated in this file's header:
#' the value of an independent route is that it shares no code path with what
#' it checks, and a helper factored out for tidiness is how that property gets
#' lost a session later. `frontier_intercept_independent()`'s own signature and
#' arithmetic are untouched, so T1 continues to compare exactly what it did.
frontier_intercept_independent_cost_stream_usd <- function(sc_cost_stream_grid, raw_dir = "data/raw",
                                                            start_age_years = MODEL_START_AGE_YEARS) {
  costs <- health_state_costs_usd_per_cycle(raw_dir)
  ct_drug_cost <- conventional_therapy_cost_usd_per_cycle(raw_dir)
  ct_matrix <- age_adjust_maintenance_matrix(load_maintenance_matrix("CT", raw_dir), 0)

  cohort <- setNames(numeric(length(MAINTENANCE_STATES)), MAINTENANCE_STATES)
  cohort[["Moderate-Severe"]] <- 1

  stream <- numeric(LANDMARK_CYCLES + ncol(sc_cost_stream_grid$streams))
  years_elapsed <- 0
  for (t in seq_len(LANDMARK_CYCLES)) {
    start <- cohort
    end <- setNames(numeric(length(MAINTENANCE_STATES)), MAINTENANCE_STATES)
    for (s in MAINTENANCE_STATES) end <- end + cohort[[s]] * ct_matrix[s, ]
    cohort <- end
    hc <- half_cycle_weighted_occupancy(start, end)
    years_elapsed <- years_elapsed + CYCLE_YEARS
    df <- discount_factor_years_to_discount_factor(years_elapsed)
    alive <- sum(hc) - hc[["Death"]]
    stream[t] <- (sum(hc * costs) + alive * ct_drug_cost) * df
  }

  landmark_age <- start_age_years + LANDMARK_CYCLES * CYCLE_YEARS
  landmark_discount <- discount_factor_years_to_discount_factor(years_elapsed)
  deferred <- standard_care_cost_stream_at_age(sc_cost_stream_grid, landmark_age)
  at <- LANDMARK_CYCLES + seq_along(deferred)
  stream[at] <- stream[at] + landmark_discount * deferred
  stream
}

#' `B`, the slope -- what one durable cure is worth. Computed directly as
#' the discounted lifetime NMB difference between a cured patient and a
#' patient on standard first-line biologic therapy, both followed from the
#' landmark. Independent of the frontier's own endpoints, so T2 can compare
#' it against `P*(1) - P*(0)`.
#'
#' DISCOUNTING REFERENCE POINT. Both streams begin at the landmark but are
#' discounted to t = 0, not to the landmark. `P*` is a price paid at t = 0,
#' so every term in `P* = A + pi * B` has to be denominated there; a `B`
#' discounted to the landmark instead is larger by exactly 1/v^6 (0.68% at
#' 3% annual over 12 weeks) and breaks T2 by ~$1,100 while leaving T1 and T3
#' untouched -- which is how it was found, and why T2 is worth having.
#' LIFE-TABLE VINTAGE. `sc_grid` is built by the caller at some vintage, and
#' the cured stream below is differenced against it. Both sides must read the
#' same table or the result mixes two mortality regimes and belongs to neither.
#' This argument existed only on the grid and comparator before, so scenario S7
#' shipped a `B` whose cured patient died on the base table while the standard
#' care it was differenced against used the pre-pandemic one.
value_of_one_cure_usd <- function(h_per_year, lambda_usd_per_qaly, sc_grid,
                                   raw_dir = "data/raw", start_age_years = MODEL_START_AGE_YEARS,
                                   life_table_vintage = "base") {
  costs <- health_state_costs_usd_per_cycle(raw_dir)
  utilities <- health_state_utilities(raw_dir)
  lt <- load_life_table(raw_dir, life_table_vintage)
  p_relapse_2wk <- relapse_hazard_per_year_to_prob_2wk(h_per_year)

  landmark_age <- start_age_years + LANDMARK_CYCLES * CYCLE_YEARS
  total_cycles <- round((100 - start_age_years) * ALIYEV_CYCLES_PER_YEAR)

  # One cured patient, followed from the landmark, discounted to t = 0.
  dfr <- 1
  age <- landmark_age
  years_from_start <- LANDMARK_CYCLES * CYCLE_YEARS
  cured_cost <- 0
  cured_qaly <- 0

  for (t in seq(LANDMARK_CYCLES + 1, total_cycles)) {
    start_dfr <- dfr
    died <- dfr * background_mortality_prob_2wk(age, lt)
    survivors <- dfr - died
    relapsed <- survivors * p_relapse_2wk
    dfr <- survivors - relapsed

    hc_dfr <- 0.5 * (start_dfr + dfr)
    years_from_start <- years_from_start + CYCLE_YEARS
    df <- discount_factor_years_to_discount_factor(years_from_start)

    cured_cost <- cured_cost + hc_dfr * costs[["Remission"]] * df
    cured_qaly <- cured_qaly + hc_dfr * utilities[["Remission"]] * CYCLE_YEARS * df

    if (relapsed > 0) {
      sc <- standard_care_at_age(sc_grid, age)
      cured_cost <- cured_cost + relapsed * df * sc$cost
      cured_qaly <- cured_qaly + relapsed * df * sc$qaly
    }
    age <- age + CYCLE_YEARS
  }

  # One patient on standard first-line biologic therapy, from the same
  # landmark, brought to the same t = 0 reference point.
  standard <- standard_care_at_age(sc_grid, landmark_age)
  landmark_discount <- discount_factor_years_to_discount_factor(LANDMARK_CYCLES * CYCLE_YEARS)

  nmb_usd(cured_cost, cured_qaly, lambda_usd_per_qaly) -
    landmark_discount * nmb_usd(standard$cost, standard$qaly, lambda_usd_per_qaly)
}

#' Required cure fraction for a given course price to be justified:
#' solve P* = A + pi * B for pi. On the all-treated denominator, because
#' that is the only denominator `pi_cure` ever has (L2).
required_cure_fraction <- function(price_usd_per_course, intercept_a_usd_per_course, slope_b_usd_per_course) {
  (price_usd_per_course - intercept_a_usd_per_course) / slope_b_usd_per_course
}
