# Probabilistic analysis (SPEC.md aim A5).
#
# WHAT IS SAMPLED, AND FROM WHAT. Every distribution here is Aliyev's own,
# read from Suppl. Table 2's `distribution`/`alpha`/`beta` columns as
# transcribed in data/raw/aliyev2019_source_parameters.csv. Nothing is
# invented:
#
#   health-state costs   Gamma(shape, scale) exactly as Aliyev fitted them
#                        (method of moments, per that table's footnote)
#   utilities            Remission from Aliyev's Uniform(0.66, 0.98); the
#                        other states scaled by Suppl. Table 5's own ratios,
#                        so the ordering Remission > Mild > M-SR > M-S is
#                        preserved in every draw rather than crossing over
#   comparator price     Uniform across the three infliximab biosimilar
#                        payment limits actually listed in the current CMS
#                        ASP file -- real dispersion in what a payer's
#                        patients receive, distinct from the C10 decision
#                        that fixes the deterministic base case
#   transition rows      Dirichlet, sampled WHOLE (A5's own wording) so each
#                        draw is a valid row summing to one
#
# WHAT IS NOT SAMPLED. pi_cure, h and lambda carry no prior: SPEC.md section
# 5 states they are swept, not assumed, and places no prior on any of them.
# The PSA is therefore run CONDITIONAL on a stated (pi, h, lambda) and
# reports uncertainty in A and B arising from the sourced parameters. A
# distribution over pi_cure would be a substantive new assumption, not an
# implementation detail, and section 5 forbids it without an amendment.
#
# Injection is by `raw_dir`: each draw writes its sampled inputs into a
# scratch copy of data/raw/ and runs the ordinary engine against it. The
# engine is not special-cased for PSA, so what is exercised here is the same
# code path the deterministic results come from.

#' Effective sample size behind a Dirichlet draw of a transition row, taken
#' as the median alpha+beta across Aliyev's own Beta-distributed proportions
#' -- his own precision, rather than a concentration invented here.
dirichlet_effective_n <- function(raw_dir = "data/raw") {
  p <- read_csv_cached(file.path(raw_dir, "aliyev2019_source_parameters.csv"))
  b <- p[grepl("Beta", p$distribution), ]
  stats::median(as.numeric(b$alpha) + as.numeric(b$beta))
}

#' One Dirichlet draw, via the standard normalised-Gamma construction.
rdirichlet_row <- function(alpha) {
  g <- stats::rgamma(length(alpha), shape = pmax(alpha, 1e-8), rate = 1)
  if (sum(g) <= 0) return(alpha / sum(alpha))
  g / sum(g)
}

#' Resample every defined row of a maintenance transition table whole.
sample_maintenance_transitions <- function(df, effective_n) {
  cols <- c("to_moderate_severe", "to_moderate_severe_responder", "to_mild",
    "to_remission", "to_surgery", "to_death")
  for (i in seq_len(nrow(df))) {
    if (df$from_state[i] == "Death") next # absorbing by construction, not estimated
    p <- as.numeric(df[i, cols])
    p <- p / sum(p)
    df[i, cols] <- as.list(rdirichlet_row(p * effective_n))
  }
  df
}

#' Write one complete sampled copy of data/raw/ into `dest`, and return it.
#' Files that are not sampled are copied unchanged, so the draw differs from
#' the base case only in the parameters this function actually varies.
write_psa_draw <- function(dest, raw_dir = "data/raw") {
  if (!dir.exists(dest)) dir.create(dest, recursive = TRUE)
  file.copy(list.files(raw_dir, full.names = TRUE), dest, overwrite = TRUE)

  params <- read_csv_cached(file.path(raw_dir, "aliyev2019_source_parameters.csv"))
  adopted <- read_csv_cached(file.path(raw_dir, "aliyev2019_base_case_costs_utilities.csv"))
  asp <- read_csv_cached(file.path(raw_dir, "cms_asp_infliximab_2026.csv"))
  maint <- read_csv_cached(file.path(raw_dir, "aliyev2019_maintenance_transitions.csv"))

  # --- health-state costs: Aliyev's own Gamma(shape, scale) fits ----------
  is_cost <- grepl("PMPM Mean Total Cost", params$parameter, fixed = TRUE)
  for (i in which(is_cost)) {
    shape <- as.numeric(params$alpha[i])
    scale <- as.numeric(params$beta[i])
    params$base_case_value[i] <- as.character(stats::rgamma(1, shape = shape, scale = scale))
  }
  utils::write.csv(params, file.path(dest, "aliyev2019_source_parameters.csv"), row.names = FALSE)

  # --- Moderate-Severe adopted per-cycle cost (C8 path) -------------------
  # Table 2 has no usable PMPM route to this figure (C8), so its draw is the
  # Table 2 Gamma for Moderate-Severe rescaled to the adopted mean: Aliyev's
  # own relative dispersion applied to the figure his model actually used.
  ms_i <- which(grepl("Moderate-Severe CD-related PMPM Mean Total", params$parameter, fixed = TRUE))[1]
  ms_shape <- as.numeric(params$alpha[ms_i])
  ms_ratio <- stats::rgamma(1, shape = ms_shape, scale = 1) / ms_shape
  ms_rows <- adopted$category == "Direct Cost per Cycle (2017 USD)" &
    adopted$item %in% c("Moderate-Severe", "Moderate-Severe Responder")
  adopted$value[ms_rows] <- as.character(as.numeric(adopted$value[ms_rows]) * ms_ratio)

  # --- utilities: Aliyev's Uniform on Remission, Table 5 ratios preserved --
  u_row <- params[params$parameter == "Remission" & grepl("Utility", params$description), ][1, ]
  remission_draw <- stats::runif(1, as.numeric(u_row$alpha), as.numeric(u_row$beta))
  u_rows <- adopted$category == "Utility (EQ-5D)"
  base_remission <- as.numeric(adopted$value[u_rows & adopted$item == "Remission"])
  adopted$value[u_rows] <- as.character(as.numeric(adopted$value[u_rows]) * (remission_draw / base_remission))
  utils::write.csv(adopted, file.path(dest, "aliyev2019_base_case_costs_utilities.csv"), row.names = FALSE)

  # --- comparator drug price: across the observed biosimilars -------------
  biosimilars <- asp$usd_per_mg[grepl("^Q", asp$hcpcs_code)]
  drawn <- stats::runif(1, min(biosimilars), max(biosimilars))
  asp$usd_per_mg[asp$hcpcs_code == IFX_PRICED_PRODUCT] <- drawn
  utils::write.csv(asp, file.path(dest, "cms_asp_infliximab_2026.csv"), row.names = FALSE)

  # --- transition rows, sampled whole -------------------------------------
  eff_n <- dirichlet_effective_n(raw_dir)
  for (tx in unique(maint$therapy)) {
    idx <- maint$therapy == tx
    maint[idx, ] <- sample_maintenance_transitions(maint[idx, ], eff_n)
  }
  utils::write.csv(maint, file.path(dest, "aliyev2019_maintenance_transitions.csv"), row.names = FALSE)

  dest
}

#' Run `n_draws` probabilistic draws, returning A and B for EVERY
#' combination of the supplied hazards and willingness-to-pay thresholds
#' from each draw.
#'
#' One draw serves all combinations because neither lambda nor h changes the
#' sampled model: lambda is a valuation weight, and h enters only the cured
#' patient's relapse stream. Both can be applied after the expensive part --
#' building the standard-care age grid -- is done. Re-drawing per
#' combination would multiply cost by the size of the grid while adding no
#' sampling whatsoever.
#'
#' `age_step_years` coarsens the standard-care age grid, which the
#' deterministic run resolves at one year; B is smooth in age, and the
#' coarsening is what makes a thousand draws tractable.
run_psa <- function(n_draws, hazards_per_year, lambdas_usd_per_qaly, window_weeks, cap_on,
                     raw_dir = "data/raw", age_step_years = 5, seed = 20260813,
                     scratch = file.path(tempdir(), "psa_draw")) {
  set.seed(seed)
  ages <- seq(MODEL_START_AGE_YEARS, 100, by = age_step_years)
  out <- list()
  for (i in seq_len(n_draws)) {
    write_psa_draw(scratch, raw_dir)
    clear_csv_cache() # the draw just rewrote files this session already parsed
    grid <- standard_care_grid(window_weeks, cap_on, scratch, ages = ages)
    comparator <- run_comparator_trace("IFX", window_weeks, cap_on,
      100 - MODEL_START_AGE_YEARS, scratch)
    for (lambda in lambdas_usd_per_qaly) {
      a <- frontier_intercept_from_model(0, lambda, comparator, grid, window_weeks, cap_on, scratch)
      for (h in hazards_per_year) {
        out[[length(out) + 1]] <- data.frame(
          draw = i, lambda_usd_per_qaly = lambda, h_per_year = h,
          intercept_a_usd_per_course = a,
          value_of_one_cure_b_usd = value_of_one_cure_usd(h, lambda, grid, scratch),
          stringsAsFactors = FALSE
        )
      }
    }
  }
  clear_csv_cache()
  do.call(rbind, out)
}
