source_r("snapshots.R")

test_that("G4: no test file (other than test-provenance.R) carries a >=4-sig-fig literal", {
  hits <- find_snapshot_literals(repo_root_relative("tests", "testthat"))
  expect_length(hits, 0)
})

test_that("G4 fires: a smuggled snapshot literal in a fixture test file is caught", {
  hits <- find_snapshot_literals(
    repo_root_relative("tests", "violations", "g4-no-snapshots"),
    exclude_files = character(0)
  )
  expect_true(length(hits) > 0)
})
