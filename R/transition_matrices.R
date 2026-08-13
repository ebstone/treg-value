# Loads Aliyev's induction and maintenance transition matrices from
# data/raw/ into named, ordered matrices the Markov engine can multiply
# directly, and renormalises each row to sum to exactly 1 -- SPEC_AMENDMENTS.md
# "Transition-row renormalisation", 2026-08-13. Renormalisation happens only
# here, visibly, never silently inside the engine (W3 trap 4).

# Canonical state order, matching SPEC.md section 3 exactly.
MAINTENANCE_STATES <- c("Remission", "Mild", "Moderate-Severe Responder", "Moderate-Severe", "Surgery", "Death")
INDUCTION_STATES <- c("Remission", "Mild", "Moderate-Severe Responder", "Moderate-Severe")

#' Renormalise a square transition matrix so every row sums to exactly 1,
#' dividing each row by its own raw sum -- the minimum-distortion correction
#' for source rounding, not an invented adjustment.
renormalize_transition_matrix <- function(m) {
  row_sums <- rowSums(m)
  sweep(m, 1, row_sums, "/")
}

#' Aliyev's induction transition matrix for one therapy: a 4x4 matrix over
#' INDUCTION_STATES, renormalised. `therapy` is one of "UST", "IFX", "ADA".
load_induction_matrix <- function(therapy, raw_dir = "data/raw") {
  df <- read_csv_cached(file.path(raw_dir, "aliyev2019_induction_transitions.csv"))
  df <- df[df$therapy == therapy, ]
  stopifnot(nrow(df) == length(INDUCTION_STATES))
  m <- matrix(0, nrow = length(INDUCTION_STATES), ncol = length(INDUCTION_STATES),
    dimnames = list(INDUCTION_STATES, INDUCTION_STATES))
  col_map <- c(
    to_moderate_severe = "Moderate-Severe", to_moderate_severe_responder = "Moderate-Severe Responder",
    to_mild = "Mild", to_remission = "Remission"
  )
  for (i in seq_len(nrow(df))) {
    from_state <- df$from_state[i]
    for (col in names(col_map)) m[from_state, col_map[[col]]] <- df[[col]][i]
  }
  renormalize_transition_matrix(m)
}

#' Aliyev's maintenance transition matrix for one therapy: a 6x6 matrix over
#' MAINTENANCE_STATES, renormalised. `therapy` is one of "UST", "IFX", "ADA",
#' "CT". Biologic therapies (UST/IFX/ADA) have no "from Moderate-Severe" row
#' in the source -- Maintenance assumption #2 (aliyev2019_assumptions.csv):
#' a biologic-maintenance patient who reaches Moderate-Severe is switched to
#' CT before that row would ever be used. That row is left as NA here, not
#' zero or a copy of another row, so any accidental use of it errors loudly
#' rather than silently returning a wrong number -- the direct fix for the
#' historical bug (trap 5) where the retired workbook populated this row
#' with induction-phase values instead of leaving it undefined.
load_maintenance_matrix <- function(therapy, raw_dir = "data/raw") {
  df <- read_csv_cached(file.path(raw_dir, "aliyev2019_maintenance_transitions.csv"))
  df <- df[df$therapy == therapy, ]
  m <- matrix(NA_real_, nrow = length(MAINTENANCE_STATES), ncol = length(MAINTENANCE_STATES),
    dimnames = list(MAINTENANCE_STATES, MAINTENANCE_STATES))
  col_map <- c(
    to_moderate_severe = "Moderate-Severe", to_moderate_severe_responder = "Moderate-Severe Responder",
    to_mild = "Mild", to_remission = "Remission", to_surgery = "Surgery", to_death = "Death"
  )
  for (i in seq_len(nrow(df))) {
    from_state <- df$from_state[i]
    for (col in names(col_map)) m[from_state, col_map[[col]]] <- df[[col]][i]
  }
  defined_rows <- MAINTENANCE_STATES[!is.na(m[, 1])]
  m[defined_rows, ] <- renormalize_transition_matrix(m[defined_rows, , drop = FALSE])
  m
}
