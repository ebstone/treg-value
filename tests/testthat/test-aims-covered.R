source_r("md_table.R")
source_r("aims.R")

test_that("G6: SPEC.md's aims table parses with Aim and Output file columns", {
  aims <- parse_aims_table(repo_root_relative("SPEC.md"))
  expect_true(all(c("Aim", "Output file") %in% names(aims)))
  expect_true(nrow(aims) >= 5)
})

test_that("G6: every aim is covered, once output/tables/ is populated", {
  # Skip while none of SPEC.md's *aim-designated* output files exist yet --
  # not merely while output/tables/ is empty. W3 populated output/tables/
  # with intermediate artifacts (a comparator trace, a validation table)
  # that are explicitly not aim outputs; a skip keyed on "any CSV present"
  # would have flipped to a real (and wrong) failure the moment those
  # landed, well before any aim's own file exists. Still not a silent pass:
  # the skip message says exactly why, every run, until the first aim
  # output lands.
  aims <- parse_aims_table(repo_root_relative("SPEC.md"))
  any_aim_output_exists <- any(file.exists(file.path(repo_root_relative("."), aims[["Output file"]])))
  if (!any_aim_output_exists) {
    skip("no aim-designated output file exists yet -- guard binds once the first one lands")
  }
  problems <- uncovered_aims(
    repo_root_relative("SPEC.md"),
    repo_root_relative("SPEC_AMENDMENTS.md"),
    repo_root_relative(".")
  )
  expect_length(problems, 0)
})

test_that("aim output paths are parsed without markdown backticks", {
  # SPEC.md writes each path in backticks. If they survive parsing, every
  # file.exists() check tests a path that cannot exist, and the guard can
  # never pass no matter what has actually been produced.
  aims <- parse_aims_table(repo_root_relative("SPEC.md"))
  expect_false(any(grepl("`", aims[["Output file"]], fixed = TRUE)))
  expect_true(all(grepl("^output/", aims[["Output file"]])))
})

test_that("aim IDs are parsed without markdown bold markers", {
  # The mirror of the backticks test above, and the reason the amendment
  # branch was unreachable: SPEC.md writes aim IDs as **A1**, while
  # SPEC_AMENDMENTS.md refers to them unbolded, so an ID carrying its markers
  # can never match a properly recorded amendment.
  aims <- parse_aims_table(repo_root_relative("SPEC.md"))
  expect_false(any(grepl("*", aims$Aim, fixed = TRUE)))
  expect_true(all(grepl("^A[0-9]+$", aims$Aim)))
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

test_that("G6's amendment branch is reachable: an amended aim with no output file is not reported", {
  # The fixture's A3 has no output file and is recorded in its
  # SPEC_AMENDMENTS.md. Only a working amendment branch keeps it out of
  # `uncovered_aims()`. This test fails against a parser that leaves the bold
  # markers on, which is what made the branch dead code.
  fixture <- repo_root_relative("tests", "violations", "g6-aim-coverage")
  aims <- parse_aims_table(file.path(fixture, "SPEC.md"))
  a3_output <- aims[["Output file"]][aims$Aim == "A3"]
  expect_length(a3_output, 1)
  expect_false(file.exists(file.path(fixture, a3_output)))

  problems <- uncovered_aims(
    file.path(fixture, "SPEC.md"),
    file.path(fixture, "SPEC_AMENDMENTS.md"),
    fixture
  )
  expect_false("A3" %in% problems)
})
