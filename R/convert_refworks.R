#' Convert a RefWorks Tagged Format export to a .bib file
#'
#' Reads citations exported from RefWorks in Tagged Format and converts them to
#' BibTeX entries using compiled C++ code.
#'
#' @param input Path to the RefWorks tagged-format text file.
#' @param output Path for the .bib file. If `NULL` (the default), nothing is
#'   written and the entries are returned.
#'
#' @return A character vector with one BibTeX entry per record (invisibly when
#'   `output` is given).
#' @examples
#' f <- system.file("extdata", "sample_refworks.txt", package = "biblio")
#' cat(convert_refworks(f)[1])
#' @export
convert_refworks <- function(input, output = NULL) {
  if (!file.exists(input)) stop("File not found: ", input, call. = FALSE)
  lines   <- readLines(input, encoding = "UTF-8", warn = FALSE)
  entries <- refworks_to_bib(lines)

  if (length(entries) == 0) {
    warning("No RefWorks records found (expected lines starting with 'RT ').",
            call. = FALSE)
  }

  if (is.null(output)) return(entries)

  writeLines(paste(entries, collapse = "\n"), output, useBytes = TRUE)
  message("Converted ", length(entries), " record(s) -> ", output)
  invisible(entries)
}
