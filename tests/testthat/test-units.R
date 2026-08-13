source_r("units.R")

test_that("G2: every numeric object in R/ carries a permitted unit suffix", {
  env <- source_r_dir(repo_root_relative("R"))
  expect_length(unsuffixed_numerics(env), 0)
})

test_that("G2: functions combining differently-suffixed arguments are named converters", {
  env <- source_r_dir(repo_root_relative("R"))
  expect_length(unnamed_converters(env), 0)
})

test_that("G2 fires: an unsuffixed numeric and an unnamed converter are caught", {
  env <- source_r_dir(repo_root_relative("tests", "violations", "g2-units", "R"))
  expect_true(length(unsuffixed_numerics(env)) > 0)
  expect_true(length(unnamed_converters(env)) > 0)
})

test_that("G2: a function combining a value-bearing suffix with a dimensionless ratio is not flagged as an unnamed converter (W3)", {
  env <- new.env()
  # discounting a per-cycle cost by a dimensionless factor does not convert
  # its unit -- the result is still cost-flavoured, just smaller.
  eval(quote(discount_cost <- function(x_usd_per_cycle, factor_discount_factor) x_usd_per_cycle * factor_discount_factor), envir = env)
  expect_length(unnamed_converters(env), 0)
})

test_that("G2 fires: a function genuinely combining two value-bearing suffixes without converter naming is still caught (W3 regression check)", {
  env <- new.env()
  eval(quote(bad_combo <- function(x_usd_per_dose, y_usd_per_cycle) x_usd_per_dose + y_usd_per_cycle), envir = env)
  expect_true(length(unnamed_converters(env)) > 0)
})

test_that("G2 flags same-numerator conflation but not different-kind arguments (W4 narrowing)", {
  # Same numerator, different denominator -- the documented defect class.
  same_numerator <- new.env()
  eval(quote(bad <- function(a_usd_per_dose, b_usd_per_course) a_usd_per_dose + b_usd_per_course), envir = same_numerator)
  expect_length(unnamed_converters(same_numerator), 1)

  # Different kinds entirely -- a duration beside an age. No swap is
  # possible, and flagging these trained the guard on orchestrators.
  different_kinds <- new.env()
  eval(quote(orchestrate <- function(window_weeks, start_age_years) window_weeks + start_age_years), envir = different_kinds)
  expect_length(unnamed_converters(different_kinds), 0)
})

test_that("suffix_numerator() strips the denominator", {
  expect_equal(suffix_numerator(c("_usd_per_dose", "_usd_per_course", "_usd")), c("usd", "usd", "usd"))
  expect_equal(suffix_numerator(c("_weeks", "_age_years")), c("weeks", "age_years"))
})

test_that("G2: a function taking three or more independently value-bearing arguments is not flagged (W3, orchestrator functions)", {
  env <- new.env()
  # e.g. a trace orchestrator using a window, a horizon and an age as three
  # independent inputs, never converting between them -- not a pairwise
  # conflation risk the way exactly two differently-suffixed args is.
  eval(quote(orchestrate <- function(window_weeks, horizon_years, start_age_years) window_weeks + horizon_years + start_age_years), envir = env)
  expect_length(unnamed_converters(env), 0)
})
