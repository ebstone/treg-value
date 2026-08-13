# The refractory population. SPEC.md section 2 makes it CO-PRIMARY --
# "Biologic-naive base case; refractory co-primary, run identically" -- not a
# sensitivity analysis, and section 5 also lists it as scenario S2.
#
# WHY THIS MATTERS FOR THIS PARTICULAR PRODUCT. The Treg therapy being
# priced is in trials for treatment-refractory disease (NCT06721962 enrols
# patients who have failed three or more advanced therapies), so the
# refractory arm is arguably the more relevant of the two populations, not a
# secondary check on the biologic-naive one.
#
# HOW THE ADJUSTMENT IS DERIVED. UNITI-1 and UNITI-2 ran the same protocol
# and the same endpoints in two populations differing only in prior therapy:
# anti-TNF-refractory and conventional-therapy-failure respectively. The
# ratio of their induction outcomes is therefore a population effect rather
# than a comparison across unrelated studies. Multipliers are computed here
# from the posted per-arm counts in data/raw/uniti_induction_outcomes.csv;
# nothing is stored pre-divided.
#
# Applied to INDUCTION ONLY. A refractory patient plausibly also does worse
# on maintenance, but IM-UNITI randomised only week-8 responders, so its
# maintenance figures are conditioned on induction success and cannot supply
# a like-for-like maintenance multiplier. Leaving maintenance unadjusted
# understates the refractory penalty on the comparator, which makes the
# comparator look better and the Treg product's justifiable price LOWER --
# the conservative direction. SPEC_AMENDMENTS.md records this.

REFRACTORY_ACTIVE_ARM <- "Ustekinumab ~6 mg/kg"
REFRACTORY_PLACEBO_ARM <- "Placebo"

#' Induction response and remission multipliers taking a
#' conventional-therapy-failure population to an anti-TNF-refractory one,
#' derived from the UNITI trials' own posted counts.
#'
#' `arm` selects which contrast: the active arm governs a biologic, the
#' placebo arm governs conventional therapy.
refractory_multipliers <- function(arm = REFRACTORY_ACTIVE_ARM, raw_dir = "data/raw") {
  d <- read_csv_cached(file.path(raw_dir, "uniti_induction_outcomes.csv"))
  d <- d[d$arm == arm, ]
  stopifnot(nrow(d) == 2)
  refractory <- d[d$trial == "UNITI-1", ]
  conventional <- d[d$trial == "UNITI-2", ]
  list(
    response = (refractory$n_clinical_response_week6 / refractory$n_randomised) /
      (conventional$n_clinical_response_week6 / conventional$n_randomised),
    remission = (refractory$n_clinical_remission_week8 / refractory$n_randomised) /
      (conventional$n_clinical_remission_week8 / conventional$n_randomised)
  )
}

#' Apply a refractory adjustment to one induction transition matrix.
#'
#' The Moderate-Severe row is the only one that moves: it is the only row
#' describing an induction outcome, the others being absorbing by
#' construction. Remission is scaled by the remission multiplier and total
#' response by the response multiplier; the responders who are not remitters
#' keep Aliyev's 50/50 split between Mild and Moderate-Severe Responder
#' (Induction assumption #7), and whatever is left stays in Moderate-Severe.
#'
#' Because both multipliers are below 1, more mass stays in Moderate-Severe,
#' which is what a refractory population means.
apply_refractory_to_induction <- function(m, multipliers) {
  row <- m["Moderate-Severe", ]
  remission <- row[["Remission"]] * multipliers$remission
  total_response <- (row[["Remission"]] + row[["Mild"]] + row[["Moderate-Severe Responder"]]) *
    multipliers$response
  non_remitter_response <- max(total_response - remission, 0)

  row[["Remission"]] <- remission
  row[["Mild"]] <- non_remitter_response / 2
  row[["Moderate-Severe Responder"]] <- non_remitter_response / 2
  row[["Moderate-Severe"]] <- 1 - remission - non_remitter_response
  stopifnot(row[["Moderate-Severe"]] >= 0)

  m["Moderate-Severe", ] <- row
  m
}

#' A refractory-adjusted induction matrix for one therapy, loaded and
#' adjusted in one step. `population` is "naive" or "refractory"; "naive"
#' returns Aliyev's matrix untouched, so a caller can switch populations
#' without branching.
load_induction_matrix_for_population <- function(therapy, population, raw_dir = "data/raw") {
  stopifnot(population %in% c("naive", "refractory"))
  m <- load_induction_matrix(therapy, raw_dir)
  if (population == "naive") return(m)
  apply_refractory_to_induction(m, refractory_multipliers(REFRACTORY_ACTIVE_ARM, raw_dir))
}
