# Violation fixture for G2 (units): a bare numeric with no permitted
# suffix, and a function combining two differently-suffixed arguments
# without naming itself as a converter.

induction_cost <- 450

combine_bad <- function(x_usd_per_dose, y_qaly) x_usd_per_dose * y_qaly
