# Auto-loaded by testthat::test_dir() before any test-*.R file runs.
# test_dir() sets the working directory to tests/testthat/ for the duration
# of every test, so repository-root-relative paths need this indirection
# (same convention as the sibling treg-cd repo).

repo_root_relative <- function(...) file.path("..", "..", ...)

# Source a single script from R/ into the caller's frame.
source_r <- function(..., envir = parent.frame()) {
  source(repo_root_relative("R", ...), local = envir)
}

# Source a single script from derive/ into the caller's frame.
source_derive <- function(..., envir = parent.frame()) {
  source(repo_root_relative("derive", ...), local = envir)
}

# Source every *.R file directly under `dir` (sorted, so earlier files'
# constants are available to later ones) into one fresh environment and
# return it. Used by guards that lint or introspect R/'s functions and
# objects (G2, G3, G7) rather than run a pipeline.
source_r_dir <- function(dir) {
  files <- sort(list.files(dir, pattern = "\\.R$", full.names = TRUE))
  env <- new.env()
  for (f in files) sys.source(f, envir = env)
  env
}
