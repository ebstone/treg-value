source_r("denominator.R")

test_that("with_denominator() attaches and denominator_of() reads back the denominator", {
  x <- with_denominator(0.3, "all_treated")
  expect_identical(denominator_of(x), "all_treated")
})

test_that("denominator_of() returns NA for a value with no declared denominator", {
  expect_true(is.na(denominator_of(0.3)))
})

test_that("G3 scaffold: pi_cure, once defined in R/, carries denominator = all_treated", {
  # The cure mechanic lands in W4. Scaffolded now, per SPEC.md, so it binds
  # without further changes once R/*.R actually defines pi_cure.
  env <- source_r_dir(repo_root_relative("R"))
  if (!"pi_cure" %in% ls(env)) {
    skip("pi_cure not yet defined in R/ -- guard binds once the cure mechanic (W4) exists")
  }
  expect_identical(denominator_of(get("pi_cure", envir = env)), "all_treated")
})

test_that("G3 fires: pi_cure without denominator = all_treated is caught", {
  env <- source_r_dir(repo_root_relative("tests", "violations", "g3-denominator", "R"))
  expect_true("pi_cure" %in% ls(env))
  expect_false(identical(denominator_of(get("pi_cure", envir = env)), "all_treated"))
})
