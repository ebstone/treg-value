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
