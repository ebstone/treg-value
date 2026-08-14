# The Treg arm: conventional-therapy dynamics to the 12-week landmark (L9),
# a two-fate split at cycle 6 (L1/L2), a sustained drug-free-remission state
# with an ongoing relapse hazard (L4), and non-cured patients entering
# standard care in full (L3).
#
# THE DENOMINATOR. `pi_cure` is a share of ALL TREATED PATIENTS (L2), not of
# any subset. This file peels it as `pi_cure * (entire cycle-6 cohort)`,
# never as a share of the remission-state occupancy or of any track. Two
# previous builds made it a share of a subset and reported it as if it were
# not, flattening the price curve roughly fivefold. The split below takes
# the whole cohort as its base and is asserted against the trace itself in
# tests/testthat/test-treg-arm.R (T4), not merely against the parameter's
# declared `denominator` attribute -- an attribute records an intent, the
# trace records what actually happened.
#
# Pre-landmark mortality is suppressed across cycles 1-6 -- see
# SPEC_AMENDMENTS.md "Pre-landmark window is mortality-free". Without it the
# cycle-6 cohort is 0.99956 rather than exactly 1, and T4's "equals 1.00"
# becomes unreachable by construction rather than by error.

DRUG_FREE_REMISSION_STATE <- "Drug-Free Remission"
LANDMARK_CYCLES <- 6 # 12 weeks at 2 weeks/cycle (L1)

# The cure fraction as a declared parameter. Carries its denominator
# explicitly (guard 3): a share of ALL TREATED PATIENTS (L2), never of
# remission, response or track. The value is NA because pi_cure is swept,
# never assumed -- SPEC.md section 5 places no prior on it, and any function
# needing one takes it as a required argument. What is asserted here is the
# denominator, which is the thing that has twice been got wrong.
pi_cure <- with_denominator(NA_real_, "all_treated")

#' Convert a continuous annual relapse hazard to the equivalent probability
#' over one 2-week cycle. `h` is a hazard that runs forever (SPEC.md section
#' 7's `exp(-h*t)`), not a one-time year-one event.
relapse_hazard_per_year_to_prob_2wk <- function(h_per_year, cycles_per_year = ALIYEV_CYCLES_PER_YEAR) {
  1 - exp(-h_per_year / cycles_per_year)
}

#' Discounted cost and QALYs of a full standard-care course (induction +
#' maintenance, to age 100) begun at each integer age on `ages`, each
#' discounted to that patient's own start. Costs and QALYs are returned
#' separately so a willingness-to-pay sweep needs no re-simulation.
#'
#' This is the analytic accounting device that lets the Treg arm hand a
#' relapsing or non-responding patient to the comparator engine at any
#' cycle: their whole future is one already-T7-verified comparator run,
#' rather than a second Markov re-implemented here with its own 2-year cap
#' clock running from their own start date.
standard_care_grid <- function(window_weeks, cap_on, raw_dir = "data/raw",
                                ages = seq(MODEL_START_AGE_YEARS, 100, by = 1),
                                population = "naive", product = IFX_PRICED_PRODUCT,
                                life_table_vintage = "base", therapy = "IFX") {
  cost <- numeric(length(ages))
  qaly <- numeric(length(ages))
  for (i in seq_along(ages)) {
    horizon <- 100 - ages[i]
    if (horizon <= 0) next
    tr <- run_comparator_trace(therapy, window_weeks, cap_on, horizon, raw_dir, start_age_years = ages[i], population = population, product = product, life_table_vintage = life_table_vintage)
    cost[i] <- tr$discounted_cost_usd
    qaly[i] <- tr$discounted_qaly
  }
  list(ages = ages, cost = cost, qaly = qaly)
}

#' Linear interpolation into a `standard_care_grid()` result at an arbitrary
#' age, returning discounted cost and QALYs to that patient's own start.
#'
#' THIS IS AN APPROXIMATION, NOT AN EXACT LOOKUP, and the size of it is
#' recorded here because `A` is reported to the dollar and someone
#' recomputing it at a different resolution will otherwise find an
#' unexplained gap. Discounted lifetime cost is not linear in starting age --
#' at age 46 the midpoint of the two neighbouring grid points misses the true
#' value by about $19 -- so interpolating between integer ages is wrong by an
#' amount that grows with age: measured against directly computed traces,
#' about $3 at 35 and $23 at 95 in cost, up to $255 in net monetary benefit at
#' $100,000 per QALY.
#'
#' Effect on the reported figures, measured by rebuilding the grid at
#' quarter-year steps: `A` moves about $70 (from -$2,655 to -$2,585, 2.7%),
#' `B` about $74 (0.04%), and the required cure fraction at the median
#' benchmark from 24.00% to 23.97%. `P*(1)` does not move at all -- the
#' landmark lookup is common to `A` and `B` and cancels in their sum. The
#' grid was left at one-year steps deliberately: no conclusion turns on the
#' difference, and the alternative costs 195 extra comparator runs.
#'
#' Adding a single grid point at the landmark age would recover 58% of it for
#' one extra run, since the landmark (35.2308) is the one non-integer age
#' every patient passes through and so the only lookup whose error is
#' systematic rather than averaged out. Not done, because it would supersede
#' an already-published `A` for a change no conclusion depends on.
#'
#' `T1` cannot see any of this: both routes to `A` consume the same grid, so
#' both carry the identical error and agree with each other while agreeing.
standard_care_at_age <- function(grid, age_years) {
  age <- min(max(age_years, min(grid$ages)), max(grid$ages))
  list(
    cost = approx(grid$ages, grid$cost, xout = age)$y,
    qaly = approx(grid$ages, grid$qaly, xout = age)$y
  )
}

#' Run the Treg arm at a given cure fraction and relapse hazard. Returns
#' discounted cost and QALYs over the lifetime horizon, the cycle-6
#' drug-free-remission share of the treated cohort (T4), and a per-cycle
#' state-sum log (T7).
#'
#' `sc_grid` is a `standard_care_grid()` for the same window/cap, passed in
#' rather than rebuilt per call so a 101-point `pi_cure` sweep costs one
#' grid, not 101. The POPULATION enters through that grid and through the
#' comparator, not through a parameter here: everything population-specific
#' in this arm is downstream of the landmark, and the pre-landmark window is
#' conventional-therapy MAINTENANCE dynamics, for which no refractory
#' multiplier is derivable (see R/refractory.R).
#' `life_table_vintage` must match the vintage `sc_grid` was built at, for the
#' same reason it must in `value_of_one_cure_usd()`: the post-landmark cured
#' stream here is accounted against that grid. No current caller passes
#' `pi_cure > 0` together with a non-base vintage, so the omission this
#' argument closes was latent rather than live -- at `pi_cure = 0` there is no
#' drug-free-remission mass for the table to act on.
run_treg_trace <- function(pi_cure, h_per_year, window_weeks, cap_on, sc_grid,
                            raw_dir = "data/raw", start_age_years = MODEL_START_AGE_YEARS,
                            life_table_vintage = "base") {
  stopifnot(pi_cure >= 0, pi_cure <= 1, h_per_year >= 0)

  costs <- health_state_costs_usd_per_cycle(raw_dir)
  utilities <- health_state_utilities(raw_dir)
  ct_drug_cost <- conventional_therapy_cost_usd_per_cycle(raw_dir)
  lt <- load_life_table(raw_dir, life_table_vintage)
  ct_matrix_base <- load_maintenance_matrix("CT", raw_dir)

  discounted_cost_usd <- 0
  discounted_qaly <- 0
  state_sum_log <- numeric(LANDMARK_CYCLES + round((100 - start_age_years) * ALIYEV_CYCLES_PER_YEAR))
  log_i <- 0L
  age <- start_age_years
  years_elapsed <- 0

  # --- Cycles 1-6: conventional-therapy dynamics, no biologic (L9) ---------
  # Mortality suppressed (SPEC_AMENDMENTS.md); the cohort is exactly 1 at
  # the landmark, which is what makes the L2 denominator exact.
  cohort <- setNames(numeric(length(MAINTENANCE_STATES)), MAINTENANCE_STATES)
  cohort[["Moderate-Severe"]] <- 1
  ct_matrix_no_mortality <- age_adjust_maintenance_matrix(ct_matrix_base, 0)

  for (t in seq_len(LANDMARK_CYCLES)) {
    start <- cohort
    end <- setNames(numeric(length(MAINTENANCE_STATES)), MAINTENANCE_STATES)
    for (s in MAINTENANCE_STATES) end <- end + cohort[[s]] * ct_matrix_no_mortality[s, ]
    cohort <- end

    hc <- half_cycle_weighted_occupancy(start, end)
    years_elapsed <- years_elapsed + CYCLE_YEARS
    df <- discount_factor_years_to_discount_factor(years_elapsed)
    ct_alive <- sum(hc) - hc[["Death"]]
    discounted_cost_usd <- discounted_cost_usd + (sum(hc * costs) + ct_alive * ct_drug_cost) * df
    discounted_qaly <- discounted_qaly + sum(hc * utilities) * CYCLE_YEARS * df

    log_i <- log_i + 1L; state_sum_log[log_i] <- sum(cohort)
    age <- age + CYCLE_YEARS
  }

  # --- Cycle 6: the two-fate split, on the ALL-TREATED denominator (L2) ----
  # The base is `sum(cohort)`, the entire treated cohort, not the occupancy
  # of any one state. This line is the denominator.
  treated_cohort <- sum(cohort)
  in_drug_free_remission <- pi_cure * treated_cohort
  entering_standard_care <- treated_cohort - in_drug_free_remission

  landmark_discount <- discount_factor_years_to_discount_factor(years_elapsed)
  sc_landmark <- standard_care_at_age(sc_grid, age)
  discounted_cost_usd <- discounted_cost_usd + entering_standard_care * landmark_discount * sc_landmark$cost
  discounted_qaly <- discounted_qaly + entering_standard_care * landmark_discount * sc_landmark$qaly

  cycle6_drug_free_remission_share <- in_drug_free_remission / treated_cohort

  # --- Cycles 7+: drug-free remission, leaking to relapse and to death ----
  p_relapse_2wk <- relapse_hazard_per_year_to_prob_2wk(h_per_year)
  dfr <- in_drug_free_remission
  cumulative_standard_care <- entering_standard_care
  cumulative_dead <- 0
  total_cycles <- round((100 - start_age_years) * ALIYEV_CYCLES_PER_YEAR)

  for (t in seq(LANDMARK_CYCLES + 1, total_cycles)) {
    start_dfr <- dfr
    p_death_2wk <- background_mortality_prob_2wk(age, lt)

    died <- dfr * p_death_2wk
    survivors <- dfr - died
    relapsed <- survivors * p_relapse_2wk
    dfr <- survivors - relapsed

    hc_dfr <- 0.5 * (start_dfr + dfr)
    years_elapsed <- years_elapsed + CYCLE_YEARS
    df <- discount_factor_years_to_discount_factor(years_elapsed)

    # A cured patient is drug-free but still a Crohn's patient in remission:
    # they carry Aliyev's Remission health-state cost (ambient CD-related
    # medical care, $10.20/cycle) and no drug cost of any kind.
    # SPEC_AMENDMENTS.md "Drug-free remission costing".
    discounted_cost_usd <- discounted_cost_usd + hc_dfr * costs[["Remission"]] * df
    discounted_qaly <- discounted_qaly + hc_dfr * utilities[["Remission"]] * CYCLE_YEARS * df

    # Relapsers rejoin standard care in full at this cycle (L4 + the
    # second-induction amendment), each carrying their own whole future.
    if (relapsed > 0) {
      sc <- standard_care_at_age(sc_grid, age)
      discounted_cost_usd <- discounted_cost_usd + relapsed * df * sc$cost
      discounted_qaly <- discounted_qaly + relapsed * df * sc$qaly
    }

    cumulative_standard_care <- cumulative_standard_care + relapsed
    cumulative_dead <- cumulative_dead + died
    log_i <- log_i + 1L; state_sum_log[log_i] <- dfr + cumulative_standard_care + cumulative_dead
    age <- age + CYCLE_YEARS
  }

  list(
    discounted_cost_usd = discounted_cost_usd,
    discounted_qaly = discounted_qaly,
    cycle6_drug_free_remission_share = cycle6_drug_free_remission_share,
    state_sums = state_sum_log[seq_len(log_i)],
    final_drug_free_remission = dfr
  )
}
