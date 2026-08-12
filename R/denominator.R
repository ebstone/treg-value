# G3 -- denominators. Every probability-like parameter must declare an
# explicit denominator: what population it is a share of. `pi_cure`
# (SPEC.md L2) is a share of all treated patients, not of remission,
# response or any other subset.

#' Attach an explicit `denominator` attribute to a probability-like value.
with_denominator <- function(x, denominator) {
  stopifnot(is.character(denominator), length(denominator) == 1, nzchar(denominator))
  attr(x, "denominator") <- denominator
  x
}

#' The denominator a value was constructed against, or NA if none was
#' declared.
denominator_of <- function(x) {
  d <- attr(x, "denominator")
  if (is.null(d)) NA_character_ else d
}
