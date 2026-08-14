# Transcription tool: turns an NCHS "United States Life Tables" PDF into the
# CSV form data/raw/nchs_life_table_<year>.csv takes.
#
# This writes into data/raw/, not data/derived/, because its output is a
# transcription of a published table rather than a quantity derived from
# other inputs. It lives here because it is transformation code and there is
# nowhere better; the guard that governs its output is G1 (provenance), via
# each life table's own .source.yaml sidecar.
#
# Usage, from the repository root:
#   Rscript derive/parse_nchs_life_table.R <pdf> <out.csv>
#   Rscript derive/parse_nchs_life_table.R <pdf> <out.csv> <first-line> <last-line>
#
# LINE RANGES ARE NOT HARD-CODED. Table 1 is located by scanning the whole
# `pdftotext -layout` rendering for the first complete age sequence 0-100.
# An earlier version of this file required the caller to pass the line range
# and documented one per report; those offsets are a property of the poppler
# version doing the rendering, not of the PDF, so they silently went stale and
# selected an unrelated table. The optional third and fourth arguments still
# accept an explicit range, for the case where a report's Table 1 is genuinely
# not the first 0-100 block, but nothing depends on them by default.
#
# THE FIRST COMPLETE BLOCK IS TABLE 1. These reports repeat the same 0-100
# layout for each sex/race subpopulation, so several blocks match. Table 1
# (total population) is the first. The block is required to be contiguous and
# to run 0, 1, 2, ... 100 exactly; rows drifting in from an adjacent table
# break that sequence and raise an error rather than being deduplicated away.
#
# TERMINAL ROW. NCHS reports do not agree on how the final row is written:
# the 2023 report says "100 and older", the 2019 report says "100 and over".
# A parser matching only one spelling drops the absorbing row silently and
# yields a 100-row table whose cohort never fully exhausts, which breaks the
# lifetime horizon without breaking any obvious check. Both spellings are
# matched, and the row count is asserted below rather than left to inspection.

options(scipen = 999)
args <- commandArgs(trailingOnly = TRUE)
if (!length(args) %in% c(2L, 4L)) {
  stop("usage: parse_nchs_life_table.R <pdf> <out.csv> [<first-line> <last-line>]", call. = FALSE)
}
pdf <- args[1]
out <- args[2]
explicit_range <- length(args) == 4L
if (!file.exists(pdf)) stop(sprintf("no such pdf: %s", pdf), call. = FALSE)

# An age row opens with either a hyphenated/en-dashed age interval or the
# terminal row's prose. The interval separator is matched literally: the
# previous pattern used an unescaped "." there, which is a wildcard, so
# "100. . . . ." from an unrelated table satisfied it by backtracking.
AGE_PREFIX <- "^\\s*(100 and (older|over)|[0-9]+(–|-)[0-9]+)"

# shQuote, because a downloaded pdf is quite often "nvsr74-06 (1).pdf" and an
# unquoted path splits into multiple shell words.
cmd <- sprintf("pdftotext -layout %s -", shQuote(pdf))
txt <- system(cmd, intern = TRUE)
if (!length(txt)) stop(sprintf("pdftotext produced no output for %s", pdf), call. = FALSE)
if (explicit_range) {
  from <- as.integer(args[3])
  to <- as.integer(args[4])
  if (is.na(from) || is.na(to) || from < 1L || to < from) {
    stop("explicit line range must be two positive integers, first <= last", call. = FALSE)
  }
  txt <- txt[seq(from, min(to, length(txt)))]
}

row_age <- function(l) {
  m <- regmatches(l, regexpr(AGE_PREFIX, l))
  if (!length(m)) return(NA_integer_)
  if (grepl("and (older|over)", m)) 100L else as.integer(sub("^\\s*", "", sub("(–|-).*$", "", m)))
}

# Each row carries six figures after the age label: qx, lx, dx, Lx, Tx, ex.
LIFE_TABLE_COLUMNS <- 6L

parse_row <- function(l) {
  age <- row_age(l)
  rest <- sub("^[^0-9]*", "", sub("^.*?\\.\\s+(?=[0-9])", "", l, perl = TRUE))
  nums <- as.numeric(gsub(",", "", regmatches(rest, gregexpr("[0-9,]+\\.?[0-9]*", rest))[[1]]))
  if (length(nums) < LIFE_TABLE_COLUMNS) {
    stop(sprintf(
      "%s: age row %s parsed to %d numeric fields, expected at least %d.\n  offending line: %s",
      pdf, age, length(nums), LIFE_TABLE_COLUMNS, trimws(l)
    ), call. = FALSE)
  }
  data.frame(age_years = age, qx_prob_1yr = nums[1], lx = nums[2], dx = nums[3],
             Lx = nums[4], Tx = nums[5], ex_years = nums[6])
}

candidates <- txt[grepl(AGE_PREFIX, txt)]
if (!length(candidates)) {
  stop(sprintf("%s: no age rows found; is this an NCHS life-table report?", pdf), call. = FALSE)
}
candidate_ages <- vapply(candidates, row_age, integer(1), USE.NAMES = FALSE)

# Walk to the first row where the age sequence starts, then require the next
# 101 rows to be exactly 0..100. Contamination from a neighbouring table shows
# up as a break in that sequence and is reported, not silently discarded.
starts <- which(candidate_ages == 0L)
if (!length(starts)) stop(sprintf("%s: found age rows but none for age 0", pdf), call. = FALSE)

block <- NULL
for (s in starts) {
  if (s + 100L > length(candidate_ages)) next
  window <- candidate_ages[s:(s + 100L)]
  if (identical(window, 0:100)) {
    block <- candidates[s:(s + 100L)]
    break
  }
}
if (is.null(block)) {
  stop(sprintf(
    "%s: no contiguous age-0-to-100 block found. Age rows were detected, so either the report's layout has changed or a table is split across pages.",
    pdf
  ), call. = FALSE)
}

df <- do.call(rbind, lapply(block, parse_row))

stopifnot(nrow(df) == 101)                          # ages 0-100 inclusive
stopifnot(identical(df$age_years, 0:100))           # contiguous, in order, no gaps
stopifnot(max(df$age_years) == 100)                 # terminal row present
stopifnot(df$qx_prob_1yr[df$age_years == 100] == 1) # and absorbing
stopifnot(!any(is.na(df)))

write.csv(df, out, row.names = FALSE)
cat(sprintf("wrote %s: %d rows, ex at 35 = %.1f\n", out, nrow(df), df$ex_years[df$age_years == 35]))
