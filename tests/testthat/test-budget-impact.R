# T13-T16 -- the budget impact analysis (A6), plus the module-boundary
# assertions SPEC.md's A6 amendment puts here rather than in T12.
#
# WHAT IS DELIBERATELY ABSENT. There is no monotonicity assertion on net budget
# impact or on the offset-capture share in the horizon, at any relapse hazard
# including zero. Two independent mechanisms make the annual incremental cost
# difference able to turn against the Treg world: a relapser re-entering
# standard care is charged a fresh induction course with their own cap clock,
# and -- independently of any relapse -- the Treg cohort's 12-week landmark
# deferral (L9) shifts its 2-year cap clock 12 weeks later than the comparator
# world's, so there is a window in which the Treg world pays biologic and the
# comparator world does not. A PASSING monotonicity test would mean one of
# those two had stopped being charged. The second mechanism is asserted
# positively below, at a cure fraction of zero and a hazard of zero, precisely
# because it is the thing a monotonicity test would quietly destroy.

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
REPORTED_HORIZONS_YEARS <- c(1, 3, 5, 10, 30)
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

# One treated patient, adopting at t = 0: the fixture T13 and T14 are stated
# over, and the only cohort shape in which "per treated patient" is unambiguous.
ONE_PATIENT <- 1

net_per_patient_usd <- function(price, treg_stream, comparator_stream, horizon_years) {
  treg_annual <- truncated_cost_usd_per_year(treg_stream, horizon_years)
  comparator_annual <- truncated_cost_usd_per_year(comparator_stream, horizon_years)
  sum(net_budget_impact_usd_per_year(
    treg_world_expenditure_usd_per_year(price, treg_annual, ONE_PATIENT, horizon_years),
    current_care_expenditure_usd_per_year(comparator_annual, ONE_PATIENT, horizon_years)))
}

# ---------------------------------------------------------------- T13 ------

test_that("T13: on the lifetime leg the BIA's net impact per treated patient is price - P*(pi, h, lambda = 0)", {
  # At lambda = 0 net monetary benefit is the negative of cost, so P*(pi, h, 0)
  # is a pure discounted lifetime cost difference and the budget arithmetic and
  # the frontier arithmetic must land on the same number by two routes. This is
  # A6's gate.
  price <- 5e4
  worst <- 0
  for (i in seq_along(COMBINATIONS)) {
    cmb <- COMBINATIONS[[i]]
    for (p in c(0, 0.25, 0.5, 1)) {
      for (h in c(0, 0.05, 0.10)) {
        treg <- run_treg_trace(p, h, cmb$window, cmb$cap_on, GRIDS[[i]], RAW_DIR,
          sc_cost_stream_grid = STREAM_GRIDS[[i]])
        bia_route <- net_per_patient_usd(price, treg$discounted_cost_stream_usd,
          COMPARATORS[[i]]$discounted_cost_stream_usd, Inf)
        frontier_route <- price - price_star_usd_per_course(p, h, 0, COMPARATORS[[i]],
          GRIDS[[i]], cmb$window, cmb$cap_on, RAW_DIR)
        expect_lt(abs(bia_route - frontier_route), 1,
          label = sprintf("%s pi=%s h=%s", label_of(cmb), p, h))
        worst <- max(worst, abs(bia_route - frontier_route))
      }
    }
  }
  # Recorded so a regression that merely widens the gap is visible rather than
  # absorbed by the dollar tolerance.
  expect_lt(worst, 0.01)
})

test_that("T13 fires: truncating the lifetime leg at the cohort's own horizon breaks the identity", {
  # The falsification fixture, and it is trap 6 in the shape it actually takes.
  # The Treg arm's stream runs PAST the cohort horizon, because a patient handed
  # to standard care near the end carries a course whose cycles continue past
  # it. Truncating the lifetime leg at LIFETIME_YEARS -- which looks like the
  # obviously correct thing to do -- silently drops that tail and the identity
  # stops holding.
  price <- 5e4
  cmb <- COMBINATIONS[[1]]
  treg <- run_treg_trace(0.5, 0.05, cmb$window, cmb$cap_on, GRIDS[[1]], RAW_DIR,
    sc_cost_stream_grid = STREAM_GRIDS[[1]])
  frontier_route <- price - price_star_usd_per_course(0.5, 0.05, 0, COMPARATORS[[1]],
    GRIDS[[1]], cmb$window, cmb$cap_on, RAW_DIR)
  truncated <- net_per_patient_usd(price, treg$discounted_cost_stream_usd,
    COMPARATORS[[1]]$discounted_cost_stream_usd, LIFETIME_YEARS)
  expect_gt(abs(truncated - frontier_route), 1)
})

# ---------------------------------------------------------------- T14 ------

test_that("T14: net budget impact per treated patient is affine in the cure fraction at every reported horizon", {
  # 101 points, as SPEC.md section 5 sweeps pi. One set of runs serves every
  # horizon, because the horizons are prefixes of the same streams.
  cmb <- COMBINATIONS[[1]]
  h <- 0.05
  price <- 5e4
  pi_grid <- seq(0, 1, length.out = 101)
  streams <- lapply(pi_grid, function(p) {
    run_treg_trace(p, h, cmb$window, cmb$cap_on, GRIDS[[1]], RAW_DIR,
      sc_cost_stream_grid = STREAM_GRIDS[[1]])$discounted_cost_stream_usd
  })
  for (horizon in c(REPORTED_HORIZONS_YEARS, Inf)) {
    net <- vapply(streams, function(s) {
      net_per_patient_usd(price, s, COMPARATORS[[1]]$discounted_cost_stream_usd, horizon)
    }, numeric(1))
    fitted <- net[1] + pi_grid * (net[length(net)] - net[1])
    expect_lt(max(abs(net - fitted)), 0.01, label = sprintf("H=%s", horizon))
  }
})

test_that("T14: on the lifetime leg the slope is -B(h, lambda = 0) and the intercept is price - A(lambda = 0)", {
  price <- 5e4
  for (i in seq_along(COMBINATIONS)) {
    cmb <- COMBINATIONS[[i]]
    intercept_a <- frontier_intercept_from_model(0, 0, COMPARATORS[[i]], GRIDS[[i]],
      cmb$window, cmb$cap_on, RAW_DIR)
    for (h in c(0, 0.05, 0.10)) {
      slope_b <- value_of_one_cure_usd(h, 0, GRIDS[[i]], RAW_DIR)
      at <- vapply(c(0, 1), function(p) {
        treg <- run_treg_trace(p, h, cmb$window, cmb$cap_on, GRIDS[[i]], RAW_DIR,
          sc_cost_stream_grid = STREAM_GRIDS[[i]])
        net_per_patient_usd(price, treg$discounted_cost_stream_usd,
          COMPARATORS[[i]]$discounted_cost_stream_usd, Inf)
      }, numeric(1))
      expect_lt(abs(at[1] - (price - intercept_a)), 1, label = sprintf("%s h=%s intercept", label_of(cmb), h))
      expect_lt(abs((at[2] - at[1]) - (-slope_b)), 1, label = sprintf("%s h=%s slope", label_of(cmb), h))
    }
  }
})

# ---------------------------------------------------------------- T15 ------

test_that("T15: in each world separately, gross annual expenditure undiscounted is at least the discounted figure, per year and cumulatively", {
  # Asserted on GROSS expenditure in each world, never on the net series:
  # undiscounting weights later years more heavily and later years are where the
  # offsets fall, so no sign holds for the discounting effect on the net.
  eligible <- 1e5
  for (i in seq_along(COMBINATIONS)) {
    cmb <- COMBINATIONS[[i]]
    comparator <- COMPARATORS[[i]]
    treg <- run_treg_trace(0.5, 0.05, cmb$window, cmb$cap_on, GRIDS[[i]], RAW_DIR,
      sc_cost_stream_grid = STREAM_GRIDS[[i]])
    treg_undiscounted <- local({
      old <- getOption("treg_value.discount_rate")
      options(treg_value.discount_rate = 0)
      on.exit(options(treg_value.discount_rate = old), add = TRUE)
      zero_grid <- standard_care_grid(cmb$window, cmb$cap_on, RAW_DIR)
      zero_stream_grid <- standard_care_cost_stream_grid(cmb$window, cmb$cap_on, RAW_DIR)
      run_treg_trace(0.5, 0.05, cmb$window, cmb$cap_on, zero_grid, RAW_DIR,
        sc_cost_stream_grid = zero_stream_grid)
    })

    newly <- uptake_newly_treated_patients(eligible, 0.25)
    for (horizon in REPORTED_HORIZONS_YEARS) {
      worlds <- list(
        list(name = "treg",
          disc = treg_world_expenditure_usd_per_year(5e4,
            truncated_cost_usd_per_year(treg$discounted_cost_stream_usd, horizon), newly, horizon),
          undisc = treg_world_expenditure_usd_per_year(5e4,
            truncated_cost_usd_per_year(treg_undiscounted$discounted_cost_stream_usd, horizon), newly, horizon)),
        list(name = "current_care",
          disc = current_care_expenditure_usd_per_year(
            truncated_cost_usd_per_year(comparator$discounted_cost_stream_usd, horizon), newly, horizon),
          undisc = current_care_expenditure_usd_per_year(
            truncated_cost_usd_per_year(comparator$undiscounted_cost_stream_usd, horizon), newly, horizon))
      )
      for (w in worlds) {
        lab <- sprintf("%s %s H=%s", label_of(cmb), w$name, horizon)
        expect_true(all(w$undisc >= w$disc - 1e-6), label = lab)
        expect_true(all(cumsum(w$undisc) >= cumsum(w$disc) - 1e-6), label = lab)
        expect_true(all(w$disc >= 0), label = lab)
      }
    }
  }
})

test_that("T15: cumulative gross expenditure in each world is non-decreasing in horizon length", {
  cmb <- COMBINATIONS[[1]]
  treg <- run_treg_trace(0.5, 0.05, cmb$window, cmb$cap_on, GRIDS[[1]], RAW_DIR,
    sc_cost_stream_grid = STREAM_GRIDS[[1]])
  newly <- uptake_newly_treated_patients(1e5, 0.25)
  gross <- function(stream, horizon) {
    sum(current_care_expenditure_usd_per_year(
      truncated_cost_usd_per_year(stream, horizon), newly, horizon))
  }
  for (stream in list(treg$discounted_cost_stream_usd, COMPARATORS[[1]]$discounted_cost_stream_usd)) {
    totals <- vapply(REPORTED_HORIZONS_YEARS, function(h) gross(stream, h), numeric(1))
    expect_true(all(diff(totals) >= -1e-6))
  }
})

test_that("the landmark deferral is still charged: at a cure fraction and a hazard of zero the Treg world outspends the current-care world in some year", {
  # The cap-clock phase shift (L9), asserted positively. The Treg cohort spends
  # 12 weeks on conventional therapy, so the non-cured enter standard care at
  # the landmark and their 2-year cap clock expires 12 weeks later than the
  # comparator world's. In that window the Treg world pays biologic and the
  # comparator world does not, with no relapsers and nobody cured. This is the
  # mechanism a monotonicity test would destroy, which is why it is asserted
  # here in the direction a monotonicity test would forbid.
  cmb <- COMBINATIONS[[1]] # cap on -- the shift needs a cap clock to shift
  treg <- run_treg_trace(0, 0, cmb$window, cmb$cap_on, GRIDS[[1]], RAW_DIR,
    sc_cost_stream_grid = STREAM_GRIDS[[1]])
  net <- net_budget_impact_usd_per_year(
    truncated_cost_usd_per_year(treg$discounted_cost_stream_usd, 30),
    truncated_cost_usd_per_year(COMPARATORS[[1]]$discounted_cost_stream_usd, 30))
  expect_true(any(net > 1))
})

# ---------------------------------------------------------------- T16 ------

test_that("T16: at a terminal uptake share of zero the two worlds are identical every year at every horizon and the net impact is exactly zero", {
  cmb <- COMBINATIONS[[1]]
  treg <- run_treg_trace(0.5, 0.05, cmb$window, cmb$cap_on, GRIDS[[1]], RAW_DIR,
    sc_cost_stream_grid = STREAM_GRIDS[[1]])
  for (eligible in c(1e4, 5e4, 1e5, 1e6)) {
    newly <- uptake_newly_treated_patients(eligible, 0)
    expect_identical(sum(newly), 0)
    for (horizon in REPORTED_HORIZONS_YEARS) {
      treg_world <- treg_world_expenditure_usd_per_year(5e4,
        truncated_cost_usd_per_year(treg$discounted_cost_stream_usd, horizon), newly, horizon)
      current_care <- current_care_expenditure_usd_per_year(
        truncated_cost_usd_per_year(COMPARATORS[[1]]$discounted_cost_stream_usd, horizon), newly, horizon)
      expect_identical(treg_world, current_care)
      expect_identical(sum(net_budget_impact_usd_per_year(treg_world, current_care)), 0)
    }
  }
})

test_that("T16: net budget impact scales exactly linearly in the number treated", {
  cmb <- COMBINATIONS[[1]]
  treg <- run_treg_trace(0.5, 0.05, cmb$window, cmb$cap_on, GRIDS[[1]], RAW_DIR,
    sc_cost_stream_grid = STREAM_GRIDS[[1]])
  net_at <- function(eligible, u, horizon) {
    newly <- uptake_newly_treated_patients(eligible, u)
    sum(net_budget_impact_usd_per_year(
      treg_world_expenditure_usd_per_year(5e4,
        truncated_cost_usd_per_year(treg$discounted_cost_stream_usd, horizon), newly, horizon),
      current_care_expenditure_usd_per_year(
        truncated_cost_usd_per_year(COMPARATORS[[1]]$discounted_cost_stream_usd, horizon), newly, horizon)))
  }
  for (horizon in REPORTED_HORIZONS_YEARS) {
    base <- net_at(1e4, 0.25, horizon)
    expect_equal(net_at(1e5, 0.25, horizon), base * 10, tolerance = 1e-9)
    expect_equal(net_at(1e6, 0.25, horizon), base * 100, tolerance = 1e-9)
    # Linear in the uptake level for the same reason: it is the same product.
    expect_equal(net_at(1e4, 0.5, horizon), base * 2, tolerance = 1e-9)
  }
})

# ------------------------------------------------- the uptake mechanics -----

test_that("guard 3: the terminal uptake share declares the eligible pool as its denominator", {
  # Trap 4. This project's twice-recorded failure mode is a share of a subset
  # reported as though it were a share of the whole; the declaration is what
  # makes "share of the eligible pool" a checked fact rather than a comment.
  share <- uptake_cumulative_share(0.4)
  expect_identical(denominator_of(share), "eligible_population_patients")
})

test_that("L15: the ramp is a single adoption wave and nobody is treated after it ends", {
  # The decision has no other mechanical guard -- T16 is satisfied by both the
  # single-wave and the persisting-rate reading -- so L15 asks that the uptake
  # function be read. This reads it.
  newly <- uptake_newly_treated_patients(1e5, 0.4)
  expect_length(newly, BIA_UPTAKE_RAMP_PERIOD_YEARS)
  expect_equal(sum(newly), 0.4 * 1e5)
  expect_true(all(abs(diff(newly)) < 1e-9)) # linear ramp: equal annual intake
  # The wave is structural, not a function of the reporting window: the uptake
  # function takes no horizon, so a 30-year projection treats exactly the same
  # u*N patients a 5-year forecast does and years 6 onward are pure offset
  # accrual. Under the rejected "flow" reading this vector would grow with the
  # horizon and treat several times the eligible pool.
  expect_false("reporting_horizon_years" %in% names(formals(uptake_newly_treated_patients)))
  expect_lte(sum(newly), 1e5)
})

test_that("trap 1: the course price is charged once, in the adoption year, not annually", {
  newly <- uptake_newly_treated_patients(1e4, 1)
  price <- 5e4
  no_ongoing <- numeric(30)
  charged <- treg_world_expenditure_usd_per_year(price, no_ongoing, newly, 30)
  # Every dollar of price falls inside the ramp; nothing is charged afterwards.
  expect_true(all(charged[seq(BIA_UPTAKE_RAMP_PERIOD_YEARS + 1, 30)] == 0))
  expect_equal(sum(charged),
    price * sum(newly * (1 + DISCOUNT_RATE_PER_YEAR)^-(seq_along(newly) - 1)), tolerance = 1e-6)
  # Charged annually to everyone ever treated it would be far larger; this is
  # the size of the error the once-only charge avoids.
  expect_lt(sum(charged), price * sum(newly) * 2)
})

test_that("trap 2: earlier cohorts keep spending in later years, so the stack overlaps", {
  newly <- uptake_newly_treated_patients(1e4, 1)
  per_patient <- rep(1, 10) # one dollar a year for ten years, per patient
  stacked <- stacked_cohort_expenditure_usd_per_year(per_patient, newly, 10)
  # Year 5 carries all five cohorts; year 1 carries one. A single scaled cohort
  # would make these equal.
  expect_gt(stacked[BIA_UPTAKE_RAMP_PERIOD_YEARS], stacked[1] * 4)
  expect_true(all(diff(stacked[seq_len(BIA_UPTAKE_RAMP_PERIOD_YEARS)]) > 0))
  # And spending continues after the last cohort adopts.
  expect_gt(stacked[10], 0)
})

test_that("the reporting horizon is calendar-exact from t = 0 and truncates a prefix of a lifetime stream", {
  # SPEC.md section 2a: the BIA's boundary is calendar time, NOT the
  # `horizon_years` argument's clock, which counts maintenance cycles only.
  stream <- COMPARATORS[[1]]$discounted_cost_stream_usd
  for (horizon in REPORTED_HORIZONS_YEARS) {
    annual <- truncated_cost_usd_per_year(stream, horizon)
    expect_length(annual, horizon)
    expect_equal(sum(annual), sum(stream[seq_len(horizon * ALIYEV_CYCLES_PER_YEAR)]), tolerance = 1e-9)
  }
  # Inf keeps the whole stream, which is what the lifetime leg needs.
  expect_equal(sum(truncated_cost_usd_per_year(stream, Inf)), sum(stream), tolerance = 1e-9)
})

# ------------------------------------------- the offset-capture progression -

test_that("the offset-capture share keeps the length of the progression it is given", {
  # The defect this pins: `ifelse()` returns a value shaped like its TEST, so a
  # scalar denominator collapses a whole progression to its first year and the
  # output table then repeats that one number across every horizon. A flat
  # progression reads as a finding, which is why a wrong answer here is worse
  # than an error.
  cumulative <- c(1, 2, 3, 4)
  expect_length(offset_captured_share(cumulative, 8), 4)
  expect_equal(offset_captured_share(cumulative, 8), cumulative / 8)
})

test_that("the offset-capture share is NA where the lifetime offset is not positive", {
  # Near a cure fraction of zero the denominator is A(lambda = 0), which is
  # small and may be of either sign. A ratio against it would be a confident
  # number standing in for the absence of one.
  expect_true(all(is.na(offset_captured_share(c(1, 2), -5e4))))
  expect_true(all(is.na(offset_captured_share(c(1, 2), 0))))
})

test_that("the offset-capture progression is a cost quantity: willingness to pay does not enter it", {
  # SPEC.md section 2a states this in terms -- a budget holds no QALYs. The
  # check is that D(lifetime) is P*(pi, h, lambda = 0) and that the progression
  # built from the cost streams reproduces it.
  cmb <- COMBINATIONS[[1]]
  treg <- run_treg_trace(0.5, 0.05, cmb$window, cmb$cap_on, GRIDS[[1]], RAW_DIR,
    sc_cost_stream_grid = STREAM_GRIDS[[1]])
  lifetime_offset <- price_star_usd_per_course(0.5, 0.05, 0, COMPARATORS[[1]], GRIDS[[1]],
    cmb$window, cmb$cap_on, RAW_DIR)
  d <- cost_offset_per_patient_usd(
    truncated_cost_usd_per_year(COMPARATORS[[1]]$discounted_cost_stream_usd, Inf),
    truncated_cost_usd_per_year(treg$discounted_cost_stream_usd, Inf))
  expect_lt(abs(d[length(d)] - lifetime_offset), 1)
  captured <- offset_captured_share(d, lifetime_offset)
  expect_lt(abs(captured[length(captured)] - 1), 1e-4)
})

# ------------------------------------------------ the module boundary -------

test_that("R/budget_impact.R supplies no default for the course price", {
  # The operative protection behind L8: the module cannot price anything on its
  # own, so a price must be handed to it by the analysis layer.
  env <- new.env()
  sys.source(repo_root_relative("R", "budget_impact.R"), envir = env)
  offenders <- character(0)
  for (nm in ls(env)) {
    obj <- get(nm, envir = env)
    if (!is.function(obj)) next
    f <- formals(obj)
    if ("price_usd_per_course" %in% names(f) && !identical(f[["price_usd_per_course"]], quote(expr = ))) {
      offenders <- c(offenders, nm)
    }
  }
  expect_length(offenders, 0)
})

test_that("no function in R/budget_impact.R can reach the manufacturing benchmark module", {
  # T12's own scope is unchanged and the BIA files are deliberately NOT added to
  # it: T12 greps for raw-data basenames as well as function names, and
  # analysis/run_bia.R legitimately reads a raw price file whose basename is one
  # of them. Adding the analysis layer to a guard scoped to R/ would fail on the
  # first run and invite weakening T12. The real invariant -- that the MODULE
  # cannot reach the benchmark -- is narrower, and it is asserted here.
  code <- readLines(repo_root_relative("R", "budget_impact.R"), warn = FALSE)
  code <- code[!grepl("^\\s*#", code)]
  for (nm in c("manufacturing_benchmark_usd_per_course", "tenham_analogy_anchors",
               "revealed_price_cogs_anchors", "tenham_eur_to_usd", "usd_per_eur")) {
    expect_false(any(grepl(nm, code, fixed = TRUE)), label = paste("budget_impact.R references", nm))
  }
  # And the same read from the other direction: sourcing the module alone
  # defines nothing that resolves to a benchmark export.
  env <- new.env()
  sys.source(repo_root_relative("R", "budget_impact.R"), envir = env)
  expect_false(any(grepl("benchmark", ls(env), fixed = TRUE)))
})

# ----------------------------------------------------- the A6 outputs -------

test_that("A6's two output files exist, are stamped against the committed spec, and carry the schema SPEC.md section 2a names", {
  bia_path <- repo_root_relative("output", "tables", "budget_impact.csv")
  recon_path <- repo_root_relative("output", "tables", "budget_impact_reconciliation.csv")
  expect_true(file.exists(bia_path))
  expect_true(file.exists(recon_path))

  bia <- read.csv(bia_path, comment.char = "#", stringsAsFactors = FALSE)
  for (col in c("reporting_horizon", "reporting_horizon_years", "horizon_class",
                "is_base_case_horizon", "discounted", "discounting_base_case",
                "terminal_uptake_share", "assumed_eligible_population_patients",
                "net_budget_impact_usd_per_year", "net_budget_impact_usd_pmpm",
                "offset_captured_share", "required_cure_fraction_all_treated")) {
    expect_true(col %in% names(bia), label = col)
  }
  # The BIA's horizon column is named `reporting_horizon_years` precisely so it
  # is never read as run_comparator_trace()'s `horizon_years` argument, which is
  # a different quantity in the same output directory.
  expect_false("horizon_years" %in% names(bia))
  # Both discounting columns at every horizon, without exception (L11).
  by_horizon <- table(bia$reporting_horizon, bia$discounted)
  expect_true(all(by_horizon > 0))
  # The base case is the 3-year horizon and nothing else (L10).
  expect_identical(sort(unique(bia$reporting_horizon[bia$is_base_case_horizon])), "3yr")
  # The uptake grid carries both endpoints (SPEC.md section 5).
  expect_true(all(c(0, 1) %in% bia$terminal_uptake_share))

  recon <- read.csv(recon_path, comment.char = "#", stringsAsFactors = FALSE)
  lifetime <- recon[recon$reporting_horizon == "lifetime", ]
  expect_gt(nrow(lifetime), 0)
  expect_true(all(abs(lifetime$agreement_usd) < 1))
  # The identity holds at the lifetime horizon and only there, so the frontier
  # route is populated there and nowhere else.
  expect_true(all(is.na(recon$frontier_route_usd[recon$reporting_horizon != "lifetime"])))
  expect_true(all(!is.na(lifetime$frontier_route_usd)))
})
