# G1 -- provenance. Every file in data/raw/ carries a `.source.yaml`
# sidecar (citation, table or page, retrieval date, SHA-256). Every file in
# data/derived/ is produced by a script in derive/ and re-derived by a test
# -- never hand-written.

REQUIRED_SOURCE_FIELDS <- c("citation", "table_or_page", "retrieval_date", "sha256")

is_sidecar <- function(path) grepl("\\.source\\.yaml$", path)
is_gitkeep <- function(path) grepl("\\.gitkeep$", path)

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
  missing_fields <- setdiff(REQUIRED_SOURCE_FIELDS, names(meta))
  if (length(missing_fields)) {
    problems <- c(problems, sprintf(
      "%s: sidecar missing field(s): %s", sidecar_path, paste(missing_fields, collapse = ", ")
    ))
  }
  present_fields <- intersect(names(meta), REQUIRED_SOURCE_FIELDS)
  empty_fields <- present_fields[vapply(present_fields, function(f) {
    is.null(meta[[f]]) || !nzchar(trimws(as.character(meta[[f]])))
  }, logical(1))]
  if (length(empty_fields)) {
    problems <- c(problems, sprintf(
      "%s: sidecar has empty field(s): %s", sidecar_path, paste(empty_fields, collapse = ", ")
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
