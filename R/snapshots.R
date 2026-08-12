# G4 -- no snapshots. Tests must assert properties, not the number a
# function happens to return in a given file's present state. Value
# snapshots (numeric literals of four or more significant figures) are
# permitted only inside tests/testthat/test-provenance.R, where a sourced
# SHA-256 or similar is legitimately a fixed value rather than a computed
# result being pinned.

#' Count significant figures in the text of a single numeric literal token
#' (as captured by R's parser, e.g. "1234", "12.30", "1e5", "10L").
count_sig_figs <- function(token) {
  token <- sub("[LiI]$", "", token) # integer/complex literal suffix
  token <- sub("[eE][+-]?[0-9]+$", "", token) # drop the exponent
  token <- sub("^[+-]", "", token)
  digits <- gsub("[^0-9]", "", token)
  digits <- sub("^0+", "", digits)
  nchar(digits)
}

#' Numeric literals with >= 4 significant figures appearing as actual code
#' tokens (not comments or strings) in `path`, as "path:line: literal".
find_snapshot_literals_in_file <- function(path, min_sig_figs = 4) {
  parsed <- tryCatch(parse(path, keep.source = TRUE), error = function(e) NULL)
  if (is.null(parsed)) return(character(0))
  pd <- utils::getParseData(parsed)
  nums <- pd[pd$token == "NUM_CONST", ]
  if (nrow(nums) == 0) return(character(0))
  hits <- vapply(nums$text, count_sig_figs, integer(1)) >= min_sig_figs
  sprintf("%s:%d: %s", path, nums$line1[hits], nums$text[hits])
}

#' Same, over every test-*.R file in `test_dir` except `exclude_files`.
find_snapshot_literals <- function(test_dir = "tests/testthat", exclude_files = "test-provenance.R", min_sig_figs = 4) {
  files <- list.files(test_dir, pattern = "^test-.*\\.R$", full.names = TRUE)
  files <- files[!basename(files) %in% exclude_files]
  unlist(lapply(files, find_snapshot_literals_in_file, min_sig_figs = min_sig_figs))
}
