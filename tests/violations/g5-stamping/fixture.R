# Violation fixture for G5 (stamping): builds a throwaway git repo with an
# uncommitted change to SPEC.md, so stamp_output() must refuse to run
# against it. Built at test time -- a working tree's dirty state can't be
# represented as a file checked into version control -- rather than stored
# as a nested .git under this repo.

build_dirty_spec_repo <- function() {
  root <- tempfile("g5-stamping-")
  dir.create(root)
  system2("git", c("init", "-q", root))
  system2("git", c("-C", root, "config", "user.email", "guard-test@example.com"))
  system2("git", c("-C", root, "config", "user.name", "Guard Test"))
  writeLines("# SPEC v1", file.path(root, "SPEC.md"))
  system2("git", c("-C", root, "add", "SPEC.md"))
  system2("git", c("-C", root, "commit", "-q", "-m", "init"))
  writeLines("# SPEC v1 (edited, uncommitted)", file.path(root, "SPEC.md"))
  root
}
