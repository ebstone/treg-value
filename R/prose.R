# G8 -- no status prose. Status belongs in OPEN_QUESTIONS.md only; R/ and
# README.md must never carry it as prose that goes stale silently.

BANNED_STATUS_PHRASES <- c(
  "currently", "not yet", "still a stub", "TODO", "flagged for", "for now"
)

#' Lines in `path` containing a banned status phrase (case-insensitive),
#' formatted as "path:line: phrase".
find_status_prose <- function(path, phrases = BANNED_STATUS_PHRASES) {
  if (!file.exists(path)) return(character(0))
  lines <- readLines(path, warn = FALSE)
  hits <- character(0)
  for (i in seq_along(lines)) {
    for (p in phrases) {
      if (grepl(p, lines[i], ignore.case = TRUE, fixed = FALSE)) {
        hits <- c(hits, sprintf("%s:%d: %s", path, i, p))
      }
    }
  }
  hits
}

#' Same, over every *.R file under `dir` plus `readme`. `exclude_basename`
#' is this guard's own definition file: it must hold the banned phrases
#' verbatim as data (`BANNED_STATUS_PHRASES` above), so it is exempt from
#' its own scan -- the same carve-out G4 makes for test-provenance.R.
find_status_prose_in_repo <- function(dir = "R", readme = "README.md", exclude_basename = "prose.R") {
  files <- list.files(dir, pattern = "\\.R$", recursive = TRUE, full.names = TRUE)
  files <- files[basename(files) != exclude_basename]
  unlist(lapply(c(files, readme), find_status_prose, phrases = BANNED_STATUS_PHRASES))
}
