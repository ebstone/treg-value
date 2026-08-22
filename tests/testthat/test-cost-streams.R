# T17 and T18 -- the per-cycle cost streams A6 rests on, and the property that
# lets a reporting horizon be a prefix of a lifetime run rather than a model
# parameter (SPEC.md L10, section 2a).
#
# T18 is a two-independent-routes test in T1/T2's house style: one route re-runs
# the engine at a shorter horizon, the other slices a lifetime run. They share
# no truncation logic. An earlier draft of T18 asserted that the streams at one
# horizon equal the leading years of the streams at a longer one -- vacuous,
# because streams are computed once at lifetime and both sides were the same
# vector.

source_r("io_cache.R")
source_r("price_index.R")
source_derive("health_state_costs.R")
source_r("denominator.R")
source_r("transition_matrices.R")
source_r("life_table.R")
source_r("dosing.R")
source_r("costs_utilities.R")
source_r("refractory.R")
source_r("comparator_dosing.R")
source_r("markov_engine.R")
source_r("treg_arm.R")
source_r("frontier.R")

RAW_DIR <- repo_root_relative("data", "raw")
LIFETIME_YEARS <- 100 - MODEL_START_AGE_YEARS
REPORTED_HORIZONS_YEARS <- c(1, 3, 5, 10, 30)
COMBINATIONS <- list(
  list(window = 4, cap_on = TRUE), list(window = 4, cap_on = FALSE),
  list(window = 8, cap_on = TRUE), list(window = 8, cap_on = FALSE)
)
label_of <- function(cmb) sprintf("window=%s cap=%s", cmb$window, cmb$cap_on)

# Built once and shared across every test below: 4 lifetime comparator runs and,
# for the Treg-side tests, one totals grid and one stream grid per combination.
LIFETIME_TRACES <- lapply(COMBINATIONS, function(cmb) {
  run_comparator_trace("IFX", cmb$window, cmb$cap_on, LIFETIME_YEARS, RAW_DIR)
})
GRIDS <- lapply(COMBINATIONS, function(cmb) standard_care_grid(cmb$window, cmb$cap_on, RAW_DIR))
STREAM_GRIDS <- lapply(COMBINATIONS, function(cmb) standard_care_cost_stream_grid(cmb$window, cmb$cap_on, RAW_DIR))

test_that("T17: the comparator's per-cycle cost stream sums to its pre-existing scalar, every window and cap", {
  for (i in seq_along(COMBINATIONS)) {
    tr <- LIFETIME_TRACES[[i]]
    expect_lt(abs(sum(tr$discounted_cost_stream_usd) - tr$discounted_cost_usd), 1e-6)
    expect_length(tr$discounted_cost_stream_usd, length(tr$undiscounted_cost_stream_usd))
  }
})

test_that("T17 is not vacuous: a stream missing its induction cycles does not sum to the scalar", {
  # The induction cycles are the first `induction_cycles` elements and carry the
  # induction course. Dropping them is the shape of error T17 would otherwise
  # sleep through, and it is worth hundreds of dollars, not rounding.
  for (i in seq_along(COMBINATIONS)) {
    tr <- LIFETIME_TRACES[[i]]
    maintenance_only <- sum(tr$discounted_cost_stream_usd[-seq_len(tr$induction_cycles)])
    expect_gt(abs(maintenance_only - tr$discounted_cost_usd), 1e3, label = label_of(COMBINATIONS[[i]]))
  }
})

test_that("the undiscounted stream is the same cycles before discounting: it dominates the discounted one and exceeds it in total", {
  for (i in seq_along(COMBINATIONS)) {
    tr <- LIFETIME_TRACES[[i]]
    expect_true(all(tr$undiscounted_cost_stream_usd >= tr$discounted_cost_stream_usd - 1e-9),
      label = label_of(COMBINATIONS[[i]]))
    expect_gt(sum(tr$undiscounted_cost_stream_usd), sum(tr$discounted_cost_stream_usd))
    # Cycle 1 is barely discounted, so the two agree there to within a cycle's
    # worth of interest -- a stream discounted twice, or not at all, fails this.
    expect_lt(abs(tr$undiscounted_cost_stream_usd[1] * (1 + DISCOUNT_RATE_PER_YEAR)^(-CYCLE_YEARS) -
      tr$discounted_cost_stream_usd[1]), 1e-9)
  }
})

test_that("T18: an independently re-run trace at horizon H equals the prefix sum of the lifetime stream at the matching cycle", {
  # Route 1: run the engine at H. Route 2: slice the lifetime run. The index is
  # `induction_cycles + round(H * cycles_per_year)` because `horizon_years`
  # governs the maintenance loop only -- induction cycles run before and in
  # addition to it (SPEC.md section 2a, horizon semantics).
  for (i in seq_along(COMBINATIONS)) {
    cmb <- COMBINATIONS[[i]]
    lifetime <- LIFETIME_TRACES[[i]]
    for (h_years in REPORTED_HORIZONS_YEARS) {
      short <- run_comparator_trace("IFX", cmb$window, cmb$cap_on, h_years, RAW_DIR)
      cycles <- lifetime$induction_cycles + round(h_years * ALIYEV_CYCLES_PER_YEAR)
      prefix <- sum(lifetime$discounted_cost_stream_usd[seq_len(cycles)])
      expect_lt(abs(short$discounted_cost_usd - prefix), 1e-6,
        label = sprintf("%s H=%s", label_of(cmb), h_years))
    }
  }
})

test_that("T18 fires: truncating at round(H * cycles_per_year) without the induction offset is caught", {
  # The falsification fixture. `total_cycles` counts maintenance cycles only, so
  # omitting the induction offset truncates 2 to 4 cycles early -- silently, and
  # by an amount that varies with the induction window. Given that
  # `comparator_ifx_trace.csv`'s own `horizon_years = 30` is 30.15 calendar
  # years for exactly this reason, this is the likeliest real bug in the whole
  # truncation, and it is what T18 exists to catch.
  #
  # Deliberately NOT built against the cap-off dose schedule taking its endpoint
  # from `total_cycles`: `seq(a, b1, by = d)` and `seq(a, b2, by = d)` agree on
  # every element <= b1 and `is_dose_cycle` is only ever asked about
  # t <= total_cycles, so that dependency is prefix-benign for cost and a
  # fixture built on it would report T18 broken when T18 is fine.
  worst_gap_usd <- 0
  for (i in seq_along(COMBINATIONS)) {
    cmb <- COMBINATIONS[[i]]
    lifetime <- LIFETIME_TRACES[[i]]
    for (h_years in REPORTED_HORIZONS_YEARS) {
      short <- run_comparator_trace("IFX", cmb$window, cmb$cap_on, h_years, RAW_DIR)
      wrong_cycles <- round(h_years * ALIYEV_CYCLES_PER_YEAR)
      wrong_prefix <- sum(lifetime$discounted_cost_stream_usd[seq_len(wrong_cycles)])
      gap <- abs(short$discounted_cost_usd - wrong_prefix)
      expect_gt(gap, 1, label = sprintf("%s H=%s", label_of(cmb), h_years))
      worst_gap_usd <- max(worst_gap_usd, gap)
    }
  }
  expect_gt(worst_gap_usd, 1e2)
})

test_that("T18: the interpolated stream sums to the interpolated total, at non-integer ages including the landmark", {
  # The construction requirement from the stream grid's own header -- zero-pad,
  # element-wise, same weight -- makes this an identity rather than an
  # approximation, which is what keeps T13's $1 tolerance safe against the
  # roughly $70 the totals grid's interpolation is already known to cost `A`.
  # The landmark age is the one non-integer age every patient passes through,
  # so its interpolation error is systematic rather than averaged out.
  landmark_age <- MODEL_START_AGE_YEARS + LANDMARK_CYCLES * CYCLE_YEARS
  ages <- c(landmark_age, 46.5, 60.5, 99.5, MODEL_START_AGE_YEARS, 100)
  for (i in seq_along(COMBINATIONS)) {
    for (age in ages) {
      stream <- standard_care_cost_stream_at_age(STREAM_GRIDS[[i]], age)
      total <- standard_care_at_age(GRIDS[[i]], age)$cost
      expect_equal(sum(stream), total, tolerance = 1e-9,
        label = sprintf("%s age=%s", label_of(COMBINATIONS[[i]]), age))
    }
  }
})

test_that("the stream lookup interpolates with the same weight approx() gives the totals", {
  # `standard_care_at_age()` interpolates via approx(). The stream lookup
  # computes the weight directly because a per-column approx() call inside a
  # relapse loop is unaffordable, so the two are checked against each other
  # rather than assumed equal. They agree to floating-point noise, not bit for
  # bit: the same weight applied in the same algebraic form still accumulates
  # differently across a vector than across a scalar.
  landmark_age <- MODEL_START_AGE_YEARS + LANDMARK_CYCLES * CYCLE_YEARS
  grid <- STREAM_GRIDS[[1]]
  for (age in c(landmark_age, 46.5, 60.5)) {
    direct <- standard_care_cost_stream_at_age(grid, age)
    via_approx <- apply(grid$streams, 2, function(col) approx(grid$ages, col, xout = age)$y)
    expect_equal(direct, via_approx, tolerance = 1e-12, label = paste("age", age))
  }
})

test_that("the undiscounted stream grid is the discounted one at a zero rate, and restores the rate it found", {
  # It cannot be relabelled out of the discounted grid, whose contents are
  # discounted to each patient's own start. Built the way run_scenarios.R builds
  # its disc-0 scenario, and checked against an element-wise rescale of the
  # discounted grid -- a second route to the same numbers.
  before <- getOption("treg_value.discount_rate")
  undiscounted <- standard_care_undiscounted_cost_stream_grid(8, TRUE, RAW_DIR)
  expect_identical(getOption("treg_value.discount_rate"), before)

  discounted <- STREAM_GRIDS[[3]] # window 8, cap on -- the same combination
  row <- which(discounted$ages == 50)
  disc <- discounted$streams[row, ]
  undisc <- undiscounted$streams[row, ]
  rescaled <- disc * (1 + DISCOUNT_RATE_PER_YEAR)^(seq_along(disc) / ALIYEV_CYCLES_PER_YEAR)
  nonzero <- undisc != 0
  expect_lt(max(abs(rescaled[nonzero] - undisc[nonzero]) / undisc[nonzero]), 1e-9)
  expect_gt(sum(undisc), sum(disc))
})

test_that("T17: the Treg arm's per-cycle cost stream sums to its pre-existing scalar, every window, cap, cure fraction and hazard", {
  for (i in seq_along(COMBINATIONS)) {
    cmb <- COMBINATIONS[[i]]
    for (p in c(0, 0.5, 1)) {
      for (h in c(0, 0.10)) {
        tr <- run_treg_trace(p, h, cmb$window, cmb$cap_on, GRIDS[[i]], RAW_DIR,
          sc_cost_stream_grid = STREAM_GRIDS[[i]])
        expect_lt(abs(sum(tr$discounted_cost_stream_usd) - tr$discounted_cost_usd), 1e-6,
          label = sprintf("%s pi=%s h=%s", label_of(cmb), p, h))
      }
    }
  }
})

test_that("the Treg arm's stream is opt-in and changes nothing when it is not asked for", {
  # The stream costs real time to build, so a 101-point sweep and a 1,000-draw
  # PSA must be able to decline it -- and declining it must not move a figure.
  cmb <- COMBINATIONS[[3]]
  without <- run_treg_trace(0.5, 0.05, cmb$window, cmb$cap_on, GRIDS[[3]], RAW_DIR)
  with_stream <- run_treg_trace(0.5, 0.05, cmb$window, cmb$cap_on, GRIDS[[3]], RAW_DIR,
    sc_cost_stream_grid = STREAM_GRIDS[[3]])
  expect_null(without$discounted_cost_stream_usd)
  expect_identical(without$discounted_cost_usd, with_stream$discounted_cost_usd)
  expect_identical(without$discounted_qaly, with_stream$discounted_qaly)
})

test_that("T17's Treg-side gap is partially closed: at a cure fraction of zero the independent route reproduces the arm's stream cycle by cycle", {
  # `run_treg_trace()` has no horizon argument, so T18's re-run route has no
  # Treg-side analogue. `frontier_intercept_independent_cost_stream_usd()` is
  # the second construction that does exist -- it prices the 12-week window
  # directly and defers one comparator course, sharing no code path with the
  # arm. At pi = 0 the arm is exactly that: nobody is cured, so there is no
  # drug-free-remission mass and there are no relapsers.
  for (i in seq_along(COMBINATIONS)) {
    cmb <- COMBINATIONS[[i]]
    independent <- frontier_intercept_independent_cost_stream_usd(STREAM_GRIDS[[i]], RAW_DIR)
    arm <- run_treg_trace(0, 0.05, cmb$window, cmb$cap_on, GRIDS[[i]], RAW_DIR,
      sc_cost_stream_grid = STREAM_GRIDS[[i]])$discounted_cost_stream_usd
    overlap <- seq_len(min(length(independent), length(arm)))
    expect_lt(max(abs(independent[overlap] - arm[overlap])), 1e-6, label = label_of(cmb))
    expect_lt(sum(abs(independent[-overlap])), 1e-6)
    expect_lt(sum(abs(arm[-overlap])), 1e-6)
  }
})

test_that("cycle-to-year aggregation is calendar-exact from t = 0 and conserves the total", {
  # Year k is exactly cycles (k-1)*cycles_per_year + 1 through k*cycles_per_year,
  # counting from t = 0 with the induction cycles first. This is the
  # calendar-exact clock SPEC.md section 2a names, NOT `horizon_years`'s clock.
  flat <- rep(1, 3 * ALIYEV_CYCLES_PER_YEAR)
  expect_equal(cost_stream_usd_per_cycle_to_usd_per_year(flat),
    rep(ALIYEV_CYCLES_PER_YEAR, 3))

  # One dollar in the last cycle of year 2 lands in year 2, not year 3.
  spike <- numeric(3 * ALIYEV_CYCLES_PER_YEAR)
  spike[2 * ALIYEV_CYCLES_PER_YEAR] <- 1
  expect_equal(cost_stream_usd_per_cycle_to_usd_per_year(spike), c(0, 1, 0))

  # A trailing partial year is reported as a partial year, not padded or dropped.
  partial <- rep(1, ALIYEV_CYCLES_PER_YEAR + 2)
  expect_length(cost_stream_usd_per_cycle_to_usd_per_year(partial), 2)
  expect_equal(sum(cost_stream_usd_per_cycle_to_usd_per_year(partial)), sum(partial))

  tr <- LIFETIME_TRACES[[3]]
  by_year <- cost_stream_usd_per_cycle_to_usd_per_year(tr$discounted_cost_stream_usd)
  expect_lt(abs(sum(by_year) - tr$discounted_cost_usd), 1e-6)
  expect_true(all(by_year >= 0))
})
