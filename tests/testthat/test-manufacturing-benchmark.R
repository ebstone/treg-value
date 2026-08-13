source_r("io_cache.R")
source_r("price_index.R")
source_r("manufacturing_benchmark.R")

RAW_DIR <- repo_root_relative("data", "raw")

test_that("euro figures convert at the source year's rate, then inflate in dollars", {
  fx <- read.csv(file.path(RAW_DIR, "fx_usd_per_eur_annual.csv"), stringsAsFactors = FALSE)
  rate_2018 <- fx$usd_per_eur_annual_average[fx$year == TENHAM_COST_YEAR]
  expected <- rebase_usd(1e3 * rate_2018, TENHAM_COST_YEAR, raw_dir = RAW_DIR)
  expect_equal(tenham_eur_to_usd(1e3, RAW_DIR), expected, tolerance = 1e-9)
  # Order matters: converting at the source year is not the same as
  # inflating in euros and converting at a later rate.
  wrong_order <- rebase_usd(1e3, TENHAM_COST_YEAR, raw_dir = RAW_DIR) *
    fx$usd_per_eur_annual_average[fx$year == TARGET_CURRENCY_YEAR]
  expect_false(isTRUE(all.equal(tenham_eur_to_usd(1e3, RAW_DIR), wrong_order)))
})

test_that("every ten Ham case study yields a positive per-treatment anchor, and the batch-amortised one is cheapest", {
  a <- tenham_analogy_anchors(RAW_DIR)
  expect_equal(nrow(a), 8)
  expect_true(all(a$cost_per_treatment_usd > 0))
  expect_true(all(is.finite(a$cost_per_treatment_usd)))

  # Case study 8 is the only one whose batch serves more than one treatment,
  # and amortisation is exactly why it should be the cheapest per treatment.
  amortised <- a[a$treatments_per_batch > 1, ]
  expect_equal(nrow(amortised), 1)
  expect_equal(amortised$cost_per_treatment_usd, min(a$cost_per_treatment_usd))
})

test_that("the benchmark is an ordered range with the allogeneic anchors inside it", {
  b <- manufacturing_benchmark_usd_per_course(RAW_DIR)
  expect_lt(b$low_usd, b$allogeneic_median_usd)
  expect_lt(b$allogeneic_median_usd, b$allogeneic_high_usd)
  expect_lt(b$allogeneic_high_usd, b$high_usd)
  expect_gt(b$n_allogeneic_anchors, 1)
})

test_that("T12: no pricing function reads the manufacturing benchmark -- zero call sites", {
  pricing_files <- c(
    repo_root_relative("R", "frontier.R"),
    repo_root_relative("R", "treg_arm.R"),
    repo_root_relative("R", "markov_engine.R"),
    repo_root_relative("R", "costs_utilities.R"),
    repo_root_relative("R", "dosing.R")
  )
  # Every exported name the benchmark module defines, plus the file itself.
  benchmark_names <- c(
    "manufacturing_benchmark", "tenham_analogy_anchors", "tenham_eur_to_usd",
    "revealed_price_cogs_anchors", "usd_per_eur", "TENHAM_COST_YEAR",
    "cell_therapy_revealed_prices", "fx_usd_per_eur"
  )
  for (f in pricing_files) {
    code <- readLines(f, warn = FALSE)
    code <- code[!grepl("^\\s*#", code)] # comments may discuss it; code may not read it
    for (nm in benchmark_names) {
      expect_false(any(grepl(nm, code, fixed = TRUE)),
        label = sprintf("%s references %s", basename(f), nm))
    }
  }
})

test_that("T12 fires: a pricing function that did read the benchmark would be caught", {
  offending <- c("price_star <- function() {", "  b <- manufacturing_benchmark_usd_per_course()", "  b$low_usd", "}")
  code <- offending[!grepl("^\\s*#", offending)]
  expect_true(any(grepl("manufacturing_benchmark", code, fixed = TRUE)))
})
