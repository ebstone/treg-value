source_r("stamp.R")

test_that("G5: analysis/ never calls write.csv/write_csv -- results go through stamp_output()", {
  # analysis/ is where results are produced, so the ban is absolute there.
  # R/ is library code: R/psa.R legitimately writes SAMPLED MODEL INPUTS to
  # a scratch directory, which are not results and must not carry a stamp
  # implying they are. The invariant that actually matters -- everything in
  # output/ is stamped -- is asserted directly in the next test, which is
  # stronger than grepping source text for a function name.
  files <- list.files(repo_root_relative("analysis"), pattern = "\\.R$", recursive = TRUE, full.names = TRUE)
  hits <- character(0)
  for (f in files) {
    lines <- readLines(f, warn = FALSE)
    bad <- grepl("\\bwrite\\.csv\\s*\\(|\\bwrite_csv\\s*\\(", lines)
    if (any(bad)) hits <- c(hits, paste0(f, ":", which(bad)))
  }
  expect_length(hits, 0)
})

test_that("G5: every file in output/ carries a commit hash and a SPEC.md hash", {
  outputs <- list.files(repo_root_relative("output"), pattern = "\\.csv$",
    recursive = TRUE, full.names = TRUE)
  skip_if(length(outputs) == 0, "no outputs written yet")
  for (f in outputs) {
    header <- readLines(f, n = 2, warn = FALSE)
    expect_match(header[1], "^# commit: [0-9a-f]{40}$", label = basename(f))
    expect_match(header[2], "^# spec_sha256: [0-9a-f]{64}$", label = basename(f))
  }
})

test_that("G5: every file in output/ was stamped against the SPEC.md now committed, not merely against some SPEC.md", {
  # SPEC.md section 11 promises that "a run whose spec hash differs from the
  # last committed one fails". Nothing asserted it: every other check in this
  # file matches the stamp's FORMAT, `^# spec_sha256: [0-9a-f]{64}$`, which a
  # stamp from any spec version satisfies equally well. So the guard that
  # actually binds -- results and the specification they were produced under
  # move together -- was documented and absent, and a spec amendment could ship
  # alongside outputs computed under the superseded text with the suite green.
  #
  # A red result here means the outputs are stale, not that the check is wrong:
  # re-run the analysis scripts against the committed SPEC.md.
  spec_hash <- digest::digest(repo_root_relative("SPEC.md"), algo = "sha256", file = TRUE)
  outputs <- list.files(repo_root_relative("output"), pattern = "\\.csv$",
    recursive = TRUE, full.names = TRUE)
  skip_if(length(outputs) == 0, "no outputs written yet")
  for (f in outputs) {
    header <- readLines(f, n = 2, warn = FALSE)
    expect_identical(header[2], sprintf("# spec_sha256: %s", spec_hash), label = basename(f))
  }
})

test_that("G5 fires: an output stamped under a superseded SPEC.md is caught", {
  # The falsification for the check above: a well-formed stamp carrying a hash
  # that is not this SPEC.md's passes every format assertion in this file and
  # must still be rejected.
  fake_output <- file.path(tempdir(), "g5_stale_spec")
  dir.create(fake_output, showWarnings = FALSE)
  on.exit(unlink(fake_output, recursive = TRUE), add = TRUE)
  superseded <- digest::digest("an earlier SPEC.md", algo = "sha256", serialize = FALSE)
  writeLines(c("# commit: 0123456789abcdef0123456789abcdef01234567",
    sprintf("# spec_sha256: %s", superseded), "a,b", "1,2"),
    file.path(fake_output, "stale.csv"))
  header <- readLines(file.path(fake_output, "stale.csv"), n = 2, warn = FALSE)
  expect_match(header[2], "^# spec_sha256: [0-9a-f]{64}$") # the format check passes
  spec_hash <- digest::digest(repo_root_relative("SPEC.md"), algo = "sha256", file = TRUE)
  expect_false(identical(header[2], sprintf("# spec_sha256: %s", spec_hash))) # the hash check does not
})

test_that("G5 fires: an unstamped file in an output directory is caught", {
  fake_output <- file.path(tempdir(), "g5_unstamped")
  dir.create(fake_output, showWarnings = FALSE)
  on.exit(unlink(fake_output, recursive = TRUE), add = TRUE)
  writeLines(c("a,b", "1,2"), file.path(fake_output, "unstamped.csv"))
  header <- readLines(file.path(fake_output, "unstamped.csv"), n = 2, warn = FALSE)
  expect_false(grepl("^# commit: [0-9a-f]{40}$", header[1]))
})

test_that("G5: stamp_output() stamps the commit hash and SPEC.md's sha256", {
  tmp <- tempfile(fileext = ".csv")
  on.exit(unlink(tmp))
  stamp_output(data.frame(a = 1), tmp, repo_root = repo_root_relative("."))
  header <- readLines(tmp, n = 2)
  expect_match(header[1], "^# commit: [0-9a-f]{40}$")
  expect_match(header[2], "^# spec_sha256: [0-9a-f]{64}$")
})

test_that("G5 fires: stamp_output() refuses when SPEC.md has uncommitted changes", {
  source(repo_root_relative("tests", "violations", "g5-stamping", "fixture.R"), local = TRUE)
  root <- build_dirty_spec_repo()
  on.exit(unlink(root, recursive = TRUE))
  expect_error(
    stamp_output(data.frame(a = 1), file.path(root, "out.csv"), repo_root = root, spec_path = file.path(root, "SPEC.md")),
    "uncommitted"
  )
})
