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
#
# CHEERS 2022 IS A REPORTING STANDARD, NOT A METHODS STANDARD. Its own
# statement says it "is not intended to guide the conduct of economic
# evaluation", and it directs users to record "Not applicable" for items that
# do not apply, explicitly warning against the phrasing "Not conducted"
# because the checklist captures reporting rather than conduct. Items 19, 21
# and 25 are therefore SATISFIED by stating in the manuscript that no
# distributional analysis and no stakeholder engagement were undertaken --
# performing them is not a compliance requirement.
#
# That is a statement about CHEERS, not about the science. The absence of a
# distributional analysis remains a real limitation of the study, and item 26
# is where a reader should be told so. `substantive_limitation` marks the
# items where compliance and completeness come apart.

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
  "19" = "manuscript", "20" = "repository", "21" = "manuscript",
  "22" = "repository", "23" = "repository", "24" = "repository",
  "25" = "manuscript", "26" = "partial",    "27" = "manuscript",
  "28" = "manuscript"
)

evidence <- c(
  "1"  = "Manuscript title.",
  "2"  = "Manuscript abstract.",
  "3"  = "SPEC.md study statement and section 1; readout artifact opening section.",
  "4"  = "SPEC.md is the analysis plan, version-controlled and hash-stamped into every output. Not separately registered or publicly posted.",
  "5"  = "SPEC.md section 2: single population -- comparator transition probabilities are estimated from trial data (UNITI-1, UNITI-2) that pool biologic-naive and biologic-experienced patients rather than a uniform stratum; no refractory-adjusted population is run separately (SPEC_AMENDMENTS.md, 2026-08-21 retirement of the refractory co-primary). Starting age 35 recorded in SPEC_AMENDMENTS.md with its SONIC source.",
  "6"  = "SPEC.md section 2: United States, commercial-payer and healthcare-sector setting; CMS ASP and PFS payment data anchor US unit costs. The US legal and regulatory constraints bearing on A7's payment arrangements are named but not assessed (sourcing register item S-10).",
  "7"  = "SPEC.md section 2; infliximab biosimilar product fixed as OPEN_QUESTIONS.md C10; ustekinumab and adalimumab run as scenario S5.",
  "8"  = "SPEC.md section 2: US healthcare-sector perspective for A1-A5. A6 and A7's budget-impact leg adopt a second, separately labelled perspective -- US commercial payer (L14, SPEC.md section 2a) -- sharing the same unit costs but a different denominator and horizon; the two perspectives are stated to coincide on inputs rather than describing two independently costed models.",
  "9"  = "SPEC.md section 2: lifetime primary, 30- and 40-year secondary; all three produced in output/tables/comparator_ifx_trace.csv. A6/A7's budget-impact leg reports a separate, stated reporting-horizon ladder -- 1/3/5 years (budget-impact base case), 10/30 years (extended offset-accrual projection), and a lifetime reconciliation leg (L10) -- in output/tables/budget_impact.csv and output/tables/payment_arrangements.csv. A7 additionally reports an outcome-observation-point ladder (12 weeks / 2 / 5 years, L19) that is explicitly not the reporting horizon (SPEC.md section 2a).",
  "10" = "SPEC.md section 2: 3% annual, costs and QALYs; R/markov_engine.R. A6/A7's budget-impact leg follows a horizon-class-dependent discounting convention rather than one rate -- undiscounted base case with 3% reported alongside at 1/3/5 years, 3% base case with undiscounted reported alongside at 10/30 years and the lifetime leg, both columns produced at every horizon without exception (L11). A7's installment financing rate is a separate, stated (not swept) contract term, base case set equal to the study's own 3% rate; any other rate is a labelled illustration pending O16.",
  "11" = "QALYs and costs combined as net monetary benefit; SPEC.md section 1.",
  "12" = "Aliyev 2019 transition matrices and NCHS life tables, each with a provenance sidecar under data/raw/.",
  "13" = "EQ-5D utilities from Aliyev Suppl. Table 5, transcribed with sidecar.",
  "14" = "data/raw/ unit costs (CMS ASP, CMS PFS, Aliyev health states) and derive/health_state_costs.R.",
  "15" = "All costs re-based to 2025 USD through medical-care CPI (R/price_index.R); euro figures converted at the source year's rate. Amendment recorded.",
  "16" = "SPEC.md section 3 and the R/ modules; model publicly available at github.com/ebstone/treg-value.",
  "17" = "SPEC_AMENDMENTS.md records every assumption; validation is the eight guards plus acceptance tests T1-T21 in tests/testthat/.",
  "18" = "No subgroup or heterogeneity comparison is reported as a study result. The refractory-adjusted co-primary population was retired as a subgroup contrast (SPEC_AMENDMENTS.md, 2026-08-21): R/refractory.R and output/tables/refractory_coprimary.csv still exist, still pass their own tests, and are accurate as far as they go, but are no longer reported as a co-primary or subgroup finding. The single population's comparator dynamics pool biologic-naive and biologic-experienced patients rather than separating them (SPEC.md section 2).",
  "19" = "No distributional or equity analysis was undertaken; results are not disaggregated by socioeconomic group, race, geography or priority population. CHEERS is satisfied by reporting this as Not applicable, but the absence is a substantive limitation for item 26 to discuss.",
  "20" = "1,000-draw probabilistic analysis (R/psa.R) over A1-A5's health-state costs, utilities, comparator price and transition rows; L5/L6 bounding pairs on every primary output; the scenario grid (SPEC.md section 5). Pi, h and lambda are swept, not sampled, across A1-A7. A7 states rather than sweeps its three normative contract parameters (installment length N, rebate share rho, observation point T -- L17/L19) and deliberately builds no per-patient outcome distribution for the outcomes-based contract (L18), a decision recorded so the absence of a variance or budget-predictability claim is not mistaken for an oversight.",
  "21" = "No patient, public, clinician or payer engagement in study design. Reported as Not applicable. A substantive limitation given the study prices a therapy on behalf of patients who were not consulted.",
  "22" = "data/raw/ with a sidecar per file; PSA distributions are Aliyev's own fitted parameters, documented in R/psa.R.",
  "23" = "output/tables/ aim outputs; readout artifact.",
  "24" = "PSA credible intervals (output/tables/psa_summary.csv); discount rate varied at 0% and 5% in output/tables/scenarios.csv (disc-0/disc-5 rows). No time-horizon scenario exists in scenarios.csv -- L10 states the reporting horizon rather than sweeping it -- so the effect of horizon choice is instead shown directly as the reported ladder in output/tables/budget_impact.csv and output/tables/payment_arrangements.csv (1/3/5/10/30 years), together with the two discounting columns L11 requires at every one of those horizons.",
  "25" = "Not applicable, following item 21 -- there is no engagement whose effect could be reported.",
  "26" = "Limitations are recorded in the readout artifact and in OPEN_QUESTIONS.md, but ethical and equity considerations are not, and generalisability is not discussed. Completing this item needs the manuscript.",
  "27" = "Manuscript funding statement.",
  "28" = "Manuscript conflict-of-interest statement."
)

checklist$status <- unname(status[as.character(checklist$item)])
checklist$evidence <- unname(evidence[as.character(checklist$item)])
# Items where CHEERS compliance and scientific completeness diverge: the
# checklist is satisfied by a statement, but something real is missing.
checklist$substantive_limitation <- checklist$item %in% c(19, 21, 26)
stopifnot(!any(is.na(checklist$status)), !any(is.na(checklist$evidence)))

stamp_output(checklist, "output/tables/cheers_2022_compliance.csv")

cat("\n--- CHEERS 2022 compliance ---\n")
print(table(checklist$status))
cat("\nItems where compliance is satisfiable by a statement but something real is absent:\n")
print(checklist[checklist$substantive_limitation, c("item", "topic", "status")], row.names = FALSE)
