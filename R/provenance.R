# G1 -- provenance. Every file in data/raw/ carries a `.source.yaml`
# sidecar (citation, retrieval date, SHA-256, status). Every file in
# data/derived/ is produced by a script in derive/ and re-derived by a test
# -- never hand-written.
#
# Schema below follows data/raw/cms_asp_infliximab_2026.csv.source.yaml, the
# real precedent W2_session_prompt.md points future sessions at ("follow the
# shape of the ASP sidecar already in data/raw/"), not W1's originally-guessed
# field names -- reconciled 2026-08-12 when that file was merged in. Two
# differences from the W1 guess: the retrieval date field may be named
# `retrieved` (as well as `retrieval_date`), and `table_or_page` is optional
# rather than required, since a source like a pricing file has no table or
# page to name -- it has a quarter, recorded inside `citation` instead.

# Each element is either a single required field name, or a character vector
# of alternative names of which at least one must be present and non-empty.
REQUIRED_SOURCE_FIELDS <- list("citation", "sha256", "status", c("retrieval_date", "retrieved"))
OPTIONAL_SOURCE_FIELDS <- c("table_or_page")

is_sidecar <- function(path) grepl("\\.source\\.yaml$", path)
is_gitkeep <- function(path) grepl("\\.gitkeep$", path)

#' Is field `name` absent, NULL, or -- accounting for nested fields like the
#' ASP sidecar's `citation` object -- entirely blank once flattened?
field_is_empty <- function(meta, name) {
  if (!(name %in% names(meta)) || is.null(meta[[name]])) return(TRUE)
  vals <- trimws(as.character(unlist(meta[[name]])))
  !any(nzchar(vals))
}

#' Validate one `.source.yaml` sidecar against the schema and, when the data
#' file it documents exists, against that file's actual SHA-256. Returns
#' character(0) if valid, else a vector of problem descriptions.
validate_source_yaml <- function(data_path, sidecar_path = paste0(data_path, ".source.yaml")) {
  if (!file.exists(sidecar_path)) {
    return(sprintf("%s: missing sidecar %s", data_path, sidecar_path))
  }
  meta <- tryCatch(yaml::read_yaml(sidecar_path), error = function(e) NULL)
  if (is.null(meta)) {
    return(sprintf("%s: unparseable sidecar %s", data_path, sidecar_path))
  }

  problems <- character(0)
  for (field in REQUIRED_SOURCE_FIELDS) {
    satisfied <- any(!vapply(field, field_is_empty, logical(1), meta = meta))
    if (!satisfied) {
      label <- if (length(field) > 1) paste0("one of: ", paste(field, collapse = "/")) else field
      problems <- c(problems, sprintf("%s: sidecar missing/empty required field (%s)", sidecar_path, label))
    }
  }
  empty_optional <- Filter(function(f) f %in% names(meta) && field_is_empty(meta, f), OPTIONAL_SOURCE_FIELDS)
  if (length(empty_optional)) {
    problems <- c(problems, sprintf(
      "%s: sidecar has empty field(s): %s", sidecar_path, paste(empty_optional, collapse = ", ")
    ))
  }
  if ("sha256" %in% names(meta) && file.exists(data_path)) {
    actual <- digest::digest(data_path, algo = "sha256", file = TRUE)
    if (!identical(tolower(as.character(meta$sha256)), tolower(actual))) {
      problems <- c(problems, sprintf(
        "%s: sha256 mismatch -- recorded %s, actual %s", sidecar_path, meta$sha256, actual
      ))
    }
  }
  problems
}

#' G1a: every file in `raw_dir` (excluding sidecars and .gitkeep) has a
#' valid sidecar.
check_raw_provenance <- function(raw_dir = "data/raw") {
  files <- list.files(raw_dir, full.names = TRUE, recursive = TRUE)
  files <- files[!is_sidecar(files) & !is_gitkeep(files)]
  unlist(lapply(files, validate_source_yaml))
}

#' G1b: every file in `derived_dir` (excluding .gitkeep) is produced by a
#' same-stem script in `derive_dir` and referenced by a re-derivation test
#' somewhere in `test_dir`.
check_derived_provenance <- function(derived_dir = "data/derived", derive_dir = "derive", test_dir = "tests/testthat") {
  files <- list.files(derived_dir, full.names = TRUE, recursive = TRUE)
  files <- files[!is_gitkeep(files)]
  if (length(files) == 0) return(character(0))

  derive_scripts <- list.files(derive_dir, pattern = "\\.R$", full.names = TRUE, recursive = TRUE)
  test_files <- list.files(test_dir, pattern = "\\.R$", full.names = TRUE, recursive = TRUE)
  test_corpus <- paste(unlist(lapply(test_files, function(f) {
    paste(readLines(f, warn = FALSE), collapse = "\n")
  })), collapse = "\n")

  problems <- character(0)
  for (f in files) {
    stem <- tools::file_path_sans_ext(basename(f))
    has_script <- any(grepl(stem, basename(derive_scripts), fixed = TRUE))
    if (!has_script) problems <- c(problems, sprintf("%s: no producing script in %s", f, derive_dir))
    has_test <- grepl(basename(f), test_corpus, fixed = TRUE) || grepl(stem, test_corpus, fixed = TRUE)
    if (!has_test) problems <- c(problems, sprintf("%s: no re-derivation test references it", f))
  }
  problems
}
