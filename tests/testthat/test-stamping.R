source_r("stamp.R")

test_that("G5: write.csv/write_csv never appear in R/ or analysis/", {
  files <- list.files(
    c(repo_root_relative("R"), repo_root_relative("analysis")),
    pattern = "\\.R$", recursive = TRUE, full.names = TRUE
  )
  hits <- character(0)
  for (f in files) {
    lines <- readLines(f, warn = FALSE)
    bad <- grepl("\\bwrite\\.csv\\s*\\(|\\bwrite_csv\\s*\\(", lines)
    if (any(bad)) hits <- c(hits, paste0(f, ":", which(bad)))
  }
  expect_length(hits, 0)
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
