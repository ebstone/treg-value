source_r("provenance.R")

test_that("G1: every file in data/raw/ has a valid .source.yaml sidecar", {
  problems <- check_raw_provenance(repo_root_relative("data", "raw"))
  expect_length(problems, 0)
})

test_that("G1: every file in data/derived/ has a producing script and a re-derivation test", {
  problems <- check_derived_provenance(
    repo_root_relative("data", "derived"),
    repo_root_relative("derive"),
    repo_root_relative("tests", "testthat")
  )
  expect_length(problems, 0)
})

test_that("G1 fires: a data/raw/ file with no sidecar is caught", {
  problems <- check_raw_provenance(repo_root_relative("tests", "violations", "g1-provenance", "data", "raw"))
  expect_true(length(problems) > 0)
  expect_true(any(grepl("no_sidecar.csv", problems)))
})

test_that("G1 fires: a sidecar missing a required field is caught", {
  problems <- check_raw_provenance(repo_root_relative("tests", "violations", "g1-provenance", "data", "raw"))
  expect_true(any(grepl("bad_sidecar.csv.source.yaml.*sha256", problems)))
})

test_that("G1 fires: a data/derived/ file with no producing script is caught", {
  problems <- check_derived_provenance(
    repo_root_relative("tests", "violations", "g1-provenance", "data", "derived"),
    repo_root_relative("tests", "violations", "g1-provenance", "derive"),
    repo_root_relative("tests", "violations", "g1-provenance", "tests")
  )
  expect_true(length(problems) > 0)
  expect_true(any(grepl("orphan.csv", problems)))
})
