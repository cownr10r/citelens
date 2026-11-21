#' Correspondence analysis of abstract vocabulary across time periods
#'
#' Tokenises abstracts, adds up word counts within time periods, and runs a
#' correspondence analysis (CA) on the resulting words-by-periods table. The
#' map shows which words are characteristic of which period, and how the
#' periods relate to one another in vocabulary. Uses base R only (a singular
#' value decomposition).
#'
#' @param data A data frame with one row per reference, such as the result of
#'   [bib_to_df()].
#' @param text Name of the column holding the abstracts.
#' @param year Name of the column holding the publication year. Text such as
#'   "2019" or "Spring 2019" is fine; the first 4-digit number is used.
#' @param breaks The first year of the 2nd, 3rd, ... period. `c(2005, 2013,
#'   2019)` gives four periods: before 2005, 2005-2012, 2013-2018, and 2019 and
#'   later. If `NULL` (the default), the years are split into `n_periods`
#'   periods holding roughly equal numbers of abstracts.
#' @param n_periods Number of periods to use when `breaks` is `NULL`.
#' @param min_words Leave out abstracts shorter than this many words. Very short
#'   texts are mostly parsing leftovers and add noise.
#' @param min_doc_freq Keep a word only if it occurs in at least this many
#'   abstracts.
#' @param min_word_length Drop words shorter than this many letters.
#' @param stopwords Extra words to drop, in addition to [citelens_stopwords()].
#'   Use this for words that are common to your whole field and so say nothing
#'   about change over time.
#' @param singularize Merge simple plurals (default `TRUE`).
#' @param n_dims Number of dimensions to return (at most the number of periods
#'   minus one). The default returns all of them.
#' @param min_count A word must be used at least this many times in a period to
#'   be listed as distinctive for it.
#' @param n_distinctive Number of distinctive words to list per period.
#'
#' @return An object of class `citelens_ca`, a list with:
#' \describe{
#'   \item{table}{Words-by-periods count matrix that was analysed.}
#'   \item{periods}{Period labels with the number of abstracts and words in each.}
#'   \item{eigen}{Singular value, inertia and percent of inertia per dimension.}
#'   \item{terms}{Data frame of word coordinates (`Dim1`, ...), `ctr1`, ...
#'     (contribution to each dimension, in percent), `quality` (share of the
#'     word's inertia captured by the dimensions kept) and `count`.}
#'   \item{period_coords}{Period coordinates on each dimension.}
#'   \item{distinctive}{For each period, the words most over-represented
#'     relative to the whole collection (`lift` = share in the period divided by
#'     share overall), among words used at least `min_count` times in that
#'     period.}
#'   \item{total_inertia, chisq, n}{Total inertia (chi-square divided by `n`),
#'     the chi-square statistic, and the number of words analysed.}
#'   \item{n_docs}{Number of abstracts analysed.}
#' }
#' @details
#' Words are the rows and periods the columns, so with k periods there are at
#' most k - 1 dimensions. The analysis is descriptive: words within one abstract
#' are not independent, so the chi-square value is not a valid test and no
#' p-value should be read from it. Because periods are ordered, the first two
#' dimensions often trace a curved gradient (the "horseshoe" or Guttman effect)
#' that reflects the time ordering rather than two separate themes. Words and
#' periods are both plotted in principal coordinates, so only distances
#' *within* the words or *within* the periods are directly interpretable.
#'
#' Periods with no usable words are dropped, and at least two periods and 20
#' abstracts are needed.
#' @seealso [word_trends()] and [topic_trends()] for trends of single words and
#'   topics over time.
#' @examples
#' f <- system.file("extdata", "sample_abstracts.bib", package = "citelens")
#' refs <- bib_to_df(f)
#' filler <- c("note", "time", "follow", "shape", "touch", "studied", "evidence",
#'             "work", "attention", "discussion")   # words from the synthetic sample
#' ca <- abstract_ca(refs, breaks = c(2017, 2020), stopwords = filler,
#'                   min_doc_freq = 3)
#' ca
#' ca$distinctive
#' plot(ca)
#' @export
abstract_ca <- function(data, text = "abstract", year = "year", breaks = NULL,
                        n_periods = 4, min_words = 30, min_doc_freq = 5,
                        min_word_length = 3, stopwords = NULL, singularize = TRUE,
                        n_dims = NULL, min_count = 5, n_distinctive = 10) {
  if (!is.data.frame(data)) stop("`data` must be a data frame.", call. = FALSE)
  for (col in c(text, year)) {
    if (!is.character(col) || length(col) != 1 || !col %in% names(data)) {
      stop("Column '", paste(col, collapse = ""), "' not found in `data`.", call. = FALSE)
    }
  }
  if (!is.null(breaks) && (!is.numeric(breaks) || anyNA(breaks) || !all(is.finite(breaks)))) {
    stop("`breaks` must be a vector of years, or NULL.", call. = FALSE)
  }
  if (is.null(breaks) && (!is.numeric(n_periods) || length(n_periods) != 1 ||
                          n_periods < 2 || n_periods != round(n_periods))) {
    stop("`n_periods` must be a whole number of at least 2.", call. = FALSE)
  }

  raw <- as.character(data[[text]])
  yr <- .parse_year(data[[year]])
  n_words <- lengths(strsplit(trimws(ifelse(is.na(raw), "", raw)), "\\s+"))
  keep <- !is.na(raw) & n_words >= min_words & !is.na(yr)
  if (sum(keep) < 20) {
    stop("Fewer than 20 abstracts have text, a year, and at least ", min_words,
         " words. Lower `min_words` or supply more abstracts.", call. = FALSE)
  }
  if (sum(!keep) > 0) {
    message(sum(!keep), " abstract(s) left out (no abstract or year, or fewer than ",
            min_words, " words).")
  }
  raw <- raw[keep]
  yr <- yr[keep]

  # ---- periods -------------------------------------------------------------
  if (is.null(breaks)) {
    ys <- sort(yr)
    idx <- floor(length(ys) * seq_len(n_periods - 1) / n_periods) + 1
    breaks <- ys[idx]
  }
  breaks <- sort(unique(breaks))
  lab <- c(paste0("<", breaks[1]),
           if (length(breaks) > 1) paste0(breaks[-length(breaks)], "-", breaks[-1] - 1),
           paste0(breaks[length(breaks)], "+"))
  period <- cut(yr, c(-Inf, breaks, Inf), labels = lab, right = FALSE)

  # ---- tokenise (same cleaning as topic_model() and word_trends()) ---------
  sw <- unique(c(.citelens_stopwords, tolower(stopwords)))
  tok <- .tokenize(raw, sw, min_word_length, isTRUE(singularize))

  # ---- words kept, then words-by-periods table -----------------------------
  doc_freq <- table(unlist(lapply(tok, unique), use.names = FALSE))
  words <- names(doc_freq)[doc_freq >= min_doc_freq]
  if (length(words) < 10) {
    stop("Only ", length(words), " words occur in at least ", min_doc_freq,
         " abstracts. Lower `min_doc_freq`.", call. = FALSE)
  }
  doc_id <- rep(seq_along(tok), lengths(tok))
  tt <- unlist(tok, use.names = FALSE)
  ok <- tt %in% words
  tab <- unclass(table(factor(tt[ok], levels = sort(words)), period[doc_id[ok]]))
  dimnames(tab) <- list(rownames(tab), lab)
  n_abs <- as.integer(table(period))

  tab <- tab[rowSums(tab) > 0, , drop = FALSE]
  used <- colSums(tab) > 0
  if (sum(used) < 2) {
    stop("Fewer than two periods contain any words. Check `breaks`.", call. = FALSE)
  }
  if (any(!used)) {
    message("Dropped period(s) with no usable words: ", paste(lab[!used], collapse = ", "), ".")
    tab <- tab[, used, drop = FALSE]
    lab <- lab[used]
    n_abs <- n_abs[used]
  }
  tab <- tab[rowSums(tab) > 0, , drop = FALSE]

  # ---- correspondence analysis (SVD of standardised residuals) -------------
  n <- sum(tab)
  P <- tab / n
  r <- rowSums(P)
  cm <- colSums(P)
  E <- r %o% cm
  sv <- svd((P - E) / sqrt(E))
  k <- min(dim(tab)) - 1
  if (is.null(n_dims)) n_dims <- k
  n_dims <- min(n_dims, k)
  d <- sv$d[seq_len(k)]
  inertia <- d^2
  total_inertia <- sum(inertia)

  U <- sv$u[, seq_len(k), drop = FALSE]
  V <- sv$v[, seq_len(k), drop = FALSE]
  Fm <- (U / sqrt(r)) %*% diag(d, k)    # words, principal coordinates
  Gm <- (V / sqrt(cm)) %*% diag(d, k)   # periods, principal coordinates
  dn <- paste0("Dim", seq_len(k))
  dimnames(Fm) <- list(rownames(tab), dn)
  dimnames(Gm) <- list(colnames(tab), dn)

  ctr <- 100 * U^2
  colnames(ctr) <- paste0("ctr", seq_len(k))
  tot_sq <- rowSums(Fm^2)
  quality <- ifelse(tot_sq > 0,
                    rowSums(Fm[, seq_len(n_dims), drop = FALSE]^2) / tot_sq, NA_real_)

  terms_df <- data.frame(term = rownames(tab), count = rowSums(tab),
                         Fm[, seq_len(n_dims), drop = FALSE],
                         ctr[, seq_len(n_dims), drop = FALSE],
                         quality = round(quality, 3),
                         row.names = NULL, stringsAsFactors = FALSE)

  # ---- distinctive words per period (lift) ---------------------------------
  share_all <- rowSums(tab) / n
  distinctive <- lapply(seq_len(ncol(tab)), function(j) {
    lift <- (tab[, j] / sum(tab[, j])) / share_all
    ok2 <- tab[, j] >= min_count
    o <- order(-lift[ok2])[seq_len(min(n_distinctive, sum(ok2)))]
    if (length(o) == 0) return(NULL)
    data.frame(period = colnames(tab)[j], term = rownames(tab)[ok2][o],
               count = tab[ok2, j][o], lift = round(lift[ok2][o], 2),
               row.names = NULL, stringsAsFactors = FALSE)
  })
  distinctive <- do.call(rbind, distinctive)
  if (is.null(distinctive)) {
    distinctive <- data.frame(period = character(), term = character(),
                              count = integer(), lift = numeric(),
                              stringsAsFactors = FALSE)
  }

  structure(
    list(
      table = tab,
      periods = data.frame(period = lab, n_abstracts = n_abs, n_words = colSums(tab),
                           row.names = NULL, stringsAsFactors = FALSE),
      eigen = data.frame(dim = dn, singular_value = round(d, 4), inertia = round(inertia, 5),
                         pct = round(100 * inertia / total_inertia, 1),
                         cum_pct = round(cumsum(100 * inertia / total_inertia), 1),
                         stringsAsFactors = FALSE),
      terms = terms_df,
      period_coords = data.frame(period = lab, Gm[, seq_len(n_dims), drop = FALSE],
                                 row.names = NULL, stringsAsFactors = FALSE),
      distinctive = distinctive,
      total_inertia = total_inertia, chisq = total_inertia * n, n = n,
      n_docs = length(tok)
    ),
    class = "citelens_ca"
  )
}

#' Plot an abstract correspondence analysis
#'
#' Map of two dimensions: periods as large labelled squares, and the `n_terms`
#' words contributing most to those two dimensions as labelled points.
#'
#' @param x An object from [abstract_ca()].
#' @param dims Two dimensions to plot (default 1 and 2).
#' @param n_terms Number of words to label.
#' @param ... Ignored.
#' @return `x`, invisibly.
#' @export
plot.citelens_ca <- function(x, dims = c(1, 2), n_terms = 30, ...) {
  dcol <- paste0("Dim", dims)
  ccol <- paste0("ctr", dims)
  if (length(dims) != 2 || !all(dcol %in% names(x$terms))) {
    stop("This analysis has only ", sum(grepl("^Dim", names(x$terms))),
         " dimension(s); `dims` must name two of them.", call. = FALSE)
  }
  tm <- x$terms
  pc <- x$period_coords
  score <- tm[[ccol[1]]] * x$eigen$pct[dims[1]] + tm[[ccol[2]]] * x$eigen$pct[dims[2]]
  top <- tm[order(-score)[seq_len(min(n_terms, nrow(tm)))], ]
  rng <- function(a, b) {
    r <- range(c(a, b))
    r + c(-1, 1) * diff(r) * 0.12
  }
  xl <- rng(top[[dcol[1]]], pc[[dcol[1]]])
  yl <- rng(top[[dcol[2]]], pc[[dcol[2]]])

  op <- graphics::par(mar = c(5.6, 4.2, 3, 1))
  on.exit(graphics::par(op), add = TRUE)
  graphics::plot(NA, xlim = xl, ylim = yl, asp = 1,
                 xlab = sprintf("Dimension %d (%.1f%%)", dims[1], x$eigen$pct[dims[1]]),
                 ylab = sprintf("Dimension %d (%.1f%%)", dims[2], x$eigen$pct[dims[2]]),
                 main = "Correspondence analysis: abstract vocabulary by period")
  graphics::abline(h = 0, v = 0, col = "grey80", lty = 2)
  graphics::points(top[[dcol[1]]], top[[dcol[2]]], pch = 16, col = "grey45", cex = 0.8)

  # Greedy label placement: try above, below, right, left, and keep the first
  # spot that does not overlap a label already placed or a period marker.
  px <- top[[dcol[1]]]
  py <- top[[dcol[2]]]
  cex_l <- 0.72
  box <- function(x0, y0, lab, pos) {
    w <- graphics::strwidth(lab, cex = cex_l)
    h <- graphics::strheight(lab, cex = cex_l)
    dx <- graphics::strwidth("m", cex = cex_l) * 0.6
    dy <- h * 0.9
    switch(as.character(pos),
           "3" = c(x0 - w / 2, y0 + dy, x0 + w / 2, y0 + dy + h),
           "1" = c(x0 - w / 2, y0 - dy - h, x0 + w / 2, y0 - dy),
           "4" = c(x0 + dx, y0 - h / 2, x0 + dx + w, y0 + h / 2),
           "2" = c(x0 - dx - w, y0 - h / 2, x0 - dx, y0 + h / 2))
  }
  hit <- function(a, b) !(a[3] < b[1] || b[3] < a[1] || a[4] < b[2] || b[4] < a[2])
  placed <- list()
  mw <- graphics::strwidth("MM", cex = 1.6)
  mh <- graphics::strheight("M", cex = 1.6)
  for (i in seq_len(nrow(pc))) {   # keep room around the period markers
    placed[[length(placed) + 1]] <- c(pc[[dcol[1]]][i] - mw, pc[[dcol[2]]][i] - mh * 2.6,
                                      pc[[dcol[1]]][i] + mw, pc[[dcol[2]]][i] + mh)
  }
  for (i in seq_along(px)) {
    chosen <- 3
    for (pp in c(3, 1, 4, 2)) {
      b <- box(px[i], py[i], top$term[i], pp)
      if (!any(vapply(placed, hit, logical(1), b = b))) {
        chosen <- pp
        break
      }
    }
    placed[[length(placed) + 1]] <- box(px[i], py[i], top$term[i], chosen)
    graphics::text(px[i], py[i], top$term[i], pos = chosen, cex = cex_l,
                   col = "grey20", offset = 0.35)
  }
  graphics::points(pc[[dcol[1]]], pc[[dcol[2]]], pch = 15, col = "#B2182B", cex = 2.2)
  graphics::text(pc[[dcol[1]]], pc[[dcol[2]]], pc$period, pos = 1, font = 2,
                 col = "#B2182B", cex = 1.0, offset = 0.9)
  graphics::mtext(sprintf("%d abstracts, %s words; labelled words = top %d contributors to these two dimensions",
                          x$n_docs, format(x$n, big.mark = ","), nrow(top)),
                  side = 1, line = 4.4, cex = 0.7, col = "grey35")
  invisible(x)
}

#' @export
print.citelens_ca <- function(x, ...) {
  cat("Correspondence analysis of abstracts by period\n")
  cat(x$n_docs, "abstracts |", nrow(x$table), "words |", format(x$n, big.mark = ","),
      "word tokens\n\n")
  print(x$periods, row.names = FALSE)
  cat("\nInertia by dimension (total inertia = ", round(x$total_inertia, 4), "):\n", sep = "")
  print(x$eigen, row.names = FALSE)
  cat("\nMost distinctive words per period (lift):\n")
  for (p in unique(x$distinctive$period)) {
    d <- x$distinctive[x$distinctive$period == p, ]
    cat(sprintf("  %-10s %s\n", p, paste0(d$term[seq_len(min(6, nrow(d)))], collapse = ", ")))
  }
  invisible(x)
}
