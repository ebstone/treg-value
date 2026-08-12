# G7 -- no defaults. Reads the "Arg name" column of OPEN_QUESTIONS.md's open
# items table: the canonical R argument name each open item binds to, so
# "no function may supply a default for it" is a mechanical check rather
# than free-text matching against the question prose.

#' Canonical argument names for OPEN_QUESTIONS.md's open items (the "Arg
#' name" column) -- the identifiers G7 forbids a default for.
open_item_arg_names <- function(path = "OPEN_QUESTIONS.md") {
  tbl <- parse_md_table(path, heading = "Open questions")
  if (!"Arg name" %in% names(tbl)) {
    stop("open_item_arg_names(): OPEN_QUESTIONS.md's open table has no 'Arg name' column")
  }
  names_ <- gsub("`", "", trimws(tbl[["Arg name"]]))
  names_[nzchar(names_)]
}

#' "fn_name(arg_name)" for every function in `env` that supplies a default
#' value for an argument named in `arg_names`.
defaulted_open_item_args <- function(env, arg_names) {
  fn_names <- Filter(function(n) is.function(get(n, envir = env)), ls(env))
  offenders <- character(0)
  for (n in fn_names) {
    fn <- get(n, envir = env)
    f <- formals(fn)
    hits <- intersect(names(f), arg_names)
    for (h in hits) {
      if (!identical(f[[h]], quote(expr = ))) offenders <- c(offenders, paste0(n, "(", h, ")"))
    }
  }
  offenders
}
