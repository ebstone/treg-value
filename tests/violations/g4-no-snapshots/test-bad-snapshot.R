# Violation fixture for G4 (no snapshots): asserts a bare value-snapshot
# literal with 4+ significant figures instead of a property.

test_that("smuggled snapshot value", {
  expect_equal(compute_price(), 19345.67)
})
