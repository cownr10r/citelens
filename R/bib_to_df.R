#' Read a BibTeX (.bib) file into a data frame
#'
#' Parses a BibTeX file with compiled C++ code and returns one row per entry.
#' The entry type is in `bibtype`, the citation key in `bibkey`, and every
#' BibTeX field found in the file (author, title, year, ...) becomes a column.
#' Fields an entry doesn't have are `NA`. All columns are character vectors.
#'
#' `@string` macros and the standard month abbreviations (`jan`, `feb`, ...) are
#' expanded, `#` concatenation is handled, and `@comment` / `@preamble` blocks are
#' ignored.
#'
#' @param input Path to the `.bib` (or `.txt`) file.
#' @param clean If `TRUE` (the default), tidy each value: remove grouping braces
#'   (e.g. `{{Title}}` becomes `Title`), unescape backslash-escaped ampersands,
#'   percent signs, dollar signs, hashes and underscores, and collapse line
#'   breaks and repeated spaces. Other LaTeX commands, such as accents, are left
#'   as they are. Use `FALSE` to get the raw values.
#' @param xlsx Optional path for an Excel file (e.g. `"~/Desktop/refs.xlsx"`).
#'   If given, the data frame is also written there as a single sheet with a
#'   header row, and the data frame is returned invisibly. A missing `.xlsx`
#'   extension is added. An existing file at that path is overwritten.
#'
#' @return A data frame with one row per BibTeX entry (invisibly when `xlsx`
#'   is given).
#' @examples
#' f <- system.file("extdata", "sample.bib", package = "citelens")
#' bib_to_df(f)
#'
#' # Also save an Excel copy
#' out <- tempfile(fileext = ".xlsx")
#' bib_to_df(f, xlsx = out)
#' @export
bib_to_df <- function(input, clean = TRUE, xlsx = NULL) {
  if (!file.exists(input)) stop("File not found: ", input, call. = FALSE)
  if (!is.null(xlsx)) xlsx <- .xlsx_path(xlsx)  # fail early on a bad path

  lines <- .read_text_lines(input)
  df <- bib_parse_cpp(lines, isTRUE(clean))

  if (nrow(df) == 0) {
    warning("No BibTeX entries found in: ", input, call. = FALSE)
    return(df)  # nothing worth writing to Excel
  }

  if (!is.null(xlsx)) {
    .write_xlsx_df(df, xlsx)
    return(invisible(df))
  }

  df
}
