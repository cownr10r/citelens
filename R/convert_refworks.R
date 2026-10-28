#' Convert a RefWorks export (Tagged Format or RIS) to a .bib file
#'
#' Reads citations exported from RefWorks in either RefWorks Tagged Format or
#' RIS format (detected automatically) and converts them to BibTeX entries
#' using compiled C++ code.
#'
#' @param input Path to the exported citation file (`.txt` or `.ris`).
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
  lines   <- .read_text_lines(input)
  entries <- refworks_to_bib(lines)

  if (length(entries) == 0) {
    warning("No records found (expected RefWorks Tagged lines starting with 'RT ' or RIS lines starting with 'TY  - ').",
            call. = FALSE)
  }

  if (is.null(output)) return(entries)

  writeLines(paste(entries, collapse = "\n"), output, useBytes = TRUE)
  message("Converted ", length(entries), " record(s) -> ", output)
  invisible(entries)
}
