# Renders the PSA draw-cloud scatter (A vs B, central case) as inline SVG
# for docs/results_readout.html. Prints markup to stdout; the readout is a
# hand-edited static file with no templating step, so this script's output
# is pasted in once rather than included at render time -- the same
# convention the P*(pi) line chart already follows, just too many points
# (1,000) to place by hand.
#
# Run from the repository root, after analysis/run_psa.R.

d <- read.csv("output/tables/psa_draws.csv", comment.char = "#")
d <- d[d$h_per_year == 0.05 & d$lambda_usd_per_qaly == 1e5, ]
stopifnot(nrow(d) > 0)

a <- d$intercept_a_usd_per_course
b <- d$value_of_one_cure_b_usd

# Plot area matches the P*(pi) chart's geometry (viewBox 0 0 660 372) so the
# two figures read as one visual system.
X0 <- 60; X1 <- 560; Y0 <- 40; Y1 <- 330

# Round the data range out to a human axis step, so gridlines land on clean
# numbers rather than the draws' exact min/max.
nice_range <- function(x, step) {
  lo <- floor(min(x) / step) * step
  hi <- ceiling(max(x) / step) * step
  c(lo, hi)
}
a_rng <- nice_range(a, 500)      # A in hundreds of dollars
b_rng <- nice_range(b, 25000)    # B in tens of thousands of dollars

sx <- function(bv) X0 + (bv - b_rng[1]) / diff(b_rng) * (X1 - X0)
sy <- function(av) Y1 - (av - a_rng[1]) / diff(a_rng) * (Y1 - Y0)  # A axis inverted (SVG y grows down)

fmt_usd <- function(x) paste0(ifelse(x < 0, "−$", "$"), formatC(abs(round(x)), big.mark = ",", format = "d"))

cat(sprintf('<svg viewBox="0 0 660 372" role="img" aria-label="Scatter plot: %d PSA draws of A against B at h = 5%% per year, lambda $100,000 per QALY, showing the joint uncertainty behind the credible-interval table above.">\n', nrow(d)))

# Horizontal gridlines (A axis)
a_ticks <- seq(a_rng[1], a_rng[2], length.out = 5)
for (t in a_ticks) {
  cls <- if (abs(t) < 1e-9) "zero-line" else "grid-line"
  cat(sprintf('        <line class="%s" x1="%s" y1="%.1f" x2="%s" y2="%.1f"></line>\n', cls, X0, sy(t), X1, sy(t)))
  cat(sprintf('        <text class="axis-text" x="%d" y="%.1f" text-anchor="end">%s</text>\n', X0 - 8, sy(t) + 3.5, fmt_usd(t)))
}

# Vertical gridlines (B axis)
b_ticks <- seq(b_rng[1], b_rng[2], length.out = 5)
cat(sprintf('        <line class="grid-line" x1="%s" y1="%s" x2="%s" y2="%s"></line>\n', X0, Y1, X1, Y1))
for (t in b_ticks) {
  cat(sprintf('        <text class="axis-text" x="%.1f" y="%d" text-anchor="middle">%s</text>\n', sx(t), Y1 + 18, fmt_usd(t)))
}
cat(sprintf('        <text class="axis-text" x="%.1f" y="%d" text-anchor="middle">B — VALUE OF ONE DURABLE CURE, PER DRAW</text>\n', (X0 + X1) / 2, Y1 + 36))
cat(sprintf('        <text class="axis-text" x="%d" y="%d" text-anchor="middle" transform="rotate(-90 %d %d)">A — VALUE AT %s CURE FRACTION, PER DRAW</text>\n',
  X0 - 42, (Y0 + Y1) / 2, X0 - 42, (Y0 + Y1) / 2, "ZERO"))

cat('        <g class="scatter-dot">\n')
for (i in seq_len(nrow(d))) {
  cat(sprintf('          <circle cx="%.1f" cy="%.1f" r="2.1"></circle>\n', sx(b[i]), sy(a[i])))
}
cat('        </g>\n')
cat('      </svg>\n')

cat(sprintf('\nn = %d draws | A: mean %s, range [%s, %s] | B: mean %s, range [%s, %s]\n',
  nrow(d), fmt_usd(mean(a)), fmt_usd(min(a)), fmt_usd(max(a)),
  fmt_usd(mean(b)), fmt_usd(min(b)), fmt_usd(max(b))))
