#' Convert a RefWorks export straight to an Excel file
#'
#' One step from a RefWorks export (Tagged Format or RIS, detected
#' automatically) to an Excel spreadsheet with one row per reference. Internally
#' it runs [convert_refworks()] and then [bib_to_df()], so the same cleaning of
#' odd characters applies. Optionally it also saves the intermediate BibTeX file.
#'
#' @param input Path to the RefWorks export (`.txt` or `.ris`).
#' @param xlsx Path for the Excel file, e.g. `"~/Desktop/references.xlsx"`. A
#'   missing `.xlsx` extension is added and an existing file is overwritten.
#' @param bib Optional path for a BibTeX file to save as well (e.g.
#'   `"~/Desktop/references.bib"`). Leave as `NULL` to skip it.
#' @param clean Passed to [bib_to_df()]: tidy braces, LaTeX escapes and extra
#'   whitespace in the values (default `TRUE`).
#'
#' @return The data frame of references, invisibly.
#' @examples
#' ris <- system.file("extdata", "sample_refworks.ris", package = "citelens")
#' refworks_to_xlsx(ris, tempfile(fileext = ".xlsx"))
#' @export
refworks_to_xlsx <- function(input, xlsx, bib = NULL, clean = TRUE) {
  if (!file.exists(input)) stop("File not found: ", input, call. = FALSE)
  xlsx <- .xlsx_path(xlsx)  # fail early on a bad path, before doing any work

  entries <- convert_refworks(input, output = bib)
  bib_lines <- if (length(entries)) {
    unlist(strsplit(entries, "\n", fixed = TRUE), use.names = FALSE)
  } else {
    character(0)
  }
  df <- bib_parse_cpp(bib_lines, isTRUE(clean))

  if (nrow(df) == 0) {
    return(invisible(df))  # convert_refworks() has already warned
  }

  .write_xlsx_df(df, xlsx)
  invisible(df)
}
