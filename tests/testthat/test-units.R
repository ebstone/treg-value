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

test_that("G2: _usd_per_year is listed before the generic _per_year, and its position is what keeps the guard watching (W7)", {
  # ORDERING, not membership, is the live property here. `has_permitted_unit_suffix()`
  # already accepted a `_usd_per_year` name before this suffix existed, because
  # such a name also ends in `_per_year`. What the position buys is the match in
  # `unnamed_converters()`, which takes hit[1]: appended at the end of the list
  # -- where W3's block put its own additions -- `_per_year` would win, and
  # `_per_year` is a DIMENSIONLESS_RATIO_SUFFIXES member, so annual dollar
  # figures would be classified as a dimensionless ratio and dropped out of
  # coverage. That is a guard that quietly stops watching, which is worse than
  # one that fires inconveniently.
  expect_true("_usd_per_year" %in% ALLOWED_UNIT_SUFFIXES)
  expect_lt(which(ALLOWED_UNIT_SUFFIXES == "_usd_per_year"),
    which(ALLOWED_UNIT_SUFFIXES == "_per_year"))
  # And the temptation the ordering exists to remove: quieting the guard by
  # declaring annual dollars dimensionless.
  expect_false("_usd_per_year" %in% DIMENSIONLESS_RATIO_SUFFIXES)
})

test_that("G2 fires: a per-course price combined with an annual dollar figure is flagged as an unnamed converter (W7 positive control)", {
  # The assertion that would have caught the reclassification. It passes only
  # while `_usd_per_year` outranks `_per_year`: under the appended ordering the
  # second argument matches `_per_year`, is treated as a dimensionless ratio,
  # and this function reads as having one value-bearing suffix -- unflagged, and
  # a genuine per-course-to-per-year conflation goes undetected.
  env <- new.env()
  eval(quote(spend <- function(price_usd_per_course, budget_usd_per_year) price_usd_per_course + budget_usd_per_year), envir = env)
  expect_length(unnamed_converters(env), 1)

  # The same combination declared as a converter is not flagged -- the guard
  # asks for the conversion to be named, not for it never to happen.
  named <- new.env()
  eval(quote(usd_per_course_to_usd_per_year <- function(price_usd_per_course, budget_usd_per_year) price_usd_per_course + budget_usd_per_year), envir = named)
  expect_length(unnamed_converters(named), 0)
})

test_that("G2: the W7 suffixes added for the budget impact frame collide with nothing", {
  # `_usd_pmpm` contains no "_per_" substring, so `suffix_numerator()` returns
  # "usd_pmpm" and it cannot share a numerator with `_usd` or `_usd_per_course`.
  # `_patients` and `_members` are counts of two different populations and are
  # deliberately distinct suffixes: the PMPM denominator is not the treated
  # population, and this project's recorded failure mode is a share of one
  # population reported as though it were a share of another.
  expect_equal(suffix_numerator("_usd_pmpm"), "usd_pmpm")
  expect_false(suffix_numerator("_usd_pmpm") %in% suffix_numerator(c("_usd", "_usd_per_course")))
  for (s in c("_usd_pmpm", "_patients", "_members")) {
    expect_true(s %in% ALLOWED_UNIT_SUFFIXES, label = s)
    expect_true(has_permitted_unit_suffix(paste0("x", s)), label = s)
  }
  counts <- new.env()
  eval(quote(cover <- function(eligible_patients, plan_members) eligible_patients / plan_members), envir = counts)
  expect_length(unnamed_converters(counts), 0)
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
