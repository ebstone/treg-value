# S8 -- the uptake-shape bounding pair (SPEC.md section 5, L12, L15), plus the
# module-boundary assertion SPEC.md's 2026-08-28 S8 amendment puts here rather
# than in G7.
#
# WHY THE OBVIOUS ORDERING ASSERTION IS ABSENT, and what stands in its place.
# "Immediate >= linear >= logistic at every year" is the natural guess and it
# is FALSE. A symmetric logistic pinned to both endpoints is antisymmetric
# about the ramp midpoint, exactly as the linear ramp is, so it runs below the
# linear path on the first half of the window and above it on the second,
# crossing at the midpoint. A test asserting the single chain would fail on
# correct code; a test written to make it pass would have to break either the
# symmetry or the shared endpoint, and the shared endpoint is the whole
# contract. The crossing is asserted positively below, in the direction the
# naive chain would forbid -- the same move test-budget-impact.R makes for the
# landmark deferral.
#
# WHAT S8's HEADLINE ACTUALLY IS. The offset-capture progression is invariant
# to the uptake shape BY CONSTRUCTION -- it is a per-treated-patient quantity
# and no uptake vector reaches it. That is asserted structurally (the
# functions that build it take no uptake argument) and empirically (the three
# shapes carry bit-identical shares in the committed S8 output), because a
# statement about what cannot happen is worth more than a bracketing
# assertion that would pass trivially.

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
source_r("budget_impact.R")

RAW_DIR <- repo_root_relative("data", "raw")
LIFETIME_YEARS <- 100 - MODEL_START_AGE_YEARS

# The steepness is an analyst's assumption with no default anywhere in R/
# (SPEC.md L12, amended 2026-08-28). The tests below therefore name their own
# values rather than importing one, and sweep several, so no property here can
# depend on the particular value analysis/run_bia.R commits to.
STEEPNESSES_PER_YEAR <- c(0.3, 1.0, 2.5)

shapes_at <- function(terminal_uptake_share, steepness, ramp_period_years) {
  lapply(BIA_UPTAKE_SHAPES, function(s) {
    uptake_cumulative_share_of_shape(s, terminal_uptake_share, steepness, ramp_period_years)
  })
}

# -------------------------------------------------- the shared contract -----

test_that("all three uptake shapes share one contract: length, denominator, monotonicity, and the terminal share at the end of the ramp", {
  for (ramp in c(2, 3, 5, 8, 11)) {
    for (u in c(0, 0.1, 0.25, 1 / 3, 1)) {
      for (k in STEEPNESSES_PER_YEAR) {
        curves <- shapes_at(u, k, ramp)
        for (i in seq_along(BIA_UPTAKE_SHAPES)) {
          lab <- sprintf("%s ramp=%s u=%s k=%s", BIA_UPTAKE_SHAPES[i], ramp, u, k)
          curve <- curves[[i]]
          expect_length(curve, ramp)
          # Guard 3: the share is of the ELIGIBLE POOL, declared and not implied.
          expect_identical(denominator_of(curve), "eligible_population_patients", label = lab)
          v <- as.numeric(curve)
          expect_true(all(diff(v) >= -1e-15), label = lab)
          expect_true(all(v >= -1e-15) && all(v <= u + 1e-15), label = lab)
          expect_lt(abs(v[ramp] - u), 1e-14)
        }
        # The endpoint is the contract, so it is asserted between the shapes as
        # well as against `u`: the three must agree there or S8 would be
        # varying the level under cover of varying the path.
        ends <- vapply(curves, function(x) as.numeric(x)[ramp], numeric(1))
        expect_lt(max(ends) - min(ends), 1e-14)
      }
    }
  }
})

test_that("the two alternative shapes reach the terminal share EXACTLY, to the bit", {
  # Stronger than the tolerance above, and true of the two new shapes but not
  # in general of the linear base case, whose endpoint is `ramp * (u / ramp)`
  # and can sit one unit in the last place away (ramp = 11, u = 0.1). Recorded
  # as a difference between the shapes rather than smoothed over: the pinned
  # logistic's endpoint is a floating-point number divided by itself, and
  # immediate uptake's is the argument returned unmodified.
  for (ramp in c(2, 5, 11)) {
    for (u in c(0.1, 0.25, 1 / 3, 1)) {
      for (k in STEEPNESSES_PER_YEAR) {
        expect_identical(as.numeric(uptake_cumulative_share_logistic(u, k, ramp))[ramp], u)
      }
      expect_identical(as.numeric(uptake_cumulative_share_immediate(u, ramp))[ramp], u)
    }
  }
})

test_that("L15 survives every shape: one adoption wave, the same u*N patients, nobody treated after the ramp", {
  eligible <- 1e5
  for (ramp in c(3, 5, 8)) {
    for (u in c(0, 0.25, 1)) {
      for (k in STEEPNESSES_PER_YEAR) {
        for (s in BIA_UPTAKE_SHAPES) {
          newly <- uptake_newly_treated_patients_of_shape(eligible, u, s, k, ramp)
          lab <- sprintf("%s ramp=%s u=%s k=%s", s, ramp, u, k)
          expect_length(newly, ramp)
          expect_equal(sum(newly), u * eligible, tolerance = 1e-9, label = lab)
          expect_true(all(newly >= -1e-9), label = lab)
        }
      }
    }
  }
  # The wave is structural and not a function of the reporting window: no shape
  # takes a horizon, so a 30-year projection treats exactly the patients a
  # 5-year forecast does. This is the same reading L15 asks of the linear ramp.
  expect_false("reporting_horizon_years" %in% names(formals(uptake_newly_treated_patients_of_shape)))
  for (fn in list(uptake_cumulative_share_logistic, uptake_cumulative_share_immediate,
                  uptake_cumulative_share_of_shape)) {
    expect_false("reporting_horizon_years" %in% names(formals(fn)))
  }
})

# ------------------------------------------------------- the ordering -------

test_that("the shapes are ordered as derived: immediate above both everywhere, and the logistic crosses the linear ramp at the midpoint", {
  # The derivation, restated so the assertion can be checked against it rather
  # than trusted: g is symmetric about the midpoint m, so the pinned F
  # satisfies F(R - t) = 1 - F(t), as the linear path t/R does. g is convex on
  # [0, m], and F is a positive affine image of g, so a convex F running from
  # F(0) = 0 to F(m) = 1/2 lies on or below the chord between them -- which is
  # the linear path. Antisymmetry carries the reverse to [m, R].
  for (ramp in c(4, 5, 8, 11)) {
    midpoint <- ramp / 2
    for (u in c(0.25, 1)) {
      for (k in STEEPNESSES_PER_YEAR) {
        lin <- as.numeric(uptake_cumulative_share(u, ramp))
        log_ <- as.numeric(uptake_cumulative_share_logistic(u, k, ramp))
        imm <- as.numeric(uptake_cumulative_share_immediate(u, ramp))
        lab <- sprintf("ramp=%s u=%s k=%s", ramp, u, k)
        # Immediate uptake is the fast bound at every year of the window.
        expect_true(all(imm >= lin - 1e-14), label = lab)
        expect_true(all(imm >= log_ - 1e-14), label = lab)
        for (j in seq_len(ramp)) {
          if (j < midpoint) expect_lte(log_[j], lin[j] + 1e-14)
          if (j > midpoint) expect_gte(log_[j], lin[j] - 1e-14)
          if (j == midpoint) expect_lt(abs(log_[j] - lin[j]), 1e-12)
        }
      }
    }
  }
})

test_that("the crossing is real, not a tolerance: at the committed ramp the logistic is strictly below the linear path early and strictly above it late", {
  # Non-vacuity for the assertion above. A shape that merely equalled the
  # linear ramp everywhere would satisfy every inequality in it.
  ramp <- BIA_UPTAKE_RAMP_PERIOD_YEARS
  lin <- as.numeric(uptake_cumulative_share(0.25, ramp))
  log_ <- as.numeric(uptake_cumulative_share_logistic(0.25, 1.0, ramp))
  expect_lt(log_[1], lin[1] - 1e-6)
  expect_lt(log_[2], lin[2] - 1e-6)
  expect_gt(log_[3], lin[3] + 1e-6)
  expect_gt(log_[4], lin[4] + 1e-6)
  expect_lt(abs(log_[ramp] - lin[ramp]), 1e-14)
  # And immediate uptake really does front-load: the whole wave in year 1.
  imm_newly <- uptake_newly_treated_patients_of_shape(1e4, 0.25, "immediate_full_uptake", 1.0)
  expect_equal(imm_newly[1], 0.25 * 1e4, tolerance = 1e-9)
  expect_true(all(imm_newly[-1] == 0))
})

# ------------------------- the offset-capture progression, S8's headline -----

test_that("S8's headline is structural: no uptake vector can reach the offset-capture progression", {
  # SPEC.md section 2a: `offset_captured(H)` "depends on pi, h and the cap
  # setting and not on the eligible population". The invariance is therefore a
  # fact about the signatures, and asserting it there is stronger than
  # observing that three numbers happened to come out equal.
  for (fn in list(cost_offset_per_patient_usd, offset_captured_share)) {
    args <- names(formals(fn))
    expect_false(any(grepl("uptake|newly_treated|eligible|shape", args)))
  }
})

test_that("the offset-capture progression is bit-identical under all three shapes, so the bounding pair brackets the base case exactly", {
  # The empirical half of the statement above, computed through the same
  # functions analysis/run_bia.R uses. Bracketing is asserted as well as
  # equality, because bracketing is what the scenario was commissioned to
  # answer and a reader should see it tested rather than inferred.
  cmb <- list(window = 8, cap_on = TRUE)
  grid <- standard_care_grid(cmb$window, cmb$cap_on, RAW_DIR)
  stream_grid <- standard_care_cost_stream_grid(cmb$window, cmb$cap_on, RAW_DIR)
  comparator <- run_comparator_trace("IFX", cmb$window, cmb$cap_on, LIFETIME_YEARS, RAW_DIR)
  treg <- run_treg_trace(0.5, 0.05, cmb$window, cmb$cap_on, grid, RAW_DIR,
    sc_cost_stream_grid = stream_grid)
  lifetime_offset <- price_star_usd_per_course(0.5, 0.05, 0, comparator, grid,
    cmb$window, cmb$cap_on, RAW_DIR)

  for (horizon in c(1, 3, 5, 10, 30)) {
    shares <- lapply(BIA_UPTAKE_SHAPES, function(s) {
      # The uptake vector is built and discarded: it cannot enter the
      # progression, and that is the point being demonstrated.
      newly <- uptake_newly_treated_patients_of_shape(1e5, 0.25, s, 1.0)
      stopifnot(length(newly) == BIA_UPTAKE_RAMP_PERIOD_YEARS)
      offset_captured_share(
        cost_offset_per_patient_usd(
          truncated_cost_usd_per_year(comparator$discounted_cost_stream_usd, horizon),
          truncated_cost_usd_per_year(treg$discounted_cost_stream_usd, horizon)),
        lifetime_offset)
    })
    linear <- shares[[match("linear_ramp", BIA_UPTAKE_SHAPES)]]
    for (s in shares) expect_identical(s, linear, label = sprintf("H=%s", horizon))
    bounds <- shares[BIA_UPTAKE_SHAPES != "linear_ramp"]
    lo <- pmin(bounds[[1]], bounds[[2]])
    hi <- pmax(bounds[[1]], bounds[[2]])
    expect_true(all(linear >= lo - 1e-12 & linear <= hi + 1e-12), label = sprintf("H=%s", horizon))
  }
})

# ------------------------------ T13, restated over each shape's cohort stack -

test_that("T13 still closes under every uptake shape: the stacked lifetime net impact per discounted treated patient is price - P*(pi, h, lambda = 0)", {
  # T13's own fixture is one cohort of one patient at t = 0, which no uptake
  # function touches. The shape-aware statement is the stack version: cohort k
  # contributes its whole per-patient net brought to t = 0 at the factor for
  # k - 1 years, so dividing the stacked total by `sum(treated_k * v^(k-1))`
  # must return the per-patient identity, whatever path put the patients there.
  # At the immediate shape that sum is a single cohort at t = 0 and the
  # statement degenerates to T13 exactly.
  price <- 5e4
  worst <- 0
  for (cap_on in c(TRUE, FALSE)) {
    grid <- standard_care_grid(8, cap_on, RAW_DIR)
    stream_grid <- standard_care_cost_stream_grid(8, cap_on, RAW_DIR)
    comparator <- run_comparator_trace("IFX", 8, cap_on, LIFETIME_YEARS, RAW_DIR)
    comp_annual <- truncated_cost_usd_per_year(comparator$discounted_cost_stream_usd, Inf)
    for (p in c(0.25, 1)) {
      for (h in c(0, 0.10)) {
        treg <- run_treg_trace(p, h, 8, cap_on, grid, RAW_DIR, sc_cost_stream_grid = stream_grid)
        treg_annual <- truncated_cost_usd_per_year(treg$discounted_cost_stream_usd, Inf)
        frontier_route <- price - price_star_usd_per_course(p, h, 0, comparator, grid,
          8, cap_on, RAW_DIR)
        for (s in BIA_UPTAKE_SHAPES) {
          newly <- uptake_newly_treated_patients_of_shape(1e4, 0.25, s, 1.0)
          weight <- sum(newly * vapply(seq_along(newly) - 1,
            discount_factor_years_to_discount_factor, numeric(1)))
          total <- sum(net_budget_impact_usd_per_year(
            treg_world_expenditure_usd_per_year(price, treg_annual, newly, Inf),
            current_care_expenditure_usd_per_year(comp_annual, newly, Inf)))
          bia_route <- total / weight
          lab <- sprintf("%s cap=%s pi=%s h=%s", s, cap_on, p, h)
          expect_lt(abs(bia_route - frontier_route), 1, label = lab)
          worst <- max(worst, abs(bia_route - frontier_route))
        }
      }
    }
  }
  expect_lt(worst, 0.01)
})

# -------------------------------------------------- falsification fixtures --

test_that("S8 fires: a shape that does not reach the terminal share fails the contract", {
  # The unpinned logistic -- the shape a first implementation writes, because
  # `1 / (1 + exp(-k(t - m)))` looks finished on its own. It never reaches the
  # terminal share, so it treats fewer than u*N patients and silently reports
  # a lower budget impact under a heading that claims to vary only the path.
  ramp <- BIA_UPTAKE_RAMP_PERIOD_YEARS
  u <- 0.25
  k <- 1.0
  broken <- with_denominator(
    u / (1 + exp(-k * (seq_len(ramp) - ramp / 2))), "eligible_population_patients")
  # The endpoint assertion the contract test makes.
  expect_gt(abs(as.numeric(broken)[ramp] - u), 1e-14)
  # And its consequence: the wave is short of u*N patients.
  short <- 1e4 * diff(c(0, as.numeric(broken)))
  expect_lt(sum(short), 0.25 * 1e4 - 1)
  # The correct shape passes both where the broken one fails.
  ok <- uptake_cumulative_share_logistic(u, k, ramp)
  expect_identical(as.numeric(ok)[ramp], u)
  expect_equal(sum(1e4 * diff(c(0, as.numeric(ok)))), 0.25 * 1e4, tolerance = 1e-9)
})

test_that("S8 fires: a shape that drops the denominator declaration is refused rather than stacked", {
  # Guard 3's failure mode in this file's shape: `uptake_newly_treated_
  # patients_of_shape()` re-checks the declaration on the vector it was
  # handed, so a shape returning a bare numeric cannot reach the cohort
  # stacker. The check is exercised here against a stripped vector, since the
  # dispatcher admits only the three declared shapes.
  stripped <- as.numeric(uptake_cumulative_share_logistic(0.25, 1.0))
  expect_identical(denominator_of(stripped), NA_character_)
  refuse <- function(cumulative) {
    stopifnot(identical(denominator_of(cumulative), "eligible_population_patients"))
    diff(c(0, as.numeric(cumulative)))
  }
  expect_error(refuse(stripped))
  expect_silent(refuse(uptake_cumulative_share_logistic(0.25, 1.0)))
})

test_that("S8 fires: an unnamed shape is refused", {
  expect_error(uptake_cumulative_share_of_shape("s_curve", 0.25, 1.0))
  expect_error(uptake_newly_treated_patients_of_shape(1e4, 0.25, "exponential", 1.0))
})

# ------------------------------------------------ the module boundary -------

test_that("no function in R/ supplies a default for the logistic steepness", {
  # SPEC.md L12, amended 2026-08-28: the steepness is unsourceable in exactly
  # the way L12's own 5-year ramp period is, and is handled the same way. G7
  # does not watch this name -- O12's argument name is `uptake_trajectory` --
  # so the assertion lives here, on the precedent L21 set for the rebate share
  # and the observation point in test-payment-arrangements.R.
  env <- new.env()
  for (f in sort(list.files(repo_root_relative("R"), pattern = "\\.R$", full.names = TRUE))) {
    sys.source(f, envir = env)
  }
  offenders <- character(0)
  for (nm in ls(env)) {
    obj <- get(nm, envir = env)
    if (!is.function(obj)) next
    f <- formals(obj)
    if ("logistic_steepness_per_year" %in% names(f) &&
        !identical(f[["logistic_steepness_per_year"]], quote(expr = ))) {
      offenders <- c(offenders, nm)
    }
  }
  expect_length(offenders, 0)
  # And it is genuinely required, not merely undefaulted-and-unused: the
  # dispatcher forces it on every branch, including the two shapes that do not
  # read it, so no caller can reach a shape without having named a value.
  expect_error(uptake_cumulative_share_of_shape("linear_ramp", 0.25))
  expect_error(uptake_cumulative_share_immediate())
})

test_that("the steepness must be a single positive number", {
  expect_error(uptake_cumulative_share_logistic(0.25, 0))
  expect_error(uptake_cumulative_share_logistic(0.25, -1))
  expect_error(uptake_cumulative_share_logistic(0.25, c(1, 2)))
})

# ----------------------------------------------------- the S8 output --------

test_that("S8's output file exists, is stamped, carries all three shapes, and records the steepness it was run at", {
  path <- repo_root_relative("output", "tables", "budget_impact_s8.csv")
  expect_true(file.exists(path))
  header <- readLines(path, n = 2, warn = FALSE)
  expect_match(header[1], "^# commit: [0-9a-f]{40}$")
  expect_match(header[2], "^# spec_sha256: [0-9a-f]{64}$")

  s8 <- read.csv(path, comment.char = "#", stringsAsFactors = FALSE)
  expect_setequal(unique(s8$uptake_shape), BIA_UPTAKE_SHAPES)
  for (col in c("uptake_shape", "uptake_ramp_period_years", "uptake_logistic_steepness_per_year",
                "reporting_horizon", "reporting_horizon_years", "horizon_class",
                "discounted", "discounting_base_case", "terminal_uptake_share",
                "patients_ever_treated_patients", "cumulative_net_budget_impact_usd",
                "offset_captured_share", "required_cure_fraction_all_treated")) {
    expect_true(col %in% names(s8), label = col)
  }
  # The steepness is recorded on the rows it governs and on no others: a value
  # printed against a linear row would read as though the linear ramp had one.
  expect_true(all(!is.na(s8$uptake_logistic_steepness_per_year[s8$uptake_shape == "logistic"])))
  expect_true(all(is.na(s8$uptake_logistic_steepness_per_year[s8$uptake_shape != "logistic"])))
  expect_length(unique(s8$uptake_logistic_steepness_per_year[s8$uptake_shape == "logistic"]), 1)
  # Every shape is present in every scenario group, or the bracketing claim
  # would be reported over a ragged grid.
  group <- interaction(s8$maintenance_cap, s8$h_per_year, s8$pi_cure, s8$price_source,
    s8$terminal_uptake_share, s8$reporting_horizon, s8$discounted, drop = TRUE)
  expect_true(all(table(group) == length(BIA_UPTAKE_SHAPES)))
  # And the headline, read off the committed table: the progression does not
  # move across the shapes, to the precision the file is written at.
  by_group <- split(s8$offset_captured_share, group)
  spreads <- vapply(by_group, function(x) {
    if (all(is.na(x))) 0 else max(x, na.rm = TRUE) - min(x, na.rm = TRUE)
  }, numeric(1))
  expect_identical(max(spreads), 0)
})
