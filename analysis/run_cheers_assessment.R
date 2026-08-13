# CHEERS 2022 compliance assessment. SPEC.md section 2 names CHEERS 2022 as
# this study's reporting standard. Run from the repository root.
#
# This repository is the ANALYSIS, not the manuscript. Several CHEERS items
# are properties of a written paper (title, abstract, funding, conflicts)
# and cannot be satisfied by an analysis repository at all. Each item is
# therefore assigned one of:
#
#   repository   satisfied by a versioned artifact here, named in `evidence`
#   manuscript   cannot be satisfied here; belongs to the written paper
#   gap          neither satisfied nor a manuscript matter -- a real hole
#
# A "gap" is a finding, not a formatting note.

source("R/io_cache.R")
source("R/stamp.R")

checklist <- read_csv_cached("data/raw/cheers_2022_checklist.csv")

status <- c(
  "1"  = "manuscript", "2"  = "manuscript", "3"  = "repository",
  "4"  = "repository", "5"  = "repository", "6"  = "repository",
  "7"  = "repository", "8"  = "repository", "9"  = "repository",
  "10" = "repository", "11" = "repository", "12" = "repository",
  "13" = "repository", "14" = "repository", "15" = "repository",
  "16" = "repository", "17" = "repository", "18" = "repository",
  "19" = "gap",        "20" = "repository", "21" = "gap",
  "22" = "repository", "23" = "repository", "24" = "repository",
  "25" = "gap",        "26" = "partial",    "27" = "manuscript",
  "28" = "manuscript"
)

evidence <- c(
  "1"  = "Manuscript title.",
  "2"  = "Manuscript abstract.",
  "3"  = "SPEC.md study statement and section 1; readout artifact opening section.",
  "4"  = "SPEC.md is the analysis plan, version-controlled and hash-stamped into every output. Not separately registered or publicly posted.",
  "5"  = "SPEC.md section 2 (biologic-naive base case, refractory co-primary); starting age 35 recorded in SPEC_AMENDMENTS.md with its SONIC source.",
  "6"  = "SPEC.md section 2: US healthcare sector, United States.",
  "7"  = "SPEC.md section 2; infliximab biosimilar product fixed as OPEN_QUESTIONS.md C10; ustekinumab and adalimumab run as scenario S5.",
  "8"  = "SPEC.md section 2: US healthcare sector perspective.",
  "9"  = "SPEC.md section 2: lifetime primary, 30- and 40-year secondary; all three produced in output/tables/comparator_ifx_trace.csv.",
  "10" = "SPEC.md section 2: 3% annual, costs and QALYs; R/markov_engine.R.",
  "11" = "QALYs and costs combined as net monetary benefit; SPEC.md section 1.",
  "12" = "Aliyev 2019 transition matrices and NCHS life tables, each with a provenance sidecar under data/raw/.",
  "13" = "EQ-5D utilities from Aliyev Suppl. Table 5, transcribed with sidecar.",
  "14" = "data/raw/ unit costs (CMS ASP, CMS PFS, Aliyev health states) and derive/health_state_costs.R.",
  "15" = "All costs re-based to 2025 USD through medical-care CPI (R/price_index.R); euro figures converted at the source year's rate. Amendment recorded.",
  "16" = "SPEC.md section 3 and the R/ modules; model publicly available at github.com/ebstone/treg-value.",
  "17" = "SPEC_AMENDMENTS.md records every assumption; validation is the eight guards plus acceptance tests T1-T12 in tests/testthat/.",
  "18" = "Refractory co-primary population (R/refractory.R, output/tables/refractory_coprimary.csv).",
  "19" = "NOT ADDRESSED. No distributional or equity analysis: results are not disaggregated by socioeconomic group, race, geography or any priority population.",
  "20" = "1,000-draw probabilistic analysis (R/psa.R), L5/L6 bounding pairs on every primary output, and the scenario grid.",
  "21" = "NOT DONE. No patient, public, clinician or payer engagement in study design is recorded anywhere.",
  "22" = "data/raw/ with a sidecar per file; PSA distributions are Aliyev's own fitted parameters, documented in R/psa.R.",
  "23" = "output/tables/ aim outputs; readout artifact.",
  "24" = "PSA credible intervals; time horizon varied (lifetime / 30 / 40 years); discount rate varied at 0% and 5% in output/tables/scenarios.csv.",
  "25" = "Not applicable while item 21 is undone -- there is no engagement whose effect could be reported.",
  "26" = "Limitations are recorded in the readout artifact and in OPEN_QUESTIONS.md, but ethical and equity considerations are not, and generalisability is not discussed. Completing this item needs the manuscript.",
  "27" = "Manuscript funding statement.",
  "28" = "Manuscript conflict-of-interest statement."
)

checklist$status <- unname(status[as.character(checklist$item)])
checklist$evidence <- unname(evidence[as.character(checklist$item)])
stopifnot(!any(is.na(checklist$status)), !any(is.na(checklist$evidence)))

stamp_output(checklist, "output/tables/cheers_2022_compliance.csv")

cat("\n--- CHEERS 2022 compliance ---\n")
print(table(checklist$status))
cat("\nItems needing attention beyond writing up:\n")
gaps <- checklist[checklist$status %in% c("gap", "partial"), c("item", "topic", "status")]
print(gaps, row.names = FALSE)
