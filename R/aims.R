# G6 -- aim coverage. Every aim in SPEC.md section 6 must have either its
# named output file present or a matching entry in SPEC_AMENDMENTS.md
# recording that it was dropped or narrowed.

#' Aims table from SPEC.md section 6, as a data.frame with columns Aim,
#' Statement, `Output file`.
parse_aims_table <- function(spec_path = "SPEC.md") {
  parse_md_table(spec_path, heading = "Aims and their outputs")
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
