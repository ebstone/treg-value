# Probabilistic analysis and per-patient EVPI (SPEC.md aims A5 and, in
# part, A4). Run from the repository root.
#
# Conditional on a stated (pi, h, lambda): SPEC.md section 5 places no prior
# on those three and this session does not invent one. See R/psa.R for what
# is sampled and from which of Aliyev's own fitted distributions.

source("R/io_cache.R")
source("R/price_index.R")
source("R/denominator.R")
source("derive/health_state_costs.R")
source("R/transition_matrices.R")
source("R/life_table.R")
source("R/dosing.R")
source("R/costs_utilities.R")
source("R/refractory.R")
source("R/markov_engine.R")
source("R/treg_arm.R")
source("R/frontier.R")
source("R/psa.R")
source("R/stamp.R")

N_DRAWS <- 1000
WINDOW_WEEKS <- 8
CAP_ON <- TRUE
HAZARDS_PER_YEAR <- c(0, 0.05, 0.10)
LAMBDAS_USD_PER_QALY <- c(5e4, 1e5, 1.5e5)
ILLUSTRATIVE_PRICE_USD <- 2e4
ILLUSTRATIVE_PI <- 0.25

all_draws <- run_psa(N_DRAWS, HAZARDS_PER_YEAR, LAMBDAS_USD_PER_QALY, WINDOW_WEEKS, CAP_ON)

summary_rows <- list()
evpi_rows <- list()

for (lambda in LAMBDAS_USD_PER_QALY) {
  for (h in HAZARDS_PER_YEAR) {
    draws <- all_draws[all_draws$lambda_usd_per_qaly == lambda & all_draws$h_per_year == h, ]
    a <- draws$intercept_a_usd_per_course
    b <- draws$value_of_one_cure_b_usd

    q <- function(x) stats::quantile(x, c(0.025, 0.5, 0.975), names = FALSE)
    summary_rows[[length(summary_rows) + 1]] <- data.frame(
      lambda_usd_per_qaly = lambda, h_per_year = h, n_draws = N_DRAWS,
      a_mean = mean(a), a_lo = q(a)[1], a_median = q(a)[2], a_hi = q(a)[3],
      b_mean = mean(b), b_lo = q(b)[1], b_median = q(b)[2], b_hi = q(b)[3],
      stringsAsFactors = FALSE
    )

    # Per-patient EVPI at an illustrative price and cure fraction. The
    # decision is adopt-or-not: net benefit of adopting is A + pi*B - price,
    # against zero for staying on the comparator. EVPI is the expected value
    # of removing the sourced-parameter uncertainty before deciding.
    delta <- a + ILLUSTRATIVE_PI * b - ILLUSTRATIVE_PRICE_USD
    evpi <- mean(pmax(delta, 0)) - max(mean(delta), 0)
    evpi_rows[[length(evpi_rows) + 1]] <- data.frame(
      lambda_usd_per_qaly = lambda, h_per_year = h,
      pi_cure = ILLUSTRATIVE_PI, price_usd_per_course = ILLUSTRATIVE_PRICE_USD,
      expected_net_benefit_usd = mean(delta),
      prob_treg_favoured = mean(delta > 0),
      evpi_per_patient_usd = evpi,
      stringsAsFactors = FALSE
    )
    cat(sprintf("lambda %s h %.2f: A %.0f [%.0f, %.0f]  B %.0f [%.0f, %.0f]  EVPI %.0f\n",
      format(lambda, big.mark = ","), h, mean(a), q(a)[1], q(a)[3],
      mean(b), q(b)[1], q(b)[3], evpi))
  }
}

psa_summary <- do.call(rbind, summary_rows)
evpi <- do.call(rbind, evpi_rows)

stamp_output(psa_summary, "output/tables/psa_summary_w6.csv")
stamp_output(evpi, "output/tables/evpi_per_patient_w6.csv")
cat("\nWrote output/tables/psa_summary_w6.csv and evpi_per_patient_w6.csv\n")
