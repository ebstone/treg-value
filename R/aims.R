# G6 -- aim coverage. Every aim in SPEC.md section 6 must have either its
# named output file present or a matching entry in SPEC_AMENDMENTS.md
# recording that it was dropped or narrowed.

#' Aims table from SPEC.md section 6, as a data.frame with columns Aim,
#' Statement, `Output file`.
#'
#' SPEC.md writes each output path in markdown backticks. They are stripped
#' here: leaving them in makes every `file.exists()` check fail against a
#' path that does not exist, so an aim whose output had genuinely landed
#' would still be reported uncovered -- the guard would have been incapable
#' of ever passing, which is a worse failure than a noisy one.
#'
#' SPEC.md also writes each aim ID in bold (`**A1**`), and the same argument
#' applies in the other direction. Left in, the identifier compared against
#' SPEC_AMENDMENTS.md is `**A1**`, which cannot match that file's unbolded
#' convention, so the amendment branch of `uncovered_aims()` is unreachable:
#' the guard passes today only because every aim's output happens to exist and
#' short-circuits the check. The first time an aim is legitimately dropped and
#' recorded as an amendment, the guard would fail on it. Both markers are
#' stripped so bolded and unbolded IDs resolve alike.
parse_aims_table <- function(spec_path = "SPEC.md") {
  tbl <- parse_md_table(spec_path, heading = "Aims and their outputs")
  if ("Output file" %in% names(tbl)) {
    tbl[["Output file"]] <- gsub("`", "", trimws(tbl[["Output file"]]))
  }
  if ("Aim" %in% names(tbl)) {
    tbl$Aim <- gsub("\\*", "", trimws(tbl$Aim))
  }
  tbl
}

#' Aim IDs (e.g. "A1") with neither their output file present under
#' `output_root` nor a matching row in `amendments_path`.
uncovered_aims <- function(spec_path = "SPEC.md", amendments_path = "SPEC_AMENDMENTS.md", output_root = ".") {
  aims <- parse_aims_table(spec_path)
  if (nrow(aims) == 0) stop("uncovered_aims(): no aims parsed from ", spec_path)
  amendments_text <- paste(readLines(amendments_path, warn = FALSE), collapse = "\n")

  uncovered <- character(0)
  for (i in seq_len(nrow(aims))) {
    aim_id <- aims$Aim[i]
    out_file <- aims[["Output file"]][i]
    has_output <- file.exists(file.path(output_root, out_file))
    has_amendment <- grepl(aim_id, amendments_text, fixed = TRUE)
    if (!has_output && !has_amendment) uncovered <- c(uncovered, aim_id)
  }
  uncovered
}
