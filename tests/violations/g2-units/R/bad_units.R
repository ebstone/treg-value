# Violation fixture for G2 (units): a bare numeric with no permitted
# suffix, and a function conflating two dollar-denominated quantities that
# differ only in their denominator -- the documented defect class (see
# data/raw/tenham2020_case_studies.csv.source.yaml: "a per-course figure was
# previously relabelled as a per-dose retail price"). Neither named as a
# converter, nor declaring its own output unit.

induction_cost <- 450

combine_bad <- function(x_usd_per_dose, y_usd_per_course) x_usd_per_dose + y_usd_per_course
