# T19-T21 -- alternative payment arrangements (A7), plus the module-boundary
# assertions SPEC.md's A7 amendment puts here rather than in T12.
#
# WHAT THESE THREE ARE FOR, IN ORDER OF WEIGHT. T20 is the gate, not T19.
# T19's content is "the payment arrangement did not move the model", which is
# the right thing to assert about a re-timing but is a statement about
# arithmetic A7 performs on its own output. T20 closes a loop THROUGH the
# model: a schedule derived from D(.) and a price derived from P*(.) cancel
# exactly, over the whole cohort stack, at every horizon at once, which cannot
# happen unless the offset machinery, the frontier and the cohort clock all
# agree. It is the T13 of this extension. T21 checks the contract arithmetic
# against a second route to A.
#
# WHAT IS DELIBERATELY ABSENT. There is no assertion that `offset_captured(H)`
# is invariant to the payment arrangement. It is attractive and it is vacuous:
# `offset_captured_share()` takes a cumulative offset and a lifetime offset and
# has no price argument at all, so a test asserting invariance to something the
# function cannot receive cannot fail against any implementation the design
# permits. The invariance is a definition, stated in SPEC.md section 2a. There
# is also no monotonicity assertion in the installment length N: below full
# inclusion the undiscounted figure falls with N and above it rises with N, and
# a passing monotonicity test would mean one of those two regimes had stopped
# being computed.

source_r("io_cache.R")
source_r("price_index.R")
source_derive("health_state_costs.R")
source_r("denominator.R")
source_r("units.R")
source_r("transition_matrices.R")
source_r("life_table.R")
source_r("dosing.R")
source_r("costs_utilities.R")
source_r("refractory.R")
source_r("comparator_dosing.R")
source_r("markov_engine.R")
source_r("treg_arm.R")
source_r("frontier.R")
source_r("analog_comparison.R")
source_r("budget_impact.R")
source_r("payment_arrangements.R")

RAW_DIR <- repo_root_relative("data", "raw")
LIFETIME_YEARS <- 100 - MODEL_START_AGE_YEARS
REPORTED_HORIZONS_YEARS <- c(1, 3, 5, 10, 30)
HAZARDS_PER_YEAR <- c(0, 0.05, 0.10)
LAMBDAS_USD_PER_QALY <- c(5e4, 1e5, 1.5e5)
INSTALLMENT_LENGTHS_YEARS <- c(3, 5)
RAMP <- BIA_UPTAKE_RAMP_PERIOD_YEARS
ANALYSIS_RATE_PER_YEAR <- DISCOUNT_RATE_PER_YEAR
INTEREST_FREE_RATE_PER_YEAR <- 0
OBSERVATION_LADDER_YEARS <- c(0, 2, 5)
REBATE_LADDER <- c(0, 0.25, 0.50, 1.00)

COMBINATIONS <- list(
  list(window = 8, cap_on = TRUE),
  list(window = 8, cap_on = FALSE)
)
label_of <- function(cmb) sprintf("window=%s cap=%s", cmb$window, cmb$cap_on)

GRIDS <- lapply(COMBINATIONS, function(cmb) standard_care_grid(cmb$window, cmb$cap_on, RAW_DIR))
STREAM_GRIDS <- lapply(COMBINATIONS, function(cmb) standard_care_cost_stream_grid(cmb$window, cmb$cap_on, RAW_DIR))
COMPARATORS <- lapply(COMBINATIONS, function(cmb) {
  run_comparator_trace("IFX", cmb$window, cmb$cap_on, LIFETIME_YEARS, RAW_DIR)
})

# The undiscounted leg is the same computation at a zero rate, not the same
# numbers read differently -- `analysis/run_bia.R`'s own idiom, and the reason
# an installment stream must be BUILT inside the block as well as summed there:
# its analysis-rate factor is read from the rate in force, while its annuity
# factor is a contract term and is not.
with_zero_discounting <- function(expr) {
  old <- getOption("treg_value.discount_rate")
  options(treg_value.discount_rate = 0)
  on.exit(options(treg_value.discount_rate = old), add = TRUE)
  force(expr)
}
at_rate_in_force <- function(discounted, expr) if (discounted) expr else with_zero_discounting(expr)

ELIGIBLE_PATIENTS <- 1e5
TERMINAL_UPTAKE <- 0.25
NEWLY <- uptake_newly_treated_patients(ELIGIBLE_PATIENTS, TERMINAL_UPTAKE)
ONE_PATIENT <- 1
PRICE <- 5e4

treg_trace_at <- function(i, pi_cure_value, h, discounted = TRUE) {
  cmb <- COMBINATIONS[[i]]
  if (discounted) {
    return(run_treg_trace(pi_cure_value, h, cmb$window, cmb$cap_on, GRIDS[[i]], RAW_DIR,
      sc_cost_stream_grid = STREAM_GRIDS[[i]])$discounted_cost_stream_usd)
  }
  with_zero_discounting({
    zero_grid <- standard_care_grid(cmb$window, cmb$cap_on, RAW_DIR)
    zero_stream_grid <- standard_care_cost_stream_grid(cmb$window, cmb$cap_on, RAW_DIR)
    run_treg_trace(pi_cure_value, h, cmb$window, cmb$cap_on, zero_grid, RAW_DIR,
      sc_cost_stream_grid = zero_stream_grid)$discounted_cost_stream_usd
  })
}

net_total_usd <- function(price_stream, treg_stream, comparator_stream, newly, horizon) {
  treg_annual <- truncated_cost_usd_per_year(treg_stream, horizon)
  comparator_annual <- truncated_cost_usd_per_year(comparator_stream, horizon)
  sum(net_budget_impact_usd_per_year(
    arrangement_expenditure_usd_per_year(price_stream, treg_annual, newly, horizon),
    current_care_expenditure_usd_per_year(comparator_annual, newly, horizon)))
}

price_leg_usd <- function(price_stream, newly, horizon) {
  sum(stacked_cohort_expenditure_usd_per_year(price_stream, newly, horizon))
}

# T19(b)'s independent route: the lump-minus-installment difference computed
# from the schedule, the two rates and the uptake vector alone. No cost stream
# is touched, and the arithmetic is written out rather than routed through the
# module, so a bug in the module cannot make this agree with it.
#
# `truncation` is the falsification switch: "per_cohort" is the correct index
# `H - k + 1`, "horizon" is the single-cohort algebra applied to all five
# cohorts, which is the error this criterion exists to catch.
installment_delta_usd <- function(price, newly, horizon, installment_years, contract_rate,
                                  analysis_rate, truncation = "per_cohort") {
  annuity <- sum((1 + contract_rate)^-(seq_len(installment_years) - 1))
  total <- 0
  for (k in seq_len(min(length(newly), horizon))) {
    span <- if (truncation == "per_cohort") min(installment_years, horizon - k + 1) else min(installment_years, horizon)
    total <- total + newly[k] * (1 + analysis_rate)^-(k - 1) *
      (1 - sum((1 + analysis_rate)^-(seq_len(span) - 1)) / annuity)
  }
  price * total
}

# The trap-1 bug, built once so both T19(b) and T19(d) can be seen to fail
# against it: the annuity factor computed from the rate in force instead of
# from the contract term. It ignores `contract_rate` entirely -- which is the
# point, and why all four cells of T19(d) collapse rather than two of them.
buggy_installment_stream <- function(price, installment_years, contract_rate) {
  annuity <- sum(discount_factor_years_to_discount_factor(seq_len(installment_years) - 1))
  (price / annuity) * discount_factor_years_to_discount_factor(seq_len(installment_years) - 1)
}

# ---------------------------------------------------------------- T19 ------

test_that("T19(a): a present-value-neutral installment leaves the discounted figure unchanged once every cohort's schedule is inside the window", {
  # The bound is `ramp + N - 1`, not `N`: the last cohort adopts in year 5 and
  # its schedule runs to year `5 + N - 1`. Asserted over the FULL UPTAKE RAMP,
  # which is the whole of the correction -- the single-cohort version of this
  # statement is true at `H >= N` and generalises to nothing.
  for (i in seq_along(COMBINATIONS)) {
    cmb <- COMBINATIONS[[i]]
    for (h in c(0, 0.05)) {
      treg <- treg_trace_at(i, 0.5, h)
      comparator <- COMPARATORS[[i]]$discounted_cost_stream_usd
      lump <- vapply(REPORTED_HORIZONS_YEARS, function(hz) {
        net_total_usd(PRICE, treg, comparator, NEWLY, hz)
      }, numeric(1))
      for (n in INSTALLMENT_LENGTHS_YEARS) {
        stream <- installment_price_stream_usd_per_year(PRICE, n, ANALYSIS_RATE_PER_YEAR)
        full_inclusion <- RAMP + n - 1
        for (j in seq_along(REPORTED_HORIZONS_YEARS)) {
          hz <- REPORTED_HORIZONS_YEARS[j]
          if (hz < full_inclusion) next
          expect_lt(abs(net_total_usd(stream, treg, comparator, NEWLY, hz) - lump[j]), 0.01,
            label = sprintf("%s h=%s N=%s H=%s", label_of(cmb), h, n, hz))
        }
      }
    }
  }
})

test_that("T19(a): on the lifetime leg T13's identity survives the installment, on the single-cohort fixture", {
  # A present-value-neutral schedule is present-value-neutral: at the analysis
  # rate the annuity factor divides out and the whole price is charged at t = 0
  # in present value, so `price - P*(pi, h, lambda = 0)` still holds.
  for (i in seq_along(COMBINATIONS)) {
    cmb <- COMBINATIONS[[i]]
    for (h in HAZARDS_PER_YEAR) {
      for (p in c(0.25, 1)) {
        treg <- treg_trace_at(i, p, h)
        frontier_route <- PRICE - price_star_usd_per_course(p, h, 0, COMPARATORS[[i]],
          GRIDS[[i]], cmb$window, cmb$cap_on, RAW_DIR)
        for (n in INSTALLMENT_LENGTHS_YEARS) {
          stream <- installment_price_stream_usd_per_year(PRICE, n, ANALYSIS_RATE_PER_YEAR)
          bia_route <- net_total_usd(stream, treg, COMPARATORS[[i]]$discounted_cost_stream_usd,
            ONE_PATIENT, Inf)
          expect_lt(abs(bia_route - frontier_route), 1,
            label = sprintf("%s pi=%s h=%s N=%s", label_of(cmb), p, h, n))
        }
      }
    }
  }
})

test_that("T19(b): the lump-minus-installment difference equals the per-cohort closed form at every horizon, on both discounting legs", {
  i <- 1
  cmb <- COMBINATIONS[[i]]
  h <- 0.05
  worst <- 0
  for (discounted in c(TRUE, FALSE)) {
    treg <- treg_trace_at(i, 0.5, h, discounted)
    comparator <- if (discounted) {
      COMPARATORS[[i]]$discounted_cost_stream_usd
    } else {
      COMPARATORS[[i]]$undiscounted_cost_stream_usd
    }
    analysis_rate <- if (discounted) ANALYSIS_RATE_PER_YEAR else 0
    for (contract_rate in c(ANALYSIS_RATE_PER_YEAR, INTEREST_FREE_RATE_PER_YEAR)) {
      for (n in INSTALLMENT_LENGTHS_YEARS) {
        for (hz in REPORTED_HORIZONS_YEARS) {
          delta <- at_rate_in_force(discounted, {
            stream <- installment_price_stream_usd_per_year(PRICE, n, contract_rate)
            net_total_usd(PRICE, treg, comparator, NEWLY, hz) -
              net_total_usd(stream, treg, comparator, NEWLY, hz)
          })
          independent <- installment_delta_usd(PRICE, NEWLY, hz, n, contract_rate, analysis_rate)
          expect_lt(abs(delta - independent), 0.01,
            label = sprintf("%s disc=%s r_c=%s N=%s H=%s", label_of(cmb), discounted, contract_rate, n, hz))
          worst <- max(worst, abs(delta - independent))
        }
      }
    }
  }
  expect_lt(worst, 0.01)
})

test_that("T19(b) fires: the single-cohort truncation index fails at the 3- and 5-year rows and CANNOT fail at 1 year", {
  # Risk 3 in this extension's own risk register: a session re-derives T19 for
  # one cohort, the algebra is one line, and nothing about it announces that it
  # does not generalise. The falsification fixture is that error exactly.
  #
  # It cannot fail at H = 1, where only cohort 1 exists and `H - k + 1 = H`
  # makes the two expressions the same number; nor at H >= ramp + N - 1, where
  # every cohort's span has saturated at N and the two agree again. A session
  # expecting failure everywhere would not know whether the fixture or the
  # implementation was wrong, and might "fix" a correct implementation.
  i <- 1
  h <- 0.05
  treg <- treg_trace_at(i, 0.5, h)
  comparator <- COMPARATORS[[i]]$discounted_cost_stream_usd
  n <- 5
  stream <- installment_price_stream_usd_per_year(PRICE, n, ANALYSIS_RATE_PER_YEAR)
  for (hz in REPORTED_HORIZONS_YEARS) {
    delta <- net_total_usd(PRICE, treg, comparator, NEWLY, hz) -
      net_total_usd(stream, treg, comparator, NEWLY, hz)
    wrong <- installment_delta_usd(PRICE, NEWLY, hz, n, ANALYSIS_RATE_PER_YEAR,
      ANALYSIS_RATE_PER_YEAR, truncation = "horizon")
    if (hz > 1 && hz < RAMP + n - 1) {
      expect_gt(abs(delta - wrong), 0.01, label = sprintf("must fail at H=%s", hz))
    } else {
      expect_lt(abs(delta - wrong), 0.01, label = sprintf("cannot fail at H=%s", hz))
    }
  }
})

test_that("T19(c): the difference as a share of the price carries no term from the disease model", {
  # Stated over `Delta(H)/price`, because `Delta` itself is proportional to the
  # price and A7's own price axis is `P*(pi, h, lambda)`, which spans more than
  # fourteen-fold across these cells. The ratio holds on both price axes; the
  # DOLLAR identity is asserted separately and only on the analog axis, where
  # the price is a single scalar.
  # TWO CONTRACT RATES, and the second is not decoration. At full inclusion a
  # present-value-neutral schedule has `Delta` identically ZERO on the
  # discounted leg, so a RELATIVE deviation there is 0/0 and says nothing; the
  # interest-free contract keeps the 10-year row non-degenerate. The invariance
  # is therefore asserted against the scale `Delta/price` actually carries --
  # discounted treated patients, so `sum(NEWLY)` -- which is well defined at
  # every horizon including the one where the quantity vanishes.
  n <- 5
  hz_grid <- c(3, 5, 10)
  contract_rates <- c(ANALYSIS_RATE_PER_YEAR, INTEREST_FREE_RATE_PER_YEAR)
  cells <- expand.grid(h = seq_along(hz_grid), r = seq_along(contract_rates))
  ratios <- vector("list", nrow(cells))
  analog_dollars <- vector("list", nrow(cells))
  slot_of <- function(j, m) which(cells$h == j & cells$r == m)
  analogs <- read.csv(file.path(RAW_DIR, "cell_therapy_revealed_prices_2025.csv"), stringsAsFactors = FALSE)
  analog_price <- median(analogs$us_list_price_usd, na.rm = TRUE)
  for (i in seq_along(COMBINATIONS)) {
    cmb <- COMBINATIONS[[i]]
    for (h in c(0, 0.10)) {
      for (p in c(0.25, 1)) {
        treg <- treg_trace_at(i, p, h)
        comparator <- COMPARATORS[[i]]$discounted_cost_stream_usd
        prices <- c(vapply(LAMBDAS_USD_PER_QALY, function(lam) {
          price_star_usd_per_course(p, h, lam, COMPARATORS[[i]], GRIDS[[i]],
            cmb$window, cmb$cap_on, RAW_DIR)
        }, numeric(1)), analog_price)
        for (pm in seq_along(prices)) {
          price <- prices[pm]
          for (rm in seq_along(contract_rates)) {
            stream <- installment_price_stream_usd_per_year(price, n, contract_rates[rm])
            for (j in seq_along(hz_grid)) {
              hz <- hz_grid[j]
              delta <- net_total_usd(price, treg, comparator, NEWLY, hz) -
                net_total_usd(stream, treg, comparator, NEWLY, hz)
              slot <- slot_of(j, rm)
              ratios[[slot]] <- c(ratios[[slot]], delta / price)
              # The dollar identity is the analog axis's alone: that axis is a
              # single scalar median list price, so a dollar figure invariant
              # across the disease grid there says nothing about the frontier
              # axis, where the price varies with every cell.
              if (pm == length(prices)) analog_dollars[[slot]] <- c(analog_dollars[[slot]], delta)
            }
          }
        }
      }
    }
  }
  degenerate <- 0
  for (slot in seq_len(nrow(cells))) {
    lab <- sprintf("H=%s r_c=%s", hz_grid[cells$h[slot]], contract_rates[cells$r[slot]])
    r <- ratios[[slot]]
    expect_gt(length(r), 1)
    expect_lt(max(abs(r - r[1])) / sum(NEWLY), 1e-10, label = sprintf("ratio at %s", lab))
    # The dollar form, on the analog axis and only there.
    d <- analog_dollars[[slot]]
    expect_lt(max(abs(d - d[1])), 0.01, label = sprintf("analog dollars at %s", lab))
    if (max(abs(r)) / sum(NEWLY) < 1e-10) degenerate <- degenerate + 1
  }
  # Exactly one cell is degenerate -- the 10-year, present-value-neutral one,
  # where the whole schedule is inside the window for every cohort and the
  # difference is identically zero. Pinned so that a future change making
  # every cell vanish, which would satisfy every assertion above, is caught.
  expect_equal(degenerate, 1)
})

test_that("T19(c): the price axis these ratios are invariant across spans more than fourteen-fold", {
  # The clause that stops T19(c) being vacuous. If every cell carried the same
  # price, a dollar identity and a ratio identity would be the same claim.
  i <- 1
  cmb <- COMBINATIONS[[i]]
  prices <- numeric(0)
  for (h in HAZARDS_PER_YEAR) {
    for (p in c(0.25, 0.5, 1)) {
      prices <- c(prices, price_star_usd_per_course(p, h, 1e5, COMPARATORS[[i]], GRIDS[[i]],
        cmb$window, cmb$cap_on, RAW_DIR))
    }
  }
  expect_gt(max(prices) / min(prices), 14)
})

test_that("T19(d): the four cells separate a re-timing from a price cut, and each is invisible in one column", {
  # Two schedules, two columns, four cells, read on the PRICE LEG at each
  # schedule's own full-inclusion horizon. A present-value-neutral schedule is
  # exactly nothing on the discounted column and the financing charge
  # `N/a_c - 1` on the undiscounted one; an interest-free schedule is exactly
  # nothing on the undiscounted column and an equivalent per-course discount
  # `1 - a_a/N` on the discounted one. A payer shown one column is being shown
  # a schedule that looks free, which is a better argument for L11's
  # both-columns rule than L11 itself makes.
  i <- 1
  treg <- list(disc = treg_trace_at(i, 0.5, 0.05, TRUE), undisc = treg_trace_at(i, 0.5, 0.05, FALSE))
  comparator <- list(disc = COMPARATORS[[i]]$discounted_cost_stream_usd,
    undisc = COMPARATORS[[i]]$undiscounted_cost_stream_usd)
  for (n in INSTALLMENT_LENGTHS_YEARS) {
    hz <- RAMP + n - 1
    annuity_contract <- sum((1 + ANALYSIS_RATE_PER_YEAR)^-(seq_len(n) - 1))
    for (contract_rate in c(ANALYSIS_RATE_PER_YEAR, INTEREST_FREE_RATE_PER_YEAR)) {
      for (discounted in c(TRUE, FALSE)) {
        ratio <- at_rate_in_force(discounted, {
          stream <- installment_price_stream_usd_per_year(PRICE, n, contract_rate)
          price_leg_usd(stream, NEWLY, hz) / price_leg_usd(PRICE, NEWLY, hz)
        })
        expected <- if (contract_rate == ANALYSIS_RATE_PER_YEAR) {
          if (discounted) 1 else n / annuity_contract
        } else {
          if (discounted) annuity_contract / n else 1
        }
        expect_lt(abs(ratio - expected), 1e-9,
          label = sprintf("N=%s r_c=%s disc=%s", n, contract_rate, discounted))
        # And the net budget impact is unchanged to the cent in whichever
        # column the arrangement is invisible in.
        if (abs(expected - 1) < 1e-12) {
          net <- at_rate_in_force(discounted, {
            stream <- installment_price_stream_usd_per_year(PRICE, n, contract_rate)
            net_total_usd(stream, treg[[if (discounted) "disc" else "undisc"]],
              comparator[[if (discounted) "disc" else "undisc"]], NEWLY, hz) -
              net_total_usd(PRICE, treg[[if (discounted) "disc" else "undisc"]],
                comparator[[if (discounted) "disc" else "undisc"]], NEWLY, hz)
          })
          expect_lt(abs(net), 0.01, label = sprintf("net N=%s r_c=%s disc=%s", n, contract_rate, discounted))
        }
      }
    }
  }
})

test_that("T19(d) fires: an annuity built from the rate in force collapses all four cells AND breaks T19(b)", {
  # Trap 1. The bug makes the module ignore the contract term altogether, so
  # the two contracts become one: on the discounted leg `a_c` becomes the
  # analysis annuity and on the undiscounted leg it becomes N, WHICHEVER
  # contract was requested. All four cells read 0.0% and the table lands on the
  # origin -- not one cell on top of another.
  #
  # Both clauses must be SEEN to fail. A session told that only (d) catches
  # this would read a green (b) as evidence the bug is absent.
  i <- 1
  n <- 5
  hz <- RAMP + n - 1
  treg <- list(disc = treg_trace_at(i, 0.5, 0.05, TRUE), undisc = treg_trace_at(i, 0.5, 0.05, FALSE))
  comparator <- list(disc = COMPARATORS[[i]]$discounted_cost_stream_usd,
    undisc = COMPARATORS[[i]]$undiscounted_cost_stream_usd)
  collapsed <- 0
  for (contract_rate in c(ANALYSIS_RATE_PER_YEAR, INTEREST_FREE_RATE_PER_YEAR)) {
    for (discounted in c(TRUE, FALSE)) {
      key <- if (discounted) "disc" else "undisc"
      ratio <- at_rate_in_force(discounted, {
        price_leg_usd(buggy_installment_stream(PRICE, n, contract_rate), NEWLY, hz) /
          price_leg_usd(PRICE, NEWLY, hz)
      })
      # (d) fails: every cell reads exactly no change, whichever contract.
      expect_lt(abs(ratio - 1), 1e-9, label = sprintf("collapsed cell r_c=%s disc=%s", contract_rate, discounted))
      collapsed <- collapsed + 1

      # (b) fails too, on the undiscounted leg for the present-value-neutral
      # contract and on the discounted leg for the interest-free one.
      analysis_rate <- if (discounted) ANALYSIS_RATE_PER_YEAR else 0
      delta <- at_rate_in_force(discounted, {
        net_total_usd(PRICE, treg[[key]], comparator[[key]], NEWLY, hz) -
          net_total_usd(buggy_installment_stream(PRICE, n, contract_rate), treg[[key]],
            comparator[[key]], NEWLY, hz)
      })
      independent <- installment_delta_usd(PRICE, NEWLY, hz, n, contract_rate, analysis_rate)
      contract_is_pv_neutral <- contract_rate == ANALYSIS_RATE_PER_YEAR
      if (xor(contract_is_pv_neutral, discounted)) {
        expect_gt(abs(delta - independent), 0.01,
          label = sprintf("T19(b) must fail r_c=%s disc=%s", contract_rate, discounted))
      }
    }
  }
  expect_equal(collapsed, 4)

  # (a) and (c) still pass under the bug, which is why (d) is the clause that
  # NAMES what went wrong: at full inclusion the buggy discounted leg is still
  # present-value-neutral, and the ratio is still free of the disease model.
  stream <- buggy_installment_stream(PRICE, n, INTEREST_FREE_RATE_PER_YEAR)
  expect_lt(abs(net_total_usd(stream, treg$disc, comparator$disc, NEWLY, hz) -
    net_total_usd(PRICE, treg$disc, comparator$disc, NEWLY, hz)), 0.01)
})

# ---------------------------------------------------------------- T20 ------

offset_fixture <- function(i, pi_cure_value, h) {
  cmb <- COMBINATIONS[[i]]
  treg <- treg_trace_at(i, pi_cure_value, h)
  comparator <- COMPARATORS[[i]]$discounted_cost_stream_usd
  lifetime_offset <- price_star_usd_per_course(pi_cure_value, h, 0, COMPARATORS[[i]],
    GRIDS[[i]], cmb$window, cmb$cap_on, RAW_DIR)
  increments <- offset_increment_usd_per_year(cost_offset_per_patient_usd(
    truncated_cost_usd_per_year(comparator, Inf), truncated_cost_usd_per_year(treg, Inf)))
  list(treg = treg, comparator = comparator, lifetime_offset = lifetime_offset,
    increments = increments)
}

stacked_offset_usd <- function(fx, newly, horizon) {
  sum(current_care_expenditure_usd_per_year(
    truncated_cost_usd_per_year(fx$comparator, horizon), newly, horizon)) -
    sum(stacked_cohort_expenditure_usd_per_year(
      truncated_cost_usd_per_year(fx$treg, horizon), newly, horizon))
}

test_that("T20: the offset-matched schedule makes a justified cure budget-neutral at every reported horizon at once, over the whole cohort stack", {
  # A6's own headline progression, read as a distribution over payment timing.
  # The identity closes at every horizon SIMULTANEOUSLY because the schedule is
  # proportional to the offset cohort by cohort, so the two are truncated at
  # the same index `H - k + 1` -- the per-cohort clock that broke T19's algebra
  # is the clock that makes this one work. Discounted leg only: D(lifetime) is
  # `P*(pi, h, lambda = 0)`, a present value at t = 0, so the schedule is not
  # defined on the undiscounted column at all.
  worst <- 0
  for (i in seq_along(COMBINATIONS)) {
    cmb <- COMBINATIONS[[i]]
    for (h in HAZARDS_PER_YEAR) {
      for (p in c(0.25, 1)) {
        fx <- offset_fixture(i, p, h)
        expect_gt(fx$lifetime_offset, 0) # the domain restriction, not inherited by accident
        for (newly in list(NEWLY, uptake_newly_treated_patients(1e3, 1), ONE_PATIENT)) {
          for (price in c(fx$lifetime_offset, PRICE)) {
            stream <- offset_matched_price_stream_usd_per_year(price, fx$increments, fx$lifetime_offset)
            for (hz in REPORTED_HORIZONS_YEARS) {
              model <- net_total_usd(stream, fx$treg, fx$comparator, newly, hz)
              independent <- (price / fx$lifetime_offset - 1) * stacked_offset_usd(fx, newly, hz)
              expect_lt(abs(model - independent), 0.01,
                label = sprintf("%s pi=%s h=%s H=%s", label_of(cmb), p, h, hz))
              worst <- max(worst, abs(model - independent))
              if (identical(price, fx$lifetime_offset)) {
                expect_lt(abs(model), 0.01,
                  label = sprintf("zero at %s pi=%s h=%s H=%s", label_of(cmb), p, h, hz))
              }
            }
          }
        }
      }
    }
  }
  expect_lt(worst, 0.01)
})

test_that("T20: the schedule is not clipped on the lifetime leg, and IS truncated per cohort at every finite horizon", {
  # Trap 5, in both directions. On the lifetime leg the stacker derives its
  # calendar from the COST stream, so a schedule longer than that stream loses
  # its last cohort's tail silently; the offset-matched schedule's length
  # EQUALS the cost stream's, so the margin is exactly zero and is asserted
  # rather than left to luck. At a finite horizon the opposite is the claim,
  # and it is the clause with content: truncation at `H - k + 1` is the
  # mechanism the identity above depends on, so the assertion is that it
  # happened, not that it did not.
  i <- 1
  fx <- offset_fixture(i, 0.5, 0.05)
  schedule_length <- length(fx$increments)
  cost_stream_length <- length(truncated_cost_usd_per_year(fx$treg, Inf))
  expect_lte(length(NEWLY) - 1 + schedule_length, length(NEWLY) - 1 + cost_stream_length)
  expect_lte(schedule_length, cost_stream_length)

  indicator <- rep(1, schedule_length)
  for (hz in REPORTED_HORIZONS_YEARS) {
    for (k in seq_along(NEWLY)) {
      one_cohort <- numeric(length(NEWLY))
      one_cohort[k] <- 1
      placed <- stacked_cohort_expenditure_usd_per_year(indicator, one_cohort, hz)
      expect_length(placed, hz)
      expect_identical(sum(placed > 0), as.integer(max(0, min(hz - k + 1, schedule_length))),
        label = sprintf("cohort %s at H=%s", k, hz))
    }
  }
})

test_that("T20: every annual offset increment is non-negative on the reported grid, at every committed cure fraction", {
  # Checked, not assumed, and scoped to the grid it was checked on.
  # `offset_captured_share()`'s own docstring declines to assert monotonicity
  # or an upper bound, so the schedule is NOT a cumulative distribution
  # function and this test does not say it is. Beyond the reported grid the
  # increments do go negative -- the schedule would pay a negative amount, the
  # payer receiving money back that year -- and at a cure fraction of zero they
  # are negative inside it, which is one reason the domain restriction
  # `D(lifetime) > 0` is stated separately.
  for (i in seq_along(COMBINATIONS)) {
    for (h in HAZARDS_PER_YEAR) {
      for (p in c(0.25, 0.5, 0.75, 1)) {
        fx <- offset_fixture(i, p, h)
        expect_true(all(fx$increments[seq_len(max(REPORTED_HORIZONS_YEARS))] >= 0),
          label = sprintf("%s pi=%s h=%s", label_of(COMBINATIONS[[i]]), p, h))
      }
    }
  }
})

test_that("T20 fires: shifting the schedule by a year, or discounting it twice, breaks the identity at every horizon", {
  i <- 1
  fx <- offset_fixture(i, 0.5, 0.05)
  price <- fx$lifetime_offset
  correct <- offset_matched_price_stream_usd_per_year(price, fx$increments, fx$lifetime_offset)
  shifted <- c(0, correct[-length(correct)])
  # Trap 3: the offset increments arrive ALREADY discounted, so a second
  # analysis-rate factor is the error that looks like a rounding problem.
  double_discounted <- correct * discount_factor_years_to_discount_factor(seq_along(correct) - 1)
  for (hz in REPORTED_HORIZONS_YEARS) {
    independent <- (price / fx$lifetime_offset - 1) * stacked_offset_usd(fx, NEWLY, hz)
    expect_gt(abs(net_total_usd(shifted, fx$treg, fx$comparator, NEWLY, hz) - independent), 0.01,
      label = sprintf("shift at H=%s", hz))
    # The second-discount arm cannot fail at H = 1, for the same structural
    # reason T19(b)'s fixture cannot: at a one-year window only cohort 1
    # exists and contributes only its own first element, whose extra factor is
    # `v^0 = 1`. Asserted in the direction it holds rather than expected to
    # fail everywhere, so a session reading a green H = 1 row knows why.
    deviation <- abs(net_total_usd(double_discounted, fx$treg, fx$comparator, NEWLY, hz) - independent)
    if (hz > 1) {
      expect_gt(deviation, 0.01, label = sprintf("double discount at H=%s", hz))
    } else {
      expect_lt(deviation, 0.01, label = "double discount cannot fail at H=1")
    }
  }
})

test_that("T20 fires: truncating the schedule short of its last money-carrying year breaks the lifetime leg and no finite horizon", {
  # DEPARTURE FROM THE LETTER OF THE CRITERION, and the reason is a fact about
  # this repository's streams rather than a weakening. The criterion asks for a
  # schedule "one element short". The Treg arm's annual stream runs 131 years
  # while its last non-zero year is 67, so the offset-matched schedule carries
  # sixty-four trailing EXACT zeros and dropping one of them is arithmetically
  # nothing -- the literal fixture cannot fail, which would make a green result
  # meaningless. The clipping hazard trap 5 exists for is a lost TAIL, so the
  # fixture drops the last element that carries money. The structural margin
  # the criterion is really about -- schedule length equal to cost-stream
  # length, zero slack -- is asserted positively in the clipping test above.
  i <- 1
  fx <- offset_fixture(i, 0.5, 0.05)
  price <- fx$lifetime_offset
  correct <- offset_matched_price_stream_usd_per_year(price, fx$increments, fx$lifetime_offset)
  last_paying <- max(which(correct != 0))
  expect_lt(last_paying, length(correct)) # the trailing zeros the departure turns on
  short <- correct[seq_len(last_paying - 1)]

  lifetime_independent <- (price / fx$lifetime_offset - 1) * stacked_offset_usd(fx, NEWLY, Inf)
  expect_gt(abs(net_total_usd(short, fx$treg, fx$comparator, NEWLY, Inf) - lifetime_independent), 0.01)
  for (hz in REPORTED_HORIZONS_YEARS) {
    independent <- (price / fx$lifetime_offset - 1) * stacked_offset_usd(fx, NEWLY, hz)
    expect_lt(abs(net_total_usd(short, fx$treg, fx$comparator, NEWLY, hz) - independent), 0.01,
      label = sprintf("finite horizon unaffected at H=%s", hz))
  }
})

# ---------------------------------------------------------------- T21 ------

test_that("T21(a): the present value of the outcomes-based price leg matches L21's closed form at every point of the rebate and observation ladders", {
  for (i in seq_along(COMBINATIONS)) {
    cmb <- COMBINATIONS[[i]]
    for (h in HAZARDS_PER_YEAR) {
      for (p in c(0.25, 0.5, 1)) {
        for (rho in REBATE_LADDER) {
          for (t in OBSERVATION_LADDER_YEARS) {
            stream <- outcomes_based_price_stream_usd_per_year(PRICE, p, h, rho, t)
            model <- price_leg_usd(stream, ONE_PATIENT, Inf)
            tau <- t + 12 / 52
            independent <- PRICE * (1 - rho * (1 - p * exp(-h * t)) * (1 + ANALYSIS_RATE_PER_YEAR)^-tau)
            expect_lt(abs(model - independent), 0.01,
              label = sprintf("%s pi=%s h=%s rho=%s T=%s", label_of(cmb), p, h, rho, t))
          }
        }
      }
    }
  }
})

test_that("T21(a): the settlement date is the landmark's own offset from adoption, and the rebate lands on the calendar", {
  # L21's clock, read off the model rather than written as a constant.
  expect_equal(rebate_settlement_years(0), LANDMARK_CYCLES * CYCLE_YEARS)
  expect_equal(rebate_settlement_years(0), 12 / 52)
  for (t in OBSERVATION_LADDER_YEARS) {
    stream <- outcomes_based_price_stream_usd_per_year(PRICE, 0.5, 0.05, 1, t)
    expect_length(stream, floor(rebate_settlement_years(t)) + 1)
    expect_equal(stream[1], if (t == 0) sum(stream) else PRICE)
  }
})

test_that("T21(a) fires: placing the rebate at index 1, or dropping its discount factor, is caught", {
  # TWO DIFFERENT BUGS, and they are caught in two different places, which is
  # worth being explicit about.
  #
  # Dropping `v^tau` changes the SUM, so it fails the closed-form comparison at
  # every observation point including the landmark, where the factor is still
  # 0.68% -- the same 0.68% a `B` discounted to the landmark once cost this
  # study, and the reason L21 refuses a coincident-settlement approximation for
  # tidiness.
  #
  # Placing the rebate at index 1 does NOT change the sum, because the cohort
  # stacker applies only the cohort's own adoption-year factor and does not
  # discount within a stream. It is invisible on the lifetime leg by
  # construction and shows up where it matters: inside a reporting window
  # shorter than the settlement lag, where the correct implementation shows the
  # whole price and none of the rebate. That is trap 2's finding stated as a
  # test -- a one-year budget impact of a two-year-observation contract.
  p <- 0.5
  h <- 0.05
  i <- 1
  for (t in OBSERVATION_LADDER_YEARS) {
    tau <- t + 12 / 52
    undiscounted_rebate <- PRICE * (1 - 1 * (1 - p * exp(-h * t)) * 1)
    correct <- price_leg_usd(outcomes_based_price_stream_usd_per_year(PRICE, p, h, 1, t),
      ONE_PATIENT, Inf)
    expect_gt(abs(correct - undiscounted_rebate), 0.01, label = sprintf("v^tau at T=%s", t))
  }
  for (t in OBSERVATION_LADDER_YEARS[OBSERVATION_LADDER_YEARS > 0]) {
    correct_stream <- outcomes_based_price_stream_usd_per_year(PRICE, p, h, 1, t)
    at_index_one <- c(sum(correct_stream), numeric(length(correct_stream) - 1))
    inside_lag <- 1
    expect_equal(price_leg_usd(correct_stream, ONE_PATIENT, inside_lag), PRICE)
    expect_gt(abs(price_leg_usd(at_index_one, ONE_PATIENT, inside_lag) - PRICE), 0.01,
      label = sprintf("index at T=%s", t))
    # And over the cohort stack, where the same placement decides which
    # cohorts' rebates a window contains at all.
    expect_gt(abs(price_leg_usd(correct_stream, NEWLY, 3) - price_leg_usd(at_index_one, NEWLY, 3)), 0.01,
      label = sprintf("stacked at T=%s", t))
  }
})

test_that("T21(b): net budget impact stays affine in the cure fraction under an outcomes-based contract, and the risk-transfer slope is exactly zero at q_flat", {
  # The contract rotates the line; it does not bend it. Payment enters the
  # budget linearly in the individual outcome indicator, so the cohort-share
  # formulation is exact and T14's affinity survives (L18).
  i <- 1
  cmb <- COMBINATIONS[[i]]
  comparator <- COMPARATORS[[i]]$discounted_cost_stream_usd
  h_affine <- 0.05
  pi_grid <- seq(0, 1, length.out = 101)
  streams <- lapply(pi_grid, function(p) treg_trace_at(i, p, h_affine))
  for (rho in c(0.5, 1)) {
    for (t in OBSERVATION_LADDER_YEARS) {
      net <- vapply(seq_along(pi_grid), function(j) {
        stream <- outcomes_based_price_stream_usd_per_year(PRICE, pi_grid[j], h_affine, rho, t)
        net_total_usd(stream, streams[[j]], comparator, ONE_PATIENT, Inf)
      }, numeric(1))
      fitted <- net[1] + pi_grid * (net[length(net)] - net[1])
      expect_lt(max(abs(net - fitted)), 0.01, label = sprintf("affine rho=%s T=%s", rho, t))
      # The slope, against the closed form.
      tau <- t + 12 / 52
      slope_b <- value_of_one_cure_usd(h_affine, 0, GRIDS[[i]], RAW_DIR)
      expected_slope <- PRICE * rho * exp(-h_affine * t) * (1 + ANALYSIS_RATE_PER_YEAR)^-tau - slope_b
      expect_lt(abs((net[length(net)] - net[1]) - expected_slope), 0.01,
        label = sprintf("slope rho=%s T=%s", rho, t))
    }
  }

  # The risk-transfer corner: at a full rebate and `q_flat` the payer's budget
  # impact stops depending on the cure fraction altogether. `q_flat` exceeds
  # what one cure is worth by exactly the two deferral factors -- that is L20
  # in per-cure clothing, the number looking bigger because it is denominated
  # on a smaller, later population, not because value appeared.
  for (h in HAZARDS_PER_YEAR) {
    slope_b <- value_of_one_cure_usd(h, 0, GRIDS[[i]], RAW_DIR)
    ends <- lapply(c(0, 1), function(p) treg_trace_at(i, p, h))
    for (t in OBSERVATION_LADDER_YEARS) {
      tau <- t + 12 / 52
      q_flat <- slope_b * exp(h * t) * (1 + ANALYSIS_RATE_PER_YEAR)^tau
      expect_gt(q_flat, slope_b)
      net <- vapply(c(1, 2), function(j) {
        p <- c(0, 1)[j]
        net_total_usd(outcomes_based_price_stream_usd_per_year(q_flat, p, h, 1, t),
          ends[[j]], comparator, ONE_PATIENT, Inf)
      }, numeric(1))
      expect_lt(abs(net[2] - net[1]), 0.01, label = sprintf("flat slope h=%s T=%s", h, t))
    }
  }
})

test_that("T21(c): the level at the risk-transfer corner matches a second route to A, and reduces to -A only in the limit", {
  # The independence is PARTIAL and is claimed as no more than that:
  # `frontier_intercept_independent()` shares no code path with
  # `run_treg_trace()`, but both routes to A share the grid and the
  # pre-landmark loop, so this is a check on the CONTRACT arithmetic rather
  # than on A.
  i <- 1
  cmb <- COMBINATIONS[[i]]
  comparator <- COMPARATORS[[i]]$discounted_cost_stream_usd
  intercept_a <- frontier_intercept_independent(0, COMPARATORS[[i]], GRIDS[[i]], RAW_DIR)
  worst <- 0
  for (h in HAZARDS_PER_YEAR) {
    slope_b <- value_of_one_cure_usd(h, 0, GRIDS[[i]], RAW_DIR)
    for (t in OBSERVATION_LADDER_YEARS) {
      tau <- t + 12 / 52
      q_flat <- slope_b * exp(h * t) * (1 + ANALYSIS_RATE_PER_YEAR)^tau
      for (p in c(0.25, 1)) {
        treg <- treg_trace_at(i, p, h)
        level <- net_total_usd(outcomes_based_price_stream_usd_per_year(q_flat, p, h, 1, t),
          treg, comparator, ONE_PATIENT, Inf)
        expected <- slope_b * exp(h * t) * ((1 + ANALYSIS_RATE_PER_YEAR)^tau - 1) - intercept_a
        expect_lt(abs(level - expected), 1, label = sprintf("h=%s T=%s pi=%s", h, t, p))
        worst <- max(worst, abs(level - expected))
        # `-A(lambda = 0)` is the TAU -> 0 limit and is reported as a limit,
        # not as the identity: at the landmark the gap is already the 0.68%
        # this study has been bitten by once.
        expect_gt(abs(level - (-intercept_a)), 1, label = sprintf("limit not identity h=%s T=%s", h, t))
      }
    }
  }
  expect_lt(worst, 1)
})

test_that("T21(d): at a rebate share of zero the justified price is exactly the frontier's own", {
  for (i in seq_along(COMBINATIONS)) {
    cmb <- COMBINATIONS[[i]]
    for (h in HAZARDS_PER_YEAR) {
      for (p in c(0, 0.25, 1)) {
        for (lam in LAMBDAS_USD_PER_QALY) {
          star <- price_star_usd_per_course(p, h, lam, COMPARATORS[[i]], GRIDS[[i]],
            cmb$window, cmb$cap_on, RAW_DIR)
          for (t in OBSERVATION_LADDER_YEARS) {
            expect_identical(justified_arrangement_price_usd_per_course(star, p, h, 0, t), star,
              label = sprintf("%s pi=%s h=%s lambda=%s T=%s", label_of(cmb), p, h, lam, t))
          }
        }
      }
    }
  }
})

# ------------------------------------------------ guard 3 and the boundary --

test_that("guard 3: the per-cure declaration tracks the observation point", {
  # Trap 4. Two populations under one unit suffix is the exact shape of the
  # failure CLAUDE.md records has happened twice, so the declaration is checked
  # on both branches rather than written once and trusted.
  expect_identical(per_cure_denominator(0), "cured_patients_at_landmark")
  for (t in OBSERVATION_LADDER_YEARS[OBSERVATION_LADDER_YEARS > 0]) {
    expect_identical(per_cure_denominator(t), "sustained_remitters_at_observation")
  }
  landmark <- justified_price_usd_per_cure(PRICE, 0.5, 0.05, 0)
  later <- justified_price_usd_per_cure(PRICE, 0.5, 0.05, 2)
  expect_identical(denominator_of(landmark), "cured_patients_at_landmark")
  expect_identical(denominator_of(later), "sustained_remitters_at_observation")
  expect_false(identical(denominator_of(landmark), denominator_of(later)))
  # The converter declares the same two, and they are different numbers as
  # well as different names: the later population is strictly smaller.
  converted_landmark <- usd_per_course_to_usd_per_cure(PRICE,
    still_in_drug_free_remission(0.5, 0.05, 0), 0)
  converted_later <- usd_per_course_to_usd_per_cure(PRICE,
    still_in_drug_free_remission(0.5, 0.05, 2), 2)
  expect_identical(denominator_of(converted_landmark), "cured_patients_at_landmark")
  expect_identical(denominator_of(converted_later), "sustained_remitters_at_observation")
  expect_gt(as.numeric(converted_later), as.numeric(converted_landmark))
})

test_that("no function in R/payment_arrangements.R combines the two per-cure denominators", {
  # Guard 3 declares but does not compare, so nothing mechanical stops the two
  # being summed. What stops it is that no function in the module takes two
  # observation points: a single `outcome_observation_years` argument cannot
  # produce two declarations in one return value.
  env <- new.env()
  sys.source(repo_root_relative("R", "payment_arrangements.R"), envir = env)
  for (nm in ls(env)) {
    obj <- get(nm, envir = env)
    if (!is.function(obj)) next
    observation_args <- grep("outcome_observation_years", names(formals(obj)), value = TRUE)
    expect_lte(length(observation_args), 1, label = nm)
  }
})

test_that("R/payment_arrangements.R supplies no default for the price or for any contract term", {
  # The price is A6's precedent; the contract terms are L17's and L19's, and
  # `installment_financing_rate_per_year` is additionally O16 and therefore
  # guard 7's business. rho and T are NOT open items -- they are normative
  # contract design, and declining to choose them would be a refusal rather
  # than a justification -- but they are required arguments all the same, which
  # is what this asserts.
  env <- new.env()
  sys.source(repo_root_relative("R", "payment_arrangements.R"), envir = env)
  required <- c("price_usd_per_course", "price_star_usd_per_course",
    "installment_length_years", "installment_financing_rate_per_year",
    "rebate_share", "outcome_observation_years", "pi_cure", "h_per_year",
    "lifetime_offset_usd", "newly_treated_patients", "reporting_horizon_years")
  offenders <- character(0)
  for (nm in ls(env)) {
    obj <- get(nm, envir = env)
    if (!is.function(obj)) next
    f <- formals(obj)
    for (arg in intersect(names(f), required)) {
      if (!identical(f[[arg]], quote(expr = ))) offenders <- c(offenders, paste0(nm, "(", arg, ")"))
    }
  }
  expect_length(offenders, 0)
})

test_that("trap 2: the Treg arm, the frontier and the engine never learn that a contract exists", {
  # Putting a rebate inside `run_treg_trace()` would make the arm's cost
  # depend on a contract, `B` would become contract-dependent, and T13, T14 and
  # T17 would all be measuring something else. Asserted in both directions.
  env <- new.env()
  sys.source(repo_root_relative("R", "payment_arrangements.R"), envir = env)
  exports <- ls(env)
  expect_gt(length(exports), 0)
  for (file in c("treg_arm.R", "frontier.R", "markov_engine.R", "budget_impact.R")) {
    code <- readLines(repo_root_relative("R", file), warn = FALSE)
    code <- code[!grepl("^\\s*#", code)]
    for (nm in exports) {
      expect_false(any(grepl(nm, code, fixed = TRUE)), label = paste(file, "references", nm))
    }
  }
  # And the module reaches neither the manufacturing benchmark (L8) nor the
  # arm's own internals: it consumes streams, never produces them.
  module <- readLines(repo_root_relative("R", "payment_arrangements.R"), warn = FALSE)
  module <- module[!grepl("^\\s*#", module)]
  for (nm in c("manufacturing_benchmark_usd_per_course", "run_treg_trace", "run_comparator_trace")) {
    expect_false(any(grepl(nm, module, fixed = TRUE)), label = paste("module references", nm))
  }
})

# ----------------------------------------------------- the A7 outputs -------

test_that("A7's two output files exist, are stamped against the committed spec, and keep the third time axis out of the budget files", {
  pa_path <- repo_root_relative("output", "tables", "payment_arrangements.csv")
  recon_path <- repo_root_relative("output", "tables", "payment_arrangements_reconciliation.csv")
  expect_true(file.exists(pa_path))
  expect_true(file.exists(recon_path))

  pa <- read.csv(pa_path, comment.char = "#", stringsAsFactors = FALSE)
  for (col in c("result_family", "arrangement", "outcome_observation_years", "rebate_share",
                "installment_length_years", "installment_financing_rate_per_year",
                "justified_price_usd_per_course", "justified_price_usd_per_cure",
                "per_cure_denominator", "price_leg_share_of_lump_sum",
                "cumulative_net_budget_impact_usd", "offset_captured_share")) {
    expect_true(col %in% names(pa), label = col)
  }
  expect_setequal(unique(pa$result_family), c("per_cure_frontier", "budget_arrangement"))

  # L21: the per-cure unit applies at a full rebate and nowhere else.
  full <- pa$result_family == "per_cure_frontier" & pa$rebate_share == 1
  partial <- pa$result_family == "per_cure_frontier" & pa$rebate_share < 1
  expect_true(all(!is.na(pa$justified_price_usd_per_cure[full])))
  expect_true(all(is.na(pa$justified_price_usd_per_cure[partial])))
  expect_setequal(unique(pa$per_cure_denominator[full]),
    c("cured_patients_at_landmark", "sustained_remitters_at_observation"))

  # L19's naming concern: three horizon-like quantities now coexist in
  # output/tables/, and section 2a exists because two of them collided once.
  # `outcome_observation_years` appears in A7's files and in no file carrying
  # `reporting_horizon_years` as its own horizon column.
  for (f in c("budget_impact.csv", "budget_impact_reconciliation.csv")) {
    other <- read.csv(repo_root_relative("output", "tables", f), comment.char = "#",
      stringsAsFactors = FALSE)
    expect_true("reporting_horizon_years" %in% names(other), label = f)
    expect_false("outcome_observation_years" %in% names(other), label = f)
    expect_false("horizon_years" %in% names(other), label = f)
  }

  recon <- read.csv(recon_path, comment.char = "#", stringsAsFactors = FALSE)
  for (leg in c("T19b_installment_delta", "T20_offset_matched_identity",
                "T21a_outcomes_price_leg", "T21c_risk_neutral_level",
                "A6_lump_sum_agreement")) {
    sub <- recon[recon$leg == leg, ]
    expect_gt(nrow(sub), 0)
    tolerance <- if (leg == "T21c_risk_neutral_level") 1 else 0.01
    expect_true(all(abs(sub$agreement_usd) < tolerance, na.rm = TRUE), label = leg)
  }
  # A7's lump-sum arrangement IS A6's budget impact, to the cent, on every cell
  # the two files share. Nothing in A1-A6 moved.
  #
  # ON BOTH DISCOUNTING COLUMNS, and that clause is the load-bearing one. A
  # lump sum is a one-element price stream, so A7's cell and A6's are the same
  # arithmetic under the same convention -- but only if both aims stack their
  # undiscounted leg at a zero rate. When A6 stacked its undiscounted leg at
  # the ambient 3% while running its traces at zero, this leg's undiscounted
  # rows ran to nine figures at three years and more while its discounted rows
  # closed to half a cent. Asserting both columns here makes A7's own output a
  # standing check on A6's convention: the agreement cannot close on the
  # undiscounted column unless A6's cohort placement is still nominal.
  a6 <- recon[recon$leg == "A6_lump_sum_agreement", ]
  expect_gt(nrow(a6), 0)
  expect_setequal(unique(a6$discounted), c(TRUE, FALSE))
  for (d in c(TRUE, FALSE)) {
    col <- a6[a6$discounted == d, ]
    expect_gt(nrow(col), 0)
    expect_lt(max(abs(col$agreement_usd)), 0.01)
  }
  # The horizons at which a second adoption cohort exists are the only ones
  # that could ever separate the two conventions, so they must be present or
  # the check above is satisfied by one-cohort rows alone.
  expect_true(any(a6$reporting_horizon_years > 1 & !a6$discounted))
})
