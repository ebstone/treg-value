# A memoised CSV reader. The engine's loaders each re-read their source file
# on every call, which is invisible in a single deterministic run and
# dominant in a probabilistic one: a 500-iteration PSA rebuilding a
# standard-care age grid per iteration would otherwise re-parse the same
# handful of files tens of thousands of times.
#
# Keyed on the normalised path and the file's modification time, so editing
# a data file during a session invalidates the entry rather than serving a
# stale parse.

.csv_cache <- new.env(parent = emptyenv())

#' read.csv(), memoised on path and mtime.
read_csv_cached <- function(path, ...) {
  key <- paste(normalizePath(path, mustWork = TRUE), file.mtime(path))
  hit <- .csv_cache[[key]]
  if (!is.null(hit)) return(hit)
  value <- utils::read.csv(path, stringsAsFactors = FALSE, ...)
  .csv_cache[[key]] <- value
  value
}

#' Drop every memoised parse. Used by tests that write a data file and then
#' read it back within the same session.
clear_csv_cache <- function() rm(list = ls(.csv_cache), envir = .csv_cache)
