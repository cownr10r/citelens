# ---------------------------------------------------------------------------
# Duplicate paper listings (title matching)
# ---------------------------------------------------------------------------

# Lower-case, fold common accents to plain letters, drop punctuation, and
# collapse spaces, so "Cafe: A Study!" and "cafe a study" compare equal.
.fold_text <- function(s) {
  s <- tolower(enc2utf8(as.character(s)))
  s <- chartr(
    "\u00e0\u00e1\u00e2\u00e3\u00e4\u00e5\u00e7\u00e8\u00e9\u00ea\u00eb\u00ec\u00ed\u00ee\u00ef\u00f1\u00f2\u00f3\u00f4\u00f5\u00f6\u00f8\u00f9\u00fa\u00fb\u00fc\u00fd\u00ff",
    "aaaaaaceeeeiiiinoooooouuuuyy", s)
  s <- gsub("[^\\p{L}\\p{N}]+", " ", s, perl = TRUE)
  trimws(s)
}

# Use `authors`, or fall back to a BibTeX-style `author` column.
.author_column <- function(data, authors) {
  if (authors %in% names(data)) return(authors)
  if (identical(authors, "authors") && "author" %in% names(data)) return("author")
  NULL
}

#' Find papers that appear more than once in a Scholar export
#'
#' Google Scholar sometimes lists the same paper twice: a journal version and a
#' preprint, a re-indexed copy with one citation, or a reprint with a new year.
#' In a co-authorship network that makes two authors look as if they wrote more
#' papers together than they did. This function flags likely duplicates without
#' changing your data.
#'
#' Two rows are treated as the same paper when their titles match after
#' lower-casing, folding accents, and removing punctuation and extra spaces
#' (`method = "exact"`), or when they are within `max_dist` of each other by edit
#' distance (`method = "near"`, the default, which also catches a missing word or
#' a typo). By default a pair is flagged only when the rows also share at least
#' one author surname, so two different papers that happen to have a generic
#' title are not merged.
#'
#' The `"near"` method compares every pair of titles, so memory and time grow
#' with the square of the number of rows. It is fine for a few thousand
#' references; for much larger files use `method = "exact"`.
#'
#' @param data A data frame of papers, such as the result of
#'   [scholar_parse_html()] or [bib_to_df()].
#' @param title,authors,year,cites Names of the columns holding the title, the
#'   author string, the year, and the citation count. If there is no `authors`
#'   column but there is an `author` column (as from [bib_to_df()]), that one is
#'   used. Missing year or citation columns are allowed.
#' @param sep Regular expression separating authors in the author string.
#'   Default `"\\s+and\\s+"`.
#' @param method `"near"` (default) or `"exact"`.
#' @param max_dist For `"near"`: the largest edit distance, as a share of the
#'   longer title. Default 0.08 (about 1 character in 12).
#' @param require_author_overlap Only flag pairs that share an author surname.
#'   Default `TRUE`.
#' @return A data frame of class `citelens_duplicates` with one row per flagged
#'   paper: `group`, `row` (row number in `data`), `title`, `year`, `cited_by`,
#'   `authors`, and `keep` (`TRUE` for the most-cited row in each group). It has
#'   zero rows if nothing is flagged.
#' @seealso [dedupe_papers()] to remove the copies, [find_duplicates()] to find
#'   near-duplicate entries by abstract similarity instead of by title.
#' @examples
#' f <- system.file("extdata", "sample_authors.csv", package = "citelens")
#' papers <- read.csv(f, stringsAsFactors = FALSE)
#' dups <- find_duplicate_papers(papers)
#' dups   # review before removing anything
#' @export
find_duplicate_papers <- function(data, title = "title", authors = "authors",
                                  year = "year", cites = "cited_by",
                                  sep = "\\s+and\\s+", method = c("near", "exact"),
                                  max_dist = 0.08, require_author_overlap = TRUE) {
  if (!is.data.frame(data)) stop("`data` must be a data frame.", call. = FALSE)
  if (!is.character(title) || length(title) != 1 || !title %in% names(data)) {
    stop("Column '", paste(title, collapse = ""), "' not found in `data`.", call. = FALSE)
  }
  method <- match.arg(method)
  if (!is.numeric(max_dist) || length(max_dist) != 1 || max_dist < 0 || max_dist > 1) {
    stop("`max_dist` must be a number between 0 and 1.", call. = FALSE)
  }
  n <- nrow(data)
  tt <- as.character(data[[title]])
  tt[is.na(tt)] <- ""
  nt <- .fold_text(tt)

  acol <- .author_column(data, authors)
  surn <- if (!is.null(acol)) {
    lapply(as.character(data[[acol]]), function(a) {
      if (is.na(a) || !nzchar(a)) return(character())
      p <- trimws(strsplit(a, sep, perl = TRUE)[[1]])
      unique(.fold_text(sub(",.*$", "", p)))
    })
  } else {
    rep(list(character()), n)
  }
  share <- function(i, j) length(intersect(surn[[i]], surn[[j]])) > 0

  # pairwise matches are merged into groups with a simple union-find
  parent <- seq_len(n)
  find <- function(i) {
    while (parent[i] != i) i <- parent[i]
    i
  }
  ok <- which(nzchar(nt))
  if (method == "exact") {
    for (g in split(ok, nt[ok])) {
      if (length(g) < 2) next
      for (k in g[-1]) {
        if (!require_author_overlap || any(vapply(g[g != k], function(j) share(j, k), logical(1)))) {
          parent[find(k)] <- find(g[1])
        }
      }
    }
  } else if (length(ok) > 1) {
    if (length(ok) > 5000) {
      message("Comparing ", length(ok), " titles pairwise may be slow and memory-heavy; ",
              "`method = \"exact\"` is much faster.")
    }
    nn <- nt[ok]
    D <- utils::adist(nn)
    R <- D / pmax(outer(nchar(nn), nchar(nn), pmax), 1)
    cand <- which(R <= max_dist & lower.tri(R), arr.ind = TRUE)
    for (q in seq_len(nrow(cand))) {
      a <- ok[cand[q, 1]]
      b <- ok[cand[q, 2]]
      if (!require_author_overlap || share(a, b)) parent[find(a)] <- find(b)
    }
  }
  root <- vapply(seq_len(n), find, integer(1))
  tab <- table(root)
  multi <- as.integer(names(tab)[tab > 1])

  cit <- if (cites %in% names(data)) suppressWarnings(as.numeric(data[[cites]])) else rep(NA_real_, n)
  yr <- if (year %in% names(data)) data[[year]] else rep(NA, n)
  au <- if (!is.null(acol)) as.character(data[[acol]]) else rep(NA_character_, n)
  out <- do.call(rbind, lapply(seq_along(multi), function(gi) {
    rows <- which(root == multi[gi])
    best <- rows[order(-ifelse(is.na(cit[rows]), -Inf, cit[rows]), rows)][1]
    data.frame(group = gi, row = rows, title = tt[rows], year = yr[rows],
               cited_by = cit[rows], authors = au[rows], keep = rows == best,
               stringsAsFactors = FALSE)
  }))
  if (is.null(out)) {
    out <- data.frame(group = integer(), row = integer(), title = character(),
                      year = integer(), cited_by = numeric(), authors = character(),
                      keep = logical(), stringsAsFactors = FALSE)
  }
  class(out) <- c("citelens_duplicates", "data.frame")
  out
}

#' @export
print.citelens_duplicates <- function(x, ...) {
  if (!all(c("group", "row", "keep") %in% names(x))) {
    class(x) <- "data.frame"
    return(print(x, ...))
  }
  if (!nrow(x)) {
    cat("No duplicate papers found.\n")
    return(invisible(x))
  }
  cat(length(unique(x$group)), " group(s) of likely duplicates; ", sum(!x$keep),
      " row(s) would be dropped.\n\n", sep = "")
  for (g in unique(x$group)) {
    s <- x[x$group == g, ]
    cat("Group ", g, "\n", sep = "")
    for (i in seq_len(nrow(s))) {
      cat(sprintf("  %s row %-4d %s | %s | %s cites | %s\n",
                  if (s$keep[i]) "KEEP" else "drop", s$row[i], s$year[i],
                  substr(s$authors[i], 1, 30), format(s$cited_by[i], big.mark = ","),
                  substr(s$title[i], 1, 70)))
    }
    cat("\n")
  }
  invisible(x)
}

#' Remove the less-cited copy of each duplicated paper
#'
#' Runs [find_duplicate_papers()] and drops every flagged row except the
#' most-cited one in each group. Review the result of [find_duplicate_papers()]
#' first.
#'
#' @param data A data frame of papers.
#' @param ... Passed to [find_duplicate_papers()].
#' @param drop_rows Optional integer vector of row numbers to drop instead of the
#'   automatic choice, for example after reviewing the list.
#' @return `data` without the duplicate rows, with an attribute `"dropped"`
#'   holding the flagged rows that were removed.
#' @examples
#' f <- system.file("extdata", "sample_authors.csv", package = "citelens")
#' papers <- read.csv(f, stringsAsFactors = FALSE)
#' clean <- dedupe_papers(papers)
#' attr(clean, "dropped")
#' @export
dedupe_papers <- function(data, ..., drop_rows = NULL) {
  dups <- find_duplicate_papers(data, ...)
  rows <- if (is.null(drop_rows)) dups$row[!dups$keep] else as.integer(drop_rows)
  if (length(rows) && (anyNA(rows) || any(rows < 1 | rows > nrow(data)))) {
    stop("`drop_rows` must be row numbers between 1 and ", nrow(data), ".", call. = FALSE)
  }
  out <- if (length(rows)) data[-rows, , drop = FALSE] else data
  rownames(out) <- NULL
  attr(out, "dropped") <- dups[dups$row %in% rows, ]
  message("Dropped ", length(rows), " duplicate row(s); ", nrow(out), " papers remain.")
  out
}
