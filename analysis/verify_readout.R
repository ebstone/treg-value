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

# The refractory co-primary population is retired (SPEC_AMENDMENTS.md,
# 2026-08-21) and its section removed from the readout, so its output table
# is no longer checked against readout text here. output/tables/
# refractory_coprimary.csv still regenerates correctly; it is simply no
# longer reported.

cat(if (length(fails) == 0) "ALL READOUT FIGURES MATCH THE STAMPED OUTPUTS\n" else
    paste0(length(fails), " MISMATCH(ES):\n", paste(fails, collapse = "\n"), "\n"))
