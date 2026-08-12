# G5 -- stamping. `stamp_output()` is the only sanctioned way to write a
# result file under this repository's guards. It stamps the git commit hash
# and the SHA-256 of SPEC.md at run time, and refuses to run if SPEC.md has
# uncommitted changes -- a stamp must describe a spec state that was
# actually committed, or it is not traceable.

#' Full git commit hash of HEAD in `repo_root`.
current_commit_hash <- function(repo_root = ".") {
  out <- suppressWarnings(system2(
    "git", c("-C", repo_root, "rev-parse", "HEAD"),
    stdout = TRUE, stderr = TRUE
  ))
  status <- attr(out, "status")
  if (!is.null(status) && status != 0) {
    stop("stamp_output(): could not resolve git HEAD in ", repo_root, ": ", paste(out, collapse = "\n"))
  }
  out[1]
}

#' Does `spec_path` have staged or unstaged changes relative to HEAD?
spec_has_uncommitted_changes <- function(repo_root = ".", spec_path = "SPEC.md") {
  # `git -C repo_root` resolves any relative pathspec against repo_root, not
  # against this process's cwd -- so a relative spec_path (e.g. "../../SPEC.md",
  # composed against the caller's cwd) must be made absolute first, or git
  # resolves it against the wrong base and reports it as outside the repo.
  out <- suppressWarnings(system2(
    "git", c("-C", repo_root, "status", "--porcelain", "--", normalizePath(spec_path, mustWork = TRUE)),
    stdout = TRUE, stderr = TRUE
  ))
  length(out) > 0 && any(nzchar(out))
}

#' Write `x` as CSV to `path`, preceded by a two-line stamp naming the git
#' commit hash and the SHA-256 of SPEC.md at run time. Refuses to run if
#' SPEC.md has uncommitted changes (G5).
stamp_output <- function(x, path, repo_root = ".", spec_path = file.path(repo_root, "SPEC.md")) {
  if (spec_has_uncommitted_changes(repo_root, spec_path)) {
    stop("stamp_output(): SPEC.md has uncommitted changes; commit or discard before writing output")
  }
  commit <- current_commit_hash(repo_root)
  spec_hash <- digest::digest(spec_path, algo = "sha256", file = TRUE)

  body_con <- textConnection("body_lines", "w", local = TRUE)
  utils::write.table(x, body_con, sep = ",", row.names = FALSE)
  close(body_con)

  writeLines(c(
    sprintf("# commit: %s", commit),
    sprintf("# spec_sha256: %s", spec_hash),
    body_lines
  ), path)
  invisible(path)
}
