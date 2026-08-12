source_r("md_table.R")
source_r("aims.R")

test_that("G6: SPEC.md's aims table parses with Aim and Output file columns", {
  aims <- parse_aims_table(repo_root_relative("SPEC.md"))
  expect_true(all(c("Aim", "Output file") %in% names(aims)))
  expect_true(nrow(aims) >= 5)
})

test_that("G6: every aim is covered, once output/tables/ is populated", {
  output_tables <- repo_root_relative("output", "tables")
  populated <- length(list.files(output_tables, pattern = "\\.csv$")) > 0
  if (!populated) {
    skip("output/tables/ is empty -- no aim can be covered yet on an empty model; guard binds once analysis code runs")
  }
  problems <- uncovered_aims(
    repo_root_relative("SPEC.md"),
    repo_root_relative("SPEC_AMENDMENTS.md"),
    repo_root_relative(".")
  )
  expect_length(problems, 0)
})

test_that("G6 fires: a populated output/tables/ that still leaves an aim uncovered is caught", {
  fixture <- repo_root_relative("tests", "violations", "g6-aim-coverage")
  problems <- uncovered_aims(
    file.path(fixture, "SPEC.md"),
    file.path(fixture, "SPEC_AMENDMENTS.md"),
    fixture
  )
  expect_true(length(problems) > 0)
  expect_true("A2" %in% problems)
})
