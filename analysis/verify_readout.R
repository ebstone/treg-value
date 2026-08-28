# Verify every headline figure in the readout against the stamped CSVs.
# Numbers were typed into HTML by hand; this checks them mechanically.
#
# Run from the repository root.
#
# READS THE COMMITTED READOUT, BY RELATIVE PATH. Earlier versions of this
# file pointed at a scratchpad copy under /tmp and setwd() to one absolute
# checkout. Both are invisible failures rather than loud ones: the script
# then verifies whichever pair of files those two paths happen to name,
# which after a re-derivation is neither the readout being shipped nor the
# outputs it should be checked against, and it still prints ALL FIGURES
# MATCH. The readout went stale behind exactly that.
READOUT <- "docs/results_readout.html"
stopifnot(file.exists(READOUT), file.exists("output/tables/price_frontier.csv"))
html <- paste(readLines(READOUT, warn = FALSE), collapse = "\n")

fails <- character(0)
check <- function(label, expected, present_as) {
  found <- grepl(present_as, html, fixed = TRUE)
  if (!found) fails <<- c(fails, sprintf("%s: expected '%s' (from %.4f) NOT FOUND in readout", label, present_as, expected))
}
usd <- function(x) paste0("$", formatC(round(x), big.mark = ",", format = "d"))
neg <- function(x) paste0("−$", formatC(abs(round(x)), big.mark = ",", format = "d"))

v <- read.csv("output/tables/value_of_one_cure.csv", comment.char = "#")
v <- v[v$induction_window_weeks == 8 & v$maintenance_cap == "on", ]
for (l in c(5e4, 1e5, 1.5e5)) {
  a <- unique(v$intercept_a_usd_per_course[v$lambda_usd_per_qaly == l])
  check(paste("A", l), a, neg(a))
  for (h in c(0, 0.05, 0.10)) {
    b <- v$value_of_one_cure_b_usd[v$lambda_usd_per_qaly == l & v$h_per_year == h]
    check(paste("B", l, h), b, usd(b))
  }
}

f <- read.csv("output/tables/price_frontier.csv", comment.char = "#")
f <- f[f$induction_window_weeks == 8 & f$maintenance_cap == "on" & f$h_per_year == 0.05, ]
for (l in c(5e4, 1e5, 1.5e5)) for (p in c(0.25, 0.5, 0.75, 1)) {
  x <- f$price_star_usd_per_course[f$lambda_usd_per_qaly == l & abs(f$pi_cure - p) < 1e-9]
  check(paste("P*", l, p), x, usd(x))
}

bm <- read.csv("output/tables/manufacturing_benchmark.csv", comment.char = "#")
for (i in seq_len(nrow(bm))) check(paste("benchmark", bm$anchor[i]), bm$cost_usd_per_course[i], usd(bm$cost_usd_per_course[i]))

r <- read.csv("output/tables/required_cure_fraction.csv", comment.char = "#")
for (i in seq_len(nrow(r))) {
  if (!r$lambda_usd_per_qaly[i] %in% c(1e5, 1.5e5)) next
  pct <- sprintf("%.1f", 100 * r$required_cure_fraction_all_treated[i])
  if (!grepl(pct, html, fixed = TRUE)) {
    fails <- c(fails, sprintf("required %s lam %s h %s: %s%% NOT FOUND",
      r$benchmark_anchor[i], r$lambda_usd_per_qaly[i], r$h_per_year[i], pct))
  }
}

p <- read.csv("output/tables/psa_summary.csv", comment.char = "#")
for (i in seq_len(nrow(p))) {
  check(paste("PSA B mean", p$lambda_usd_per_qaly[i], p$h_per_year[i]), p$b_mean[i], usd(p$b_mean[i]))
  for (q in c(p$b_lo[i], p$b_hi[i])) {
    s <- formatC(round(q), big.mark = ",", format = "d")
    if (!grepl(s, html, fixed = TRUE)) fails <- c(fails, sprintf("PSA CI bound %s NOT FOUND", s))
  }
}

e <- read.csv("output/tables/evpi_per_patient_w6.csv", comment.char = "#")
for (i in seq_len(nrow(e))) {
  check(paste("EVPI", e$lambda_usd_per_qaly[i], e$h_per_year[i]), e$evpi_per_patient_usd[i], usd(e$evpi_per_patient_usd[i]))
}

sc <- read.csv("output/tables/scenarios.csv", comment.char = "#")
sc <- sc[sc$lambda_usd_per_qaly == 1e5 & sc$h_per_year == 0.05, ]
for (i in seq_len(nrow(sc))) {
  check(paste("scenario B", sc$scenario[i]), sc$value_of_one_cure_b_usd[i], usd(sc$value_of_one_cure_b_usd[i]))
  pct <- sprintf("%.1f", 100 * sc$required_cure_fraction_at_median_benchmark[i])
  if (!grepl(pct, html, fixed = TRUE)) fails <- c(fails, sprintf("scenario %s required %s%% NOT FOUND", sc$scenario[i], pct))
}

# --- A6, the budget impact section (W8) ----------------------------------
#
# SCOPED, unlike everything above it, and the scoping is the point. `check()`
# is a `grepl(..., fixed = TRUE)` over the WHOLE document. That is adequate for
# a handful of large, distinctive dollar figures; it is a false pass waiting to
# happen for this section, which carries thirty two-digit percentages and a
# grid of small per-year amounts. A "25.9" occurring anywhere in fourteen
# hundred lines of HTML would satisfy a whole-document match, and this file's
# own header records that a confident ALL FIGURES MATCH is exactly how the
# readout went stale before. The checks below are matched only against the
# substring between this section's own <h2> and the next </section>.
#
# It remains a spot check and not structural protection: it verifies that a
# formatted string appears somewhere in the section, not that it appears in the
# right cell.
section_html <- function(heading) {
  start <- regexpr(heading, html, fixed = TRUE)
  stopifnot(start > 0)
  rest <- substring(html, start)
  end <- regexpr("</section>", rest, fixed = TRUE)
  stopifnot(end > 0)
  substring(rest, 1, end - 1)
}
bia_html <- section_html("<h2>Budget impact")
check_in <- function(label, present_as) {
  if (!grepl(present_as, bia_html, fixed = TRUE)) {
    fails <<- c(fails, sprintf("BIA %s: expected '%s' NOT FOUND in the budget impact section", label, present_as))
  }
}
pct <- function(x) sprintf("%.1f", 100 * x)
usd_millions <- function(x) paste0("$", formatC(x / 1e6, format = "f", digits = 1, big.mark = ","), "M")
usd_cents <- function(x) sprintf("$%.2f", x)

bia <- read.csv("output/tables/budget_impact.csv", comment.char = "#", stringsAsFactors = FALSE)
final_year <- bia$year == bia$reporting_horizon_years

# The offset-capture progression, at pi = 0.50, both cap settings.
prog <- bia[bia$discounted & bia$pi_cure == 0.5 & final_year &
  bia$price_source == "frontier_P_star" & bia$terminal_uptake_share == 0.25 &
  bia$assumed_eligible_population_patients == 1e5, ]
for (hz in c("1yr", "3yr", "5yr", "10yr", "30yr")) {
  for (hh in c(0, 0.05, 0.10)) {
    at <- prog[prog$reporting_horizon == hz & prog$h_per_year == hh, ]
    on <- at$offset_captured_share[at$maintenance_cap == "on"]
    off <- at$offset_captured_share[at$maintenance_cap == "off"]
    check_in(sprintf("offset captured %s h=%s", hz, hh), sprintf("%s / %s%%", pct(on), pct(off)))
  }
}

# The 3-year base-case grid, undiscounted, cap on, h = 5%, 100,000 eligible.
base <- bia[!bia$discounted & bia$reporting_horizon == "3yr" & final_year &
  bia$maintenance_cap == "on" & bia$h_per_year == 0.05 &
  bia$assumed_eligible_population_patients == 1e5, ]
for (p in c(0.25, 0.5, 0.75, 1)) {
  at <- base[base$pi_cure == p & base$price_source == "frontier_P_star", ]
  check_in(sprintf("price pi=%s", p), usd(unique(at$price_usd_per_course)))
  for (u in c(0.25, 1)) {
    check_in(sprintf("3yr cumulative pi=%s u=%s", p, u),
      usd_millions(at$cumulative_net_budget_impact_usd[at$terminal_uptake_share == u]))
  }
  check_in(sprintf("3yr pmpm pi=%s", p),
    usd_cents(at$net_budget_impact_usd_pmpm[at$terminal_uptake_share == 0.25]))
}
analog <- base[base$price_source == "observed_analog_list_price" & base$pi_cure == 0.5, ]
check_in("analog price", usd(unique(analog$price_usd_per_course)))
for (u in c(0.25, 1)) {
  check_in(sprintf("analog 3yr cumulative u=%s", u),
    usd_millions(analog$cumulative_net_budget_impact_usd[analog$terminal_uptake_share == u]))
}
check_in("analog 3yr pmpm", usd_cents(analog$net_budget_impact_usd_pmpm[analog$terminal_uptake_share == 0.25]))
check_in("analog required cure fraction", paste0(pct(unique(analog$required_cure_fraction_all_treated)), "%"))

# The horizon path at the central cell, each leg on its own base-case
# discounting convention (L11), plus the 3-year discounted figure the text
# names to show that discounting has no fixed sign on the net series.
path <- bia[final_year & bia$maintenance_cap == "on" & bia$h_per_year == 0.05 &
  bia$pi_cure == 0.5 & bia$price_source == "frontier_P_star" &
  bia$terminal_uptake_share == 0.25 & bia$assumed_eligible_population_patients == 1e5, ]
for (hz in c("1yr", "3yr", "5yr")) {
  check_in(paste("path", hz), usd_millions(path$cumulative_net_budget_impact_usd[path$reporting_horizon == hz & !path$discounted]))
}
for (hz in c("10yr", "30yr")) {
  check_in(paste("path", hz), usd_millions(path$cumulative_net_budget_impact_usd[path$reporting_horizon == hz & path$discounted]))
}
check_in("3yr discounted", usd_millions(path$cumulative_net_budget_impact_usd[path$reporting_horizon == "3yr" & path$discounted]))

# The plan-scale pool, where the PMPM column reads as a payer would read it.
small <- bia[!bia$discounted & bia$reporting_horizon == "3yr" & final_year &
  bia$maintenance_cap == "on" & bia$h_per_year == 0.05 & bia$pi_cure == 0.5 &
  bia$price_source == "frontier_P_star" & bia$terminal_uptake_share == 0.25 &
  bia$assumed_eligible_population_patients == 1e3, ]
check_in("plan-scale cumulative", usd_millions(small$cumulative_net_budget_impact_usd))
check_in("plan-scale pmpm", usd_cents(small$net_budget_impact_usd_pmpm))

# --- S8, the uptake-shape bounding pair (inside the same BIA section) -----
#
# Scoped to `bia_html` like everything above it. Two kinds of check, and the
# second is the one that matters: the fifteen dollar figures and the five
# percentages are string spot checks in the usual way, but S8's HEADLINE is a
# claim that three numbers are equal, and a string match cannot express that.
# The invariance is therefore recomputed here from the committed table and
# asserted directly, so a change that made the progression shape-dependent
# would fail this script even if every printed figure were updated to match.
s8 <- read.csv("output/tables/budget_impact_s8.csv", comment.char = "#", stringsAsFactors = FALSE)
s8_base <- s8[s8$maintenance_cap == "on" & s8$h_per_year == 0.05 & s8$pi_cure == 0.5 &
  s8$price_source == "frontier_P_star" & s8$terminal_uptake_share == 0.25 &
  s8$assumed_eligible_population_patients == 1e5, ]
s8_cell <- function(shape, hz, column) {
  r <- s8_base[s8_base$uptake_shape == shape & s8_base$reporting_horizon == hz &
    s8_base$discounting_base_case, ]
  r[[column]]
}
S8_SHAPES <- c("logistic", "linear_ramp", "immediate_full_uptake")
for (hz in c("1yr", "3yr", "5yr", "10yr", "30yr")) {
  for (shape in S8_SHAPES) {
    check_in(sprintf("S8 %s %s", shape, hz),
      usd_millions(s8_cell(shape, hz, "cumulative_net_budget_impact_usd")))
  }
  # The offset-capture column, printed once per row because all three shapes
  # carry the same value. Read off the discounted leg, where the share is
  # defined; the undiscounted rows carry NA by the same convention
  # budget_impact.csv uses.
  share <- unique(s8_base$offset_captured_share[s8_base$reporting_horizon == hz &
    s8_base$discounted])
  check_in(sprintf("S8 offset captured %s", hz), paste0(pct(share), "%"))
}
# The two ratios and the two patient counts the S8 prose names.
s8_ratio <- function(shape, hz) {
  100 * (s8_cell(shape, hz, "cumulative_net_budget_impact_usd") /
    s8_cell("linear_ramp", hz, "cumulative_net_budget_impact_usd") - 1)
}
for (shape in c("logistic", "immediate_full_uptake")) {
  check_in(sprintf("S8 3yr ratio %s", shape), paste0(sprintf("%.1f", s8_ratio(shape, "3yr")), "%"))
}
for (shape in c("logistic", "immediate_full_uptake")) {
  check_in(sprintf("S8 year-1 treated %s", shape),
    formatC(round(s8_cell(shape, "1yr", "patients_newly_treated_first_year_patients")),
      big.mark = ",", format = "d"))
}
# The steepness, and the 10%-to-90% rise it implies -- recomputed from the
# committed column rather than transcribed, so the readout's "1.0 per year"
# and "4.4 years" cannot drift apart from the value the run actually used.
s8_k <- unique(s8$uptake_logistic_steepness_per_year[s8$uptake_shape == "logistic"])
if (length(s8_k) != 1) {
  fails <- c(fails, "S8: more than one logistic steepness in budget_impact_s8.csv")
} else {
  check_in("S8 steepness", sprintf("%.1f per year", s8_k))
  check_in("S8 10-90 rise", sprintf("%.1f years", 2 * log(9) / s8_k))
}
# S8's headline, asserted rather than matched: the offset-capture progression
# is identical across the three shapes in every scenario group, and the count
# of groups where it is defined is the number the readout prints.
s8_spread <- vapply(split(s8$offset_captured_share, s8$scenario_group_id), function(x) {
  if (all(is.na(x))) NA_real_ else max(x, na.rm = TRUE) - min(x, na.rm = TRUE)
}, numeric(1))
s8_defined <- sum(!is.na(s8_spread))
if (!identical(max(s8_spread, na.rm = TRUE), 0)) {
  fails <- c(fails, sprintf("S8 headline: offset-capture spread across shapes is %g, not 0",
    max(s8_spread, na.rm = TRUE)))
}
check_in("S8 defined scenario cells", formatC(s8_defined, big.mark = ",", format = "d"))

# The refractory co-primary population is retired (SPEC_AMENDMENTS.md,
# 2026-08-21) and its section removed from the readout, so its output table
# is no longer checked against readout text here. output/tables/
# refractory_coprimary.csv still regenerates correctly; it is simply no
# longer reported.

# --- A7, the alternative payment arrangements section (W10) --------------
#
# Scoped exactly as the BIA section is above, against its own <h2>..</section>
# substring, for the same reason: this section carries dozens of small
# percentages and dollar figures, and a whole-document grepl would pass on a
# coincidental match elsewhere rather than on the right cell.
pa_html <- section_html("<h2>Alternative payment arrangements")
check_pa <- function(label, present_as) {
  if (!grepl(present_as, pa_html, fixed = TRUE)) {
    fails <<- c(fails, sprintf("A7 %s: expected '%s' NOT FOUND in the payment arrangements section", label, present_as))
  }
}

pa <- read.csv("output/tables/payment_arrangements.csv", comment.char = "#", stringsAsFactors = FALSE)
recon <- read.csv("output/tables/payment_arrangements_reconciliation.csv", comment.char = "#", stringsAsFactors = FALSE)

# The offset-matched schedule's year-30 distribution, across all 240
# discounted 30-year scenario groups (R8's corrected range, not the best cell).
om30 <- pa[pa$arrangement == "offset_matched" & pa$discounted & pa$reporting_horizon == "30yr" &
  !is.na(pa$offset_captured_share), ]
stopifnot(length(unique(om30$scenario_id)) == 240)
om_min <- min(om30$offset_captured_share)
om_med <- median(om30$offset_captured_share)
om_max <- max(om30$offset_captured_share)
pct2 <- function(x) sprintf("%.2f", 100 * x)
check_pa("offset-matched min share", paste0(pct2(om_min), "%"))
check_pa("offset-matched median share", paste0(pct2(om_med), "%"))
check_pa("offset-matched max share", paste0(pct2(om_max), "%"))
check_pa("offset-matched min outstanding", paste0(pct2(1 - om_min), "%"))
check_pa("offset-matched median outstanding", paste0(pct2(1 - om_med), "%"))
check_pa("offset-matched max outstanding", paste0(pct2(1 - om_max), "%"))
# Non-decreasing on the reported grid, checked rather than assumed (T20's own
# qualification): every reporting-horizon-to-reporting-horizon increment of
# offset_captured_share, within a scenario group on the discounted leg, is
# non-negative.
om_all <- pa[pa$arrangement == "offset_matched" & pa$discounted & !is.na(pa$offset_captured_share), ]
horizon_order <- c("1yr", "3yr", "5yr", "10yr", "30yr")
om_all$reporting_horizon <- factor(om_all$reporting_horizon, levels = horizon_order, ordered = TRUE)
any_decrease <- FALSE
for (grp in split(om_all$offset_captured_share, om_all$scenario_id)) {
  if (length(grp) > 1 && any(diff(grp) < -1e-9)) any_decrease <- TRUE
}
if (any_decrease) fails <- c(fails, "A7 offset-matched schedule: a decrease was found across the reported horizon grid")

# The installment table -- price leg as a share of the lump sum, population
# level, at the base-case cell.
inst_cell <- function(arr, hz, disc) {
  x <- pa[pa$arrangement == arr & pa$maintenance_cap == "on" & pa$induction_window_weeks == 8 &
    pa$lambda_usd_per_qaly == 1e5 & pa$h_per_year == 0.05 & pa$pi_cure == 0.5 &
    pa$price_source == "frontier_P_star" & pa$terminal_uptake_share == 0.25 &
    pa$assumed_eligible_population_patients == 1e5 & pa$reporting_horizon == hz & pa$discounted == disc, ]
  x$price_leg_share_of_lump_sum
}
pct1 <- function(x) sprintf("%.1f", 100 * x)
for (hz in c("1yr", "3yr", "5yr", "10yr", "30yr")) {
  check_pa(sprintf("N=5 undiscounted %s", hz), paste0(pct1(inst_cell("installment_pv_neutral_5yr", hz, FALSE)), "%"))
  check_pa(sprintf("N=5 discounted %s", hz), paste0(pct1(inst_cell("installment_pv_neutral_5yr", hz, TRUE)), "%"))
  check_pa(sprintf("N=3 undiscounted %s", hz), paste0(pct1(inst_cell("installment_pv_neutral_3yr", hz, FALSE)), "%"))
  check_pa(sprintf("N=3 discounted %s", hz), paste0(pct1(inst_cell("installment_pv_neutral_3yr", hz, TRUE)), "%"))
}
# The interest-free schedule's equivalent per-course present-value discount,
# once every cohort's schedule is inside the window (10/30-year rows).
free_disc <- inst_cell("installment_interest_free_5yr", "10yr", TRUE)
free_disc_pct <- 100 * (free_disc - 1)
check_pa("interest-free equivalent discount", paste0("−", sprintf("%.3f", abs(free_disc_pct)), "%"))

# The single-cohort fixture (N=5, undiscounted): ratio = min(N, H) / a_c,
# recomputed from the schedule's own committed rate and length -- not
# transcribed -- exactly as T19(b)'s own formula does.
one_row <- pa[pa$arrangement == "installment_pv_neutral_5yr" & pa$maintenance_cap == "on" &
  pa$induction_window_weeks == 8 & pa$lambda_usd_per_qaly == 1e5 & pa$h_per_year == 0.05 &
  pa$pi_cure == 0.5 & pa$price_source == "frontier_P_star", ][1, ]
r_c <- one_row$installment_financing_rate_per_year
N <- one_row$installment_length_years
a_c <- sum((1 + r_c)^(-(0:(N - 1))))
single_cohort_ratio <- function(h) min(N, h) / a_c
for (hz in c(1, 3, 5)) check_pa(sprintf("single-cohort N=5 undiscounted H=%d", hz), paste0(pct1(single_cohort_ratio(hz)), "%"))

# The outcomes-based table -- effective price as a share of the lump sum,
# once every cohort's rebate has settled (10/30-year full-inclusion rows).
outc_cell <- function(arr, disc) {
  x <- pa[pa$arrangement == arr & pa$maintenance_cap == "on" & pa$induction_window_weeks == 8 &
    pa$lambda_usd_per_qaly == 1e5 & pa$h_per_year == 0.05 & pa$pi_cure == 0.5 &
    pa$price_source == "frontier_P_star" & pa$terminal_uptake_share == 0.25 &
    pa$assumed_eligible_population_patients == 1e5 & pa$reporting_horizon == "10yr" & pa$discounted == disc, ]
  x$price_leg_share_of_lump_sum
}
for (arr in c("outcomes_based_rho100_T0yr", "outcomes_based_rho100_T2yr", "outcomes_based_rho100_T5yr", "outcomes_based_rho050_T2yr")) {
  check_pa(paste(arr, "undiscounted"), paste0(pct1(outc_cell(arr, FALSE)), "%"))
  check_pa(paste(arr, "discounted"), paste0(pct1(outc_cell(arr, TRUE)), "%"))
}
# The settlement convention: tau = T + 12/52, discount factor v^tau at 3%.
disc_rate <- unique(pa$analysis_discount_rate_per_year[!is.na(pa$analysis_discount_rate_per_year)])[1]
v_tau <- function(T) (1 + disc_rate)^(-(T + 12 / 52))
for (T in c(0, 2, 5)) check_pa(sprintf("v^tau T=%s", T), sprintf("%.4f", v_tau(T)))

# P*_cure -- the per-cure frontier surface, at ppo = 1 (ratio's own rho = 1
# leg), against the committed per_cure_frontier rows.
pcf <- pa[pa$result_family == "per_cure_frontier" & pa$rebate_share == 1 & pa$maintenance_cap == "on" &
  pa$induction_window_weeks == 8 & pa$price_source == "frontier_P_star", ]
pcf_at <- function(pi_val, h, T, lam = 1e5) {
  x <- pcf[abs(pcf$pi_cure - pi_val) < 1e-9 & pcf$h_per_year == h & pcf$outcome_observation_years == T & pcf$lambda_usd_per_qaly == lam, ]
  x$justified_price_usd_per_cure
}
for (pi_val in c(0.25, 0.5, 1.00)) for (h in c(0, 0.05, 0.10)) {
  check_pa(sprintf("P*_cure pi=%s h=%s T=2", pi_val, h), usd(pcf_at(pi_val, h, 2)))
}
check_pa("P*_cure pi=0.25 h=0 T=0", usd(pcf_at(0.25, 0, 0)))
check_pa("P*_cure pi=0.25 h=0 T=5", usd(pcf_at(0.25, 0, 5)))
check_pa("P*_cure pi=1 h=0.10 T=0", usd(pcf_at(1, 0.10, 0)))
check_pa("P*_cure pi=1 h=0.10 T=5", usd(pcf_at(1, 0.10, 5)))
# The sign threshold pi = -A/B, and the pi = 0 excursion, at lambda = $100k.
for (h in c(0, 0.05, 0.10)) {
  thr <- unique(pcf$positive_price_threshold_pi_cure[pcf$h_per_year == h & pcf$lambda_usd_per_qaly == 1e5])
  check_pa(sprintf("threshold h=%s", h), sprintf("%.2f%%", 100 * thr))
}
check_pa("P*_cure pi=0 excursion", neg(abs(pcf_at(0, 0, 0))))
check_pa("P*_cure pi=0.01 excursion", usd(pcf_at(0.01, 0, 0)))
check_pa("P*_cure pi=0.02 excursion", usd(pcf_at(0.02, 0, 0)))

cat(if (length(fails) == 0) "ALL READOUT FIGURES MATCH THE STAMPED OUTPUTS\n" else
    paste0(length(fails), " MISMATCH(ES):\n", paste(fails, collapse = "\n"), "\n"))
