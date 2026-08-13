# Verify every headline figure in the readout against the stamped CSVs.
# Numbers were typed into HTML by hand; this checks them mechanically.
setwd("/home/eric/treg-value")
html <- paste(readLines("/tmp/claude-1000/-home-eric/a05865ce-08a3-4f9e-a63c-c47b13d06169/scratchpad/treg_value_readout.html", warn = FALSE), collapse = "\n")

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

rc <- read.csv("output/tables/refractory_coprimary.csv", comment.char = "#")
rc <- rc[rc$induction_window_weeks == 8 & rc$maintenance_cap == "on" & rc$lambda_usd_per_qaly == 1e5 & rc$h_per_year == 0.05, ]
for (i in seq_len(nrow(rc))) check(paste("refractory", rc$population[i]), rc$value_of_one_cure_b_usd[i], usd(rc$value_of_one_cure_b_usd[i]))

cat(if (length(fails) == 0) "ALL READOUT FIGURES MATCH THE STAMPED OUTPUTS\n" else
    paste0(length(fails), " MISMATCH(ES):\n", paste(fails, collapse = "\n"), "\n"))
