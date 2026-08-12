source_r("md_table.R")
source_r("open_items.R")

test_that("open_item_arg_names() parses OPEN_QUESTIONS.md's Arg name column", {
  names_ <- open_item_arg_names(repo_root_relative("OPEN_QUESTIONS.md"))
  expect_true(length(names_) >= 6)
  expect_true(all(nzchar(names_)))
})

test_that("G7: no function in R/ supplies a default for an open item's argument", {
  arg_names <- open_item_arg_names(repo_root_relative("OPEN_QUESTIONS.md"))
  env <- source_r_dir(repo_root_relative("R"))
  expect_length(defaulted_open_item_args(env, arg_names), 0)
})

test_that("G7 fires: fixture supplying a default for an open item's argument is caught", {
  arg_names <- open_item_arg_names(repo_root_relative("OPEN_QUESTIONS.md"))
  env <- source_r_dir(repo_root_relative("tests", "violations", "g7-no-defaults", "R"))
  offenders <- defaulted_open_item_args(env, arg_names)
  expect_true(length(offenders) > 0)
  expect_true(any(grepl("eligible_population_fractions", offenders)))
})
