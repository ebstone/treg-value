source_r("prose.R")

test_that("G8: no banned status phrase in R/ or README.md", {
  hits <- find_status_prose_in_repo(repo_root_relative("R"), repo_root_relative("README.md"))
  expect_length(hits, 0)
})

test_that("G8 fires: a banned status phrase in a fixture file is caught", {
  hits <- find_status_prose(repo_root_relative("tests", "violations", "g8-no-stale-prose", "R", "bad_prose.R"))
  expect_true(length(hits) > 0)
})
