source_r("io_cache.R")

test_that("the CHEERS 2022 checklist is complete and matches the standard's own numbering", {
  d <- read.csv(repo_root_relative("data", "raw", "cheers_2022_checklist.csv"), stringsAsFactors = FALSE)
  expect_equal(nrow(d), 28)
  expect_equal(sort(d$item), 1:28)
  expect_true(all(nzchar(d$recommendation)))
  expect_setequal(unique(d$section),
    c("Title", "Abstract", "Introduction", "Methods", "Results", "Discussion", "Other relevant information"))
})

test_that("every checklist item has a compliance status and evidence, with gaps named as gaps", {
  f <- repo_root_relative("output", "tables", "cheers_2022_compliance.csv")
  skip_if(!file.exists(f), "compliance assessment not yet run")
  d <- read.csv(f, comment.char = "#", stringsAsFactors = FALSE)
  expect_equal(nrow(d), 28)
  expect_true(all(nzchar(d$status)))
  expect_true(all(nzchar(d$evidence)))
  expect_true(all(d$status %in% c("repository", "manuscript", "gap", "partial")))
  # A gap must say so in its evidence rather than being quietly reclassified.
  for (i in which(d$status == "gap")) {
    expect_true(grepl("NOT ADDRESSED|NOT DONE|Not applicable", d$evidence[i]),
      label = paste("item", d$item[i]))
  }
})
