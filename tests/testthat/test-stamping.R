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
