#' Citation index and ranking
#'
#' Ranks papers (or venues, or authors) by citation count and computes summary
#' citation indices (h-index, g-index, i10-index and more) for the whole
#' collection. Written in base R, so it adds no package dependencies.
#'
#' @param data A data frame with one row per paper, such as the result of
#'   [scholar_parse_html()] or [bib_to_df()].
#' @param by What to rank: `"paper"` (default), `"venue"` or `"author"`. For
#'   `"author"`, each author is credited with the full citation count of every
#'   paper they appear on.
#' @param cites,year,title,venue,authors Names of the columns in `data`. Defaults
#'   match the Google Scholar layout. If there is no `authors` column but there
#'   is an `author` column (as from [bib_to_df()]), that one is used.
#' @param sep Regular expression separating authors. Default `"\\s+and\\s+"`.
#' @param current_year Year used to compute paper age. Defaults to this year.
#' @param na_cites_as_zero If `TRUE` (default), a missing citation count is
#'   treated as 0, which is how Google Scholar reports an uncited paper (no
#'   "Cited by" link). If `FALSE`, those rows are dropped.
#' @param drop_untitled If `TRUE` (default), rows with no title (usually parse
#'   failures) are dropped with a message.
#' @param dedupe If `TRUE` (default), remove duplicate listings of the same
#'   paper before counting (see [find_duplicate_papers()]): the less-cited copy
#'   is dropped, a message names the rows, and they are returned in
#'   `$duplicates`. Use `FALSE` to count every row.
#' @param top_n Optional. Keep only the top `n` rows of the ranked table.
#'   Indices are always computed on the full data.
#'
#' @return An object of class `citelens_rank`, a list with:
#' \describe{
#'   \item{ranked}{Data frame sorted by rank. For `by = "paper"`: `rank`,
#'     `title`, `authors`, `venue`, `year`, `citations`, `percentile`, `share`,
#'     `cum_share`, `age`, `cites_per_year`, `rank_per_year`. For `"venue"` and
#'     `"author"`: `rank`, the entity name, `n_papers`, `total_citations`,
#'     `mean_citations`, `max_citations`, `h_index`, `share`, `cum_share`.}
#'   \item{index}{One-row data frame of whole-collection indices: `n_papers`,
#'     `total`, `mean`, `median`, `max`, `uncited`, `h_index`, `g_index`,
#'     `i10_index`.}
#'   \item{by, n_total}{What was ranked, and the number of rows before `top_n`.}
#'   \item{duplicates}{Rows dropped as duplicate listings, or `NULL`.}
#' }
#'
#' @details
#' * **h-index**: the largest h such that h papers each have at least h
#'   citations.
#' * **g-index**: the largest g such that the top g papers together have at
#'   least g^2 citations (capped at the number of papers).
#' * **i10-index**: number of papers with at least 10 citations.
#' * **rank** uses competition ranking (`ties.method = "min"`), so tied papers
#'   share a rank and the next rank is skipped.
#' * **percentile** is the percent of papers with strictly fewer citations.
#' * **cites_per_year** is citations divided by the paper's age, where
#'   age = `current_year - year + 1`, so a paper from this year has age 1.
#'
#' Author and venue tables are built from the papers that remain after
#' de-duplication and cleaning.
#' @seealso [find_duplicate_papers()], [author_network()]
#' @examples
#' f <- system.file("extdata", "sample_authors.csv", package = "citelens")
#' d <- read.csv(f, stringsAsFactors = FALSE)
#' res <- citation_rank(d, current_year = 2024)
#' res
#' res$index
#' citation_rank(d, by = "author", top_n = 5)$ranked
#' @export
citation_rank <- function(data,
                          by = c("paper", "venue", "author"),
                          cites = "cited_by",
                          year = "year",
                          title = "title",
                          venue = "venue",
                          authors = "authors",
                          sep = "\\s+and\\s+",
                          current_year = as.integer(format(Sys.Date(), "%Y")),
                          na_cites_as_zero = TRUE,
                          drop_untitled = TRUE,
                          dedupe = TRUE,
                          top_n = NULL) {
  by <- match.arg(by)
  if (!is.data.frame(data)) stop("`data` must be a data frame.", call. = FALSE)
  if (!is.null(top_n) && (!is.numeric(top_n) || length(top_n) != 1 || top_n < 1)) {
    stop("`top_n` must be a single positive number.", call. = FALSE)
  }

  acol <- .author_column(data, authors)
  if (is.null(acol)) acol <- authors      # absent: handled below
  need <- c(cites, title)
  if (by == "venue")  need <- c(need, venue)
  if (by == "author") need <- c(need, acol)
  missing_cols <- setdiff(need, names(data))
  if (length(missing_cols)) {
    stop("Column(s) not found in `data`: ", paste(missing_cols, collapse = ", "),
         call. = FALSE)
  }

  # duplicate listings of one paper inflate counts
  dup_dropped <- NULL
  if (isTRUE(dedupe)) {
    dd <- find_duplicate_papers(data, title = title, authors = acol, year = year,
                                cites = cites, sep = sep,
                                require_author_overlap = acol %in% names(data))
    if (any(!dd$keep)) {
      dup_dropped <- dd[!dd$keep, , drop = FALSE]
      message("Dropped ", nrow(dup_dropped), " duplicate paper listing(s): row ",
              paste(dup_dropped$row, collapse = ", "),
              ". Use dedupe = FALSE to keep them; see $duplicates.")
      data <- data[-dup_dropped$row, , drop = FALSE]
    }
  }

  # clean
  cit <- suppressWarnings(as.numeric(data[[cites]]))
  ttl <- as.character(data[[title]])
  keep <- rep(TRUE, nrow(data))
  if (drop_untitled) {
    untitled <- is.na(ttl) | !nzchar(trimws(ttl))
    if (any(untitled)) message("Dropped ", sum(untitled), " row(s) with no title.")
    keep <- keep & !untitled
  }
  if (na_cites_as_zero) {
    n_na <- sum(is.na(cit) & keep)
    if (n_na) message(n_na, " row(s) had no citation count; treated as 0.")
    cit[is.na(cit)] <- 0
  } else {
    keep <- keep & !is.na(cit)
  }
  data <- data[keep, , drop = FALSE]
  cit <- cit[keep]
  if (!nrow(data)) stop("No rows left to rank after cleaning.", call. = FALSE)

  yr <- if (year %in% names(data)) {
    suppressWarnings(as.integer(data[[year]]))
  } else {
    rep(NA_integer_, nrow(data))
  }
  col_or_na <- function(nm) {
    if (nm %in% names(data)) as.character(data[[nm]]) else rep(NA_character_, nrow(data))
  }

  index <- .cite_index(cit)

  if (by == "paper") {
    age <- current_year - yr + 1L
    age[!is.na(age) & age < 1L] <- 1L          # guard against future-dated rows
    cpy <- cit / age

    out <- data.frame(
      rank           = rank(-cit, ties.method = "min"),
      title          = as.character(data[[title]]),
      authors        = col_or_na(acol),
      venue          = col_or_na(venue),
      year           = yr,
      citations      = cit,
      percentile     = round(100 * vapply(cit, function(v) mean(cit < v), numeric(1)), 1),
      share          = NA_real_,
      cum_share      = NA_real_,
      age            = age,
      cites_per_year = round(cpy, 2),
      rank_per_year  = rank(-cpy, ties.method = "min", na.last = "keep"),
      stringsAsFactors = FALSE
    )
    out <- out[order(out$rank, -out$cites_per_year, out$title), , drop = FALSE]
    tot <- sum(out$citations)
    out$share     <- if (tot > 0) round(out$citations / tot, 4) else 0
    out$cum_share <- if (tot > 0) round(cumsum(out$citations) / tot, 4) else 0
  } else {
    if (by == "venue") {
      ent <- trimws(col_or_na(venue))
      ent[!nzchar(ent)] <- NA_character_
      rows <- seq_along(ent)
    } else {
      auth <- strsplit(col_or_na(acol), sep)
      auth <- lapply(auth, function(a) {
        a <- trimws(gsub("\u2026|\\.\\.\\.", "", a))   # drop Scholar's "..." markers
        unique(a[!is.na(a) & nzchar(a)])
      })
      rows <- rep(seq_along(auth), lengths(auth))
      ent  <- unlist(auth, use.names = FALSE)
    }
    cc <- cit[rows]
    ok <- !is.na(ent)
    ent <- ent[ok]
    cc <- cc[ok]
    if (!length(ent)) stop("No non-missing ", by, " values to rank.", call. = FALSE)

    grp <- split(cc, ent)
    out <- data.frame(
      name            = names(grp),
      n_papers        = lengths(grp, use.names = FALSE),
      total_citations = vapply(grp, sum, numeric(1), USE.NAMES = FALSE),
      mean_citations  = round(vapply(grp, mean, numeric(1), USE.NAMES = FALSE), 1),
      max_citations   = vapply(grp, max, numeric(1), USE.NAMES = FALSE),
      h_index         = vapply(grp, function(v) .cite_index(v)$h_index, numeric(1),
                               USE.NAMES = FALSE),
      stringsAsFactors = FALSE
    )
    names(out)[1] <- by
    out <- out[order(-out$total_citations, -out$n_papers, out[[by]]), , drop = FALSE]
    out$rank <- rank(-out$total_citations, ties.method = "min")
    tot <- sum(out$total_citations)
    out$share     <- if (tot > 0) round(out$total_citations / tot, 4) else 0
    out$cum_share <- if (tot > 0) round(cumsum(out$total_citations) / tot, 4) else 0
    out <- out[, c("rank", by, "n_papers", "total_citations", "mean_citations",
                   "max_citations", "h_index", "share", "cum_share")]
  }

  rownames(out) <- NULL
  n_total <- nrow(out)
  if (!is.null(top_n)) out <- utils::head(out, top_n)

  structure(list(ranked = out, index = index, by = by, n_total = n_total,
                 duplicates = dup_dropped),
            class = "citelens_rank")
}

# h, g, i10 and descriptive stats for a vector of citation counts
.cite_index <- function(x) {
  x <- sort(x[!is.na(x)], decreasing = TRUE)
  n <- length(x)
  data.frame(
    n_papers  = n,
    total     = sum(x),
    mean      = round(if (n) mean(x) else 0, 1),
    median    = if (n) stats::median(x) else 0,
    max       = if (n) max(x) else 0,
    uncited   = sum(x == 0),
    h_index   = sum(x >= seq_len(n)),
    g_index   = if (n) max(c(0L, which(cumsum(x) >= seq_len(n)^2))) else 0L,
    i10_index = sum(x >= 10),
    row.names = NULL
  )
}

#' @export
print.citelens_rank <- function(x, n = 10, ...) {
  cat("Citation index (", x$by, " ranking)\n", sep = "")
  print(x$index, row.names = FALSE)
  cat("\nTop ", min(n, nrow(x$ranked)), " of ", x$n_total, ":\n", sep = "")
  show <- utils::head(x$ranked, n)
  if ("title" %in% names(show)) show$title <- substr(show$title, 1, 50)
  if ("authors" %in% names(show)) show$authors <- substr(show$authors, 1, 25)
  if ("venue" %in% names(show) && x$by == "paper") show$venue <- substr(show$venue, 1, 25)
  print(show, row.names = FALSE)
  invisible(x)
}
