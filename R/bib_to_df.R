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
#'
#' @return A data frame with one row per BibTeX entry.
#' @examples
#' f <- system.file("extdata", "sample.bib", package = "biblio")
#' bib_to_df(f)
#' @export
bib_to_df <- function(input, clean = TRUE) {
  if (!file.exists(input)) stop("File not found: ", input, call. = FALSE)
  lines <- readLines(input, encoding = "UTF-8", warn = FALSE)
  df <- bib_parse_cpp(lines, isTRUE(clean))

  if (nrow(df) == 0) {
    warning("No BibTeX entries found in: ", input, call. = FALSE)
  }
  df
}
