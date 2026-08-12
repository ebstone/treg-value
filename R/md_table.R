# Shared infrastructure for guards that read a governing document's tables
# mechanically (G6 reads SPEC.md section 6; G7 reads OPEN_QUESTIONS.md)
# instead of matching against free-text prose.

#' Parse a pipe-delimited markdown table into a data.frame. `heading`
#' selects the table in the section that starts at the first markdown
#' heading line whose text contains it (case-insensitive) and ends at the
#' next heading line; NULL takes the first table in the file.
parse_md_table <- function(path, heading = NULL) {
  lines <- readLines(path, warn = FALSE)
  start <- 1L
  if (!is.null(heading)) {
    hit <- grep(paste0("^#+.*", heading), lines, ignore.case = TRUE)
    if (length(hit) == 0) stop("parse_md_table(): heading not found: ", heading)
    start <- hit[1]
  }
  rest <- lines[(start + 1):length(lines)]
  next_heading <- grep("^#", rest)
  end <- if (length(next_heading)) next_heading[1] - 1 else length(rest)
  section <- if (end >= 1) rest[seq_len(end)] else character(0)
  table_lines <- section[grepl("^\\s*\\|", section)]
  if (length(table_lines) < 2) return(data.frame())

  split_row <- function(l) {
    trimws(strsplit(sub("^\\s*\\|", "", sub("\\|\\s*$", "", l)), "\\|")[[1]])
  }
  header <- split_row(table_lines[1])
  body <- table_lines[-(1:2)] # drop header row and the |---|---| separator
  body <- body[nzchar(trimws(body))]
  if (length(body) == 0) {
    empty <- as.data.frame(matrix(character(0), ncol = length(header)), stringsAsFactors = FALSE)
    names(empty) <- header
    return(empty)
  }
  rows <- lapply(body, function(l) {
    cells <- split_row(l)
    length(cells) <- length(header)
    cells
  })
  df <- as.data.frame(do.call(rbind, rows), stringsAsFactors = FALSE)
  names(df) <- header
  df
}
