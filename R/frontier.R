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
#' at time zero.
#'
#' This is SPEC.md section 1's own definition of A read literally -- the
#' deferral of the comparator induction course across the rescue window,
#' less the health and non-drug cost penalty of that window.
#'
#' WHY THE WINDOW IS SUMMED IN CLOSED FORM. T1 is only worth having if the two
#' routes to `A` can disagree. An earlier version of this function advanced the
#' cohort with the same cycle-by-cycle loop `run_treg_trace()` uses -- same
#' initial vector, same matrix, same half-cycle correction, same discount
#' indexing, written out twice. Agreement was then close to automatic: setting
#' the rescue window to the wrong length moved `A` by $232.83 and T1 still
#' passed with a difference of exactly 0.00, because both copies moved
#' together. The two routes may share inputs -- the CT matrix and the cost and
#' utility vectors are the same data either way -- but they must not share the
#' derivation.
#'
#' So the discounted half-cycle-weighted occupancy over the window is summed
#' as a matrix series rather than accumulated in a loop. With `v` the
#' per-cycle discount factor, `M` the mortality-free CT matrix, `e` the
#' all-Moderate-Severe starting vector and `T` the landmark, the occupancy at
#' cycle `t` is `e M^t`, and
#'
#'     sum_{t=1..T} v^t * 0.5 * (e M^(t-1) + e M^t)
#'       = 0.5 * e * (v I + v M) * sum_{t=0..T-1} (v M)^t
#'       = 0.5 * e * (v I + v M) * (I - (v M)^T) (I - v M)^-1
#'
#' which is evaluated below with a matrix inverse and no cycle loop. An
#' off-by-one in either route's cycle count, a mis-indexed discount factor or a
#' dropped half-cycle term now shows up as disagreement instead of cancelling.
frontier_intercept_independent <- function(lambda_usd_per_qaly, comparator, sc_grid,
                                           raw_dir = "data/raw", start_age_years = MODEL_START_AGE_YEARS) {
  costs <- health_state_costs_usd_per_cycle(raw_dir)
  utilities <- health_state_utilities(raw_dir)
  ct_drug_cost <- conventional_therapy_cost_usd_per_cycle(raw_dir)
  ct_matrix <- age_adjust_maintenance_matrix(load_maintenance_matrix("CT", raw_dir), 0)

  m <- as.matrix(ct_matrix[MAINTENANCE_STATES, MAINTENANCE_STATES])
  n <- length(MAINTENANCE_STATES)
  identity <- diag(n)
  v <- discount_factor_years_to_discount_factor(CYCLE_YEARS)
  vm <- v * m

  # sum_{t=0..T-1} (vM)^t, in closed form.
  vm_to_t <- diag(n)
  for (i in seq_len(LANDMARK_CYCLES)) vm_to_t <- vm_to_t %*% vm # (vM)^T, by definition
  geometric <- (identity - vm_to_t) %*% solve(identity - vm)

  e <- matrix(0, nrow = 1, ncol = n)
  e[1, match("Moderate-Severe", MAINTENANCE_STATES)] <- 1
  weighted <- setNames(
    as.vector(0.5 * e %*% (v * identity + vm) %*% geometric),
    MAINTENANCE_STATES
  )

  alive <- sum(weighted) - weighted[["Death"]]
  window_cost <- sum(weighted * costs) + alive * ct_drug_cost
  window_qaly <- sum(weighted * utilities) * CYCLE_YEARS

  landmark_age <- start_age_years + LANDMARK_CYCLES * CYCLE_YEARS
  landmark_discount <- discount_factor_years_to_discount_factor(LANDMARK_CYCLES * CYCLE_YEARS)
  deferred <- standard_care_at_age(sc_grid, landmark_age)

  nmb_window <- nmb_usd(window_cost, window_qaly, lambda_usd_per_qaly)
  nmb_deferred_course <- landmark_discount * nmb_usd(deferred$cost, deferred$qaly, lambda_usd_per_qaly)
  nmb_comparator <- nmb_usd(comparator$discounted_cost_usd, comparator$discounted_qaly, lambda_usd_per_qaly)

  nmb_window + nmb_deferred_course - nmb_comparator
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
