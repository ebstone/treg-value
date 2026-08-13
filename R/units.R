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
  "_cells_per_kg",
  # Added in W3 (comparator Markov engine) -- each is a genuine new unit the
  # W1-era list didn't anticipate, not a workaround for an inconvenient guard.
  "_usd", # an aggregated/total dollar figure -- distinct from any _usd_per_* rate
  "_utility", # a dimensionless EQ-5D-style quality-of-life weight, [0,1]
  "_discount_factor", # a dimensionless multiplier, e.g. 1.03^-t
  "_prob_1yr", # an annual probability (life-table qx) -- distinct from _prob_2wk
  "_life_years", # accumulated life-years -- distinct from _qaly (utility-weighted)
  "_age_years", # a person's age in years (a point, not a duration like _weeks/_cycles)
  "_years", # a plain duration in years -- distinct from _age_years (a point) and _life_years (accumulated, utility-relevant)
  "_kg", # body weight, kilograms
  "_mg", # a drug dose mass, milligrams
  "_mg_per_kg" # a weight-scaled dosing rate
)

# Suffixes naming a dimensionless ratio/weight/rate rather than a stock or
# flow of value. A function multiplying a value by one of these (e.g.
# discounting a cost, or weighting a cycle by a utility) does not change
# what the *other* argument's suffix means, unlike a real unit conversion
# (PMPM -> per-cycle) -- so combining one of these with any other suffix does
# not by itself require the function to be a named converter.
DIMENSIONLESS_RATIO_SUFFIXES <- c(
  "_prob_2wk", "_prob_1yr", "_per_year", "_utility", "_discount_factor",
  # Willingness to pay is an exchange rate, not a quantity of money the
  # model spends or receives. Its entire job is to bridge `_qaly` and
  # `_usd`, so its presence in a signature is a conversion being declared
  # rather than a conflation risk -- unlike `_usd_per_dose` vs
  # `_usd_per_course`, which are two prices of two different things.
  "_usd_per_qaly"
)

#' The numerator of a unit suffix: everything before `_per_`, or the whole
#' suffix when it names no denominator. `_usd_per_dose`, `_usd_per_course`
#' and `_usd` all share the numerator "usd" and are therefore mutually
#' confusable; `_weeks` and `_age_years` do not.
suffix_numerator <- function(suffixes) {
  sub("^_", "", sub("_per_.*$", "", suffixes))
}

#' Does `name` end in a permitted unit suffix? Matched case-insensitively --
#' R constants are conventionally UPPER_SNAKE_CASE (e.g. `MODEL_START_AGE_YEARS`,
#' matching `ALLOWED_UNIT_SUFFIXES` itself), while function arguments are
#' conventionally lower_snake_case; the suffix vocabulary is one vocabulary
#' either way, not two.
has_permitted_unit_suffix <- function(name, suffixes = ALLOWED_UNIT_SUFFIXES) {
  any(vapply(suffixes, function(s) endsWith(tolower(name), tolower(s)), logical(1)))
}

#' Is `name` a legitimate unit converter? Its own name must contain the bare
#' form of at least two permitted suffixes, joined by `_to_`. Case-insensitive,
#' for the same reason as `has_permitted_unit_suffix()`.
is_named_converter <- function(name, suffixes = ALLOWED_UNIT_SUFFIXES) {
  bare <- sub("^_", "", suffixes)
  name <- tolower(name)
  hits <- vapply(bare, function(s) grepl(tolower(s), name, fixed = TRUE), logical(1))
  sum(hits) >= 2 && grepl("_to_", name, fixed = TRUE)
}

#' Numeric, non-function objects in `env` whose name lacks a permitted
#' suffix.
#' Numeric, non-function objects in `env` whose name lacks a permitted
#' suffix. Objects carrying a declared `denominator` attribute are exempt:
#' those are probability-like parameters governed by guard 3, which demands
#' something strictly stronger than a unit suffix -- an explicit statement of
#' what population the number is a share of. `pi_cure` is unitless by
#' SPEC.md section 1's own table; its denominator, not its unit, is the
#' thing that has twice gone wrong here.
unsuffixed_numerics <- function(env, suffixes = ALLOWED_UNIT_SUFFIXES) {
  names_ <- ls(env)
  numeric_names <- Filter(function(n) {
    v <- get(n, envir = env)
    is.numeric(v) && !is.function(v)
  }, names_)
  Filter(function(n) {
    # Attribute read inline rather than via denominator.R's accessor, so
    # this guard has no load-order dependency on another guard's file.
    if (!is.null(attr(get(n, envir = env), "denominator"))) return(FALSE)
    !has_permitted_unit_suffix(n, suffixes)
  }, numeric_names)
}

#' Names of functions in `env` that combine *exactly two* differently-
#' suffixed arguments without naming themselves as a converter.
#' Dimensionless ratios (`DIMENSIONLESS_RATIO_SUFFIXES`) are excluded from
#' the count: a function that discounts a cost or weights a cycle by a
#' utility does not change what the other, value-bearing argument's suffix
#' means, so it is not a unit conversion in the PMPM-to-per-cycle sense this
#' guard exists to police.
#'
#' Exactly two, not two-or-more: the historical bug this guard is modeled on
#' (a dose-cost figure silently conflated with a per-course figure) is
#' inherently pairwise -- two comparable-sounding quantities, one substituted
#' for the other. A function needing three or more differently-unit'd
#' inputs (e.g. a trace orchestrator taking a week-denominated window, a
#' year-denominated horizon and an age) is characteristically a driver
#' function using each independently, not a pairwise conflation risk; a
#' >=2 threshold flagged exactly this kind of function as an unnamed
#' converter (W3, `run_comparator_trace`) despite it doing no unit
#' conversion at all.
unnamed_converters <- function(env, suffixes = ALLOWED_UNIT_SUFFIXES, ratio_suffixes = DIMENSIONLESS_RATIO_SUFFIXES) {
  fn_names <- Filter(function(n) is.function(get(n, envir = env)), ls(env))
  Filter(function(n) {
    fn <- get(n, envir = env)
    arg_names <- names(formals(fn))
    suffixes_used <- unique(Filter(Negate(is.na), vapply(arg_names, function(a) {
      hit <- suffixes[vapply(suffixes, function(s) endsWith(tolower(a), tolower(s)), logical(1))]
      if (length(hit)) hit[1] else NA_character_
    }, character(1))))
    value_bearing <- setdiff(suffixes_used, ratio_suffixes)
    # Flag only when two value-bearing suffixes share a NUMERATOR and differ
    # in denominator -- `_usd_per_dose` against `_usd_per_course`, or either
    # against a bare `_usd` total. That is the documented defect class: the
    # ten Ham sidecar records "a per-course figure was previously relabelled
    # as a per-dose retail price". A duration in weeks beside an age in
    # years, or dollars beside QALYs, are different kinds that nobody
    # silently swaps, and flagging them only trained the guard to cry wolf
    # at orchestrator functions.
    if (!any(duplicated(suffix_numerator(value_bearing)))) return(FALSE)
    if (is_named_converter(n, suffixes)) return(FALSE)
    # A function whose OWN name ends in a permitted unit suffix has declared
    # what it returns. Combining a rate with a total to produce a stated
    # total is accumulation, not conflation -- `one_cycle_cost_usd()` adding
    # a per-cycle drug rate to a per-dose lump to yield that cycle's dollars
    # is correct and self-documenting. The conflation this guard exists to
    # catch is an undeclared swap between two denominators of the same
    # numerator, which is precisely what an undeclared return unit hides.
    !has_permitted_unit_suffix(n, suffixes)
  }, fn_names)
}
