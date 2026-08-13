# SPEC.md section 7 -- the analog comparison rule.
#
# pi_cure is assessed at this study's 12-week landmark. Published analogs
# report at their own timepoints. Comparing pi_cure directly against those
# figures is the same class of error as a conditional denominator: the right
# number against the wrong reference point. The comparison is therefore made
# on the derived quantity
#
#     still_in_drug_free_remission(t) = pi_cure * exp(-h * t)
#
# evaluated at each analog's own timepoint, never on pi_cure itself.

#' Share of all treated patients still in sustained drug-free remission at
#' `t_years_from_landmark`, given a cure fraction and an ongoing relapse
#' hazard. `t = 0` returns `pi_cure` itself, at the landmark and only there.
still_in_drug_free_remission <- function(pi_cure, h_per_year, t_years_from_landmark) {
  pi_cure * exp(-h_per_year * t_years_from_landmark)
}

# Published analogs and their own readout timepoints, measured from
# treatment. This study's landmark is 12 weeks (LANDMARK_CYCLES), so the
# time entering the decay is `readout - 12 weeks`.
ANALOG_READOUTS_WEEKS <- c(`PolTREG PTG-007` = 24 * (52 / 12), `Ovasave/CATS1` = 8)

#' The comparison table SPEC.md section 7 requires: each analog's own
#' timepoint, and this model's predicted drug-free-remission share at that
#' same timepoint -- not pi_cure.
#'
#' `Ovasave/CATS1` reads out at week 8, which PRECEDES this study's 12-week
#' landmark, so its row carries a negative time-from-landmark. The decay
#' formula run backwards would imply a drug-free-remission share above
#' pi_cure, which is not a claim this model can support: before the landmark
#' no patient has been declared cured, and the pre-landmark window is
#' conventional-therapy dynamics (L9), not drug-free remission. That row is
#' returned with `comparable = FALSE` and a NA share rather than an
#' extrapolated number. See SPEC_AMENDMENTS.md "Analog comparison before the
#' landmark".
analog_comparison_table <- function(pi_cure, h_per_year, landmark_weeks = LANDMARK_CYCLES * 2) {
  weeks <- ANALOG_READOUTS_WEEKS
  t_years <- (weeks - landmark_weeks) / 52
  comparable <- t_years >= 0
  share <- ifelse(comparable, still_in_drug_free_remission(pi_cure, h_per_year, t_years), NA_real_)
  data.frame(
    analog = names(weeks),
    readout_weeks_from_treatment = as.numeric(weeks),
    years_from_landmark = as.numeric(t_years),
    comparable = comparable,
    drug_free_remission_share = as.numeric(share),
    stringsAsFactors = FALSE
  )
}
