# G2 -- units. Every exported numeric identifier in R/ must end in one of
# these suffixes. Only a "converter" -- a function that names both units in
# its own name, e.g. `usd_per_dose_to_usd_per_course` -- may combine values
# that carry two different suffixes.

ALLOWED_UNIT_SUFFIXES <- c(
  "_usd_per_course",
  "_usd_per_dose",
  "_usd_per_cycle",
  "_usd_per_qaly",
  "_prob_2wk",
  "_per_year",
  "_qaly",
  "_cycles",
  "_weeks",
  "_cells_per_kg"
)

#' Does `name` end in a permitted unit suffix?
has_permitted_unit_suffix <- function(name, suffixes = ALLOWED_UNIT_SUFFIXES) {
  any(vapply(suffixes, function(s) endsWith(name, s), logical(1)))
}

#' Is `name` a legitimate unit converter? Its own name must contain the bare
#' form of at least two permitted suffixes, joined by `_to_`.
is_named_converter <- function(name, suffixes = ALLOWED_UNIT_SUFFIXES) {
  bare <- sub("^_", "", suffixes)
  hits <- vapply(bare, function(s) grepl(s, name, fixed = TRUE), logical(1))
  sum(hits) >= 2 && grepl("_to_", name, fixed = TRUE)
}

#' Numeric, non-function objects in `env` whose name lacks a permitted
#' suffix.
unsuffixed_numerics <- function(env, suffixes = ALLOWED_UNIT_SUFFIXES) {
  names_ <- ls(env)
  numeric_names <- Filter(function(n) {
    v <- get(n, envir = env)
    is.numeric(v) && !is.function(v)
  }, names_)
  Filter(function(n) !has_permitted_unit_suffix(n, suffixes), numeric_names)
}

#' Names of functions in `env` that combine two differently-suffixed
#' arguments without naming themselves as a converter.
unnamed_converters <- function(env, suffixes = ALLOWED_UNIT_SUFFIXES) {
  fn_names <- Filter(function(n) is.function(get(n, envir = env)), ls(env))
  Filter(function(n) {
    fn <- get(n, envir = env)
    arg_names <- names(formals(fn))
    suffixes_used <- unique(Filter(Negate(is.na), vapply(arg_names, function(a) {
      hit <- suffixes[vapply(suffixes, function(s) endsWith(a, s), logical(1))]
      if (length(hit)) hit[1] else NA_character_
    }, character(1))))
    length(suffixes_used) >= 2 && !is_named_converter(n, suffixes)
  }, fn_names)
}
