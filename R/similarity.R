#' Document similarity (cosine similarity of TF-IDF vectors)
#'
#' Measures how alike the abstracts in a data frame are. Each abstract is turned
#' into a vector of word weights (TF-IDF: a word counts for more when it is
#' frequent in that abstract and rare across the collection), and two abstracts
#' are compared by the cosine of the angle between their vectors: 0 means no
#' words in common, 1 means the same word profile. Text is cleaned the same way
#' as in [topic_model()].
#'
#' Similarity reflects shared vocabulary, not meaning, so two abstracts that use
#' different words for the same idea can look less alike than they are. The
#' result stores a full abstract-by-abstract matrix, which is fine for thousands
#' of abstracts but grows with the square of their number.
#'
#' @inheritParams topic_model
#' @param min_doc_freq Drop words that occur in fewer than this many abstracts.
#'   The default of 2 ignores words that cannot link two abstracts.
#' @return An object of class `citelens_similarity`. Use [similar_to()],
#'   [find_duplicates()] and [plot_similarity()] to explore it; the matrix itself
#'   is in `$sim`.
#' @examples
#' f <- system.file("extdata", "sample_abstracts.bib", package = "citelens")
#' refs <- bib_to_df(f)
#' s <- doc_similarity(refs)
#' similar_to(s, "syn01", n = 3)
#' @export
doc_similarity <- function(data, text = "abstract", id = "bibkey", min_doc_freq = 2,
                           max_doc_prop = 1, min_word_length = 3, stopwords = NULL,
                           singularize = TRUE) {
  if (!is.data.frame(data)) stop("`data` must be a data frame.", call. = FALSE)
  if (!is.character(text) || length(text) != 1 || !text %in% names(data)) {
    stop("Column '", paste(text, collapse = ""), "' not found in `data`.", call. = FALSE)
  }
  raw <- as.character(data[[text]])
  has_text <- !is.na(raw) & nzchar(trimws(raw))
  if (sum(has_text) < 2) {
    stop("Need at least 2 non-empty '", text, "' values to compare.", call. = FALSE)
  }
  rows <- which(has_text)
  ids <- if (id %in% names(data)) as.character(data[[id]]) else as.character(seq_len(nrow(data)))

  sw <- unique(c(.citelens_stopwords, tolower(stopwords)))
  tokens <- .tokenize(raw[rows], sw, min_word_length, isTRUE(singularize))

  n_all <- length(tokens)
  doc_freq <- table(unlist(lapply(tokens, unique), use.names = FALSE))
  vocab <- names(doc_freq)[doc_freq >= min_doc_freq & doc_freq <= max_doc_prop * n_all]
  if (length(vocab) < 1) {
    stop("No words remain after filtering. Lower `min_doc_freq` or supply more abstracts.",
         call. = FALSE)
  }
  df <- as.numeric(doc_freq[vocab])
  idf <- log((n_all + 1) / (df + 1)) + 1

  word_ids <- list()
  word_wts <- list()
  for (d in seq_len(n_all)) {
    m <- match(tokens[[d]], vocab)
    m <- m[!is.na(m)]
    cnt <- table(m)
    w <- as.integer(names(cnt))
    word_ids[[d]] <- w - 1L
    word_wts[[d]] <- (1 + log(as.numeric(cnt))) * idf[w]   # sublinear tf * idf
  }

  usable <- lengths(word_ids) > 0
  if (sum(usable) < 2) {
    stop("Fewer than 2 abstracts have any usable words. Lower `min_doc_freq`.", call. = FALSE)
  }
  n_dropped <- sum(!usable)
  if (n_dropped > 0) {
    message(n_dropped, " abstract(s) had no usable words and were left out.")
  }
  rows <- rows[usable]
  sim <- cosine_sparse_cpp(word_ids[usable], word_wts[usable], length(vocab))
  dimnames(sim) <- list(ids[rows], ids[rows])

  structure(
    list(sim = sim, doc_ids = ids[rows], doc_rows = rows, n_rows = nrow(data),
         vocab = vocab),
    class = "citelens_similarity"
  )
}

.check_sim <- function(s) {
  if (!inherits(s, "citelens_similarity")) {
    stop("`s` must be the result of doc_similarity().", call. = FALSE)
  }
}

#' @export
print.citelens_similarity <- function(x, ...) {
  n <- length(x$doc_ids)
  off <- x$sim[upper.tri(x$sim)]
  cat("<citelens document similarity>\n")
  cat(n, " abstracts, ", length(x$vocab), " distinct words\n", sep = "")
  cat("pairwise cosine similarity: median ", format(round(stats::median(off), 3)),
      ", 90th percentile ", format(round(unname(stats::quantile(off, 0.9)), 3)),
      ", max ", format(round(max(off), 3)), "\n", sep = "")
  cat("Use similarity_to_df(s) for a table (and xlsx = \"file.xlsx\" to save it to Excel).\n")
  invisible(x)
}

#' @export
plot.citelens_similarity <- function(x, ...) plot_similarity(x, ...)

#' Abstracts most similar to a given one
#'
#' @param s A result from [doc_similarity()].
#' @param which The reference to look up: its id (for example the `bibkey`) or
#'   its position among the abstracts used.
#' @param n Number of similar abstracts to return.
#' @param data Optional: the data frame passed to [doc_similarity()]. If given,
#'   the `title` column (see `title`) is added to the result.
#' @param title Name of the title column in `data`.
#' @return A data frame with `rank`, `id`, `similarity` (and `title`).
#' @export
similar_to <- function(s, which, n = 5, data = NULL, title = "title") {
  .check_sim(s)
  if (length(which) != 1) stop("`which` must be a single id or position.", call. = FALSE)
  i <- if (is.numeric(which)) as.integer(which) else match(as.character(which), s$doc_ids)
  if (is.na(i) || i < 1 || i > length(s$doc_ids)) {
    stop("Reference '", which, "' not found among the abstracts used.", call. = FALSE)
  }
  v <- s$sim[i, ]
  v[i] <- NA
  o <- order(v, decreasing = TRUE, na.last = NA)
  o <- o[seq_len(min(n, length(o)))]
  out <- data.frame(rank = seq_along(o), id = s$doc_ids[o], similarity = unname(v[o]),
                    stringsAsFactors = FALSE)
  if (!is.null(data) && title %in% names(data)) out$title <- as.character(data[[title]])[s$doc_rows[o]]
  out
}

#' Find likely duplicate or near-duplicate references
#'
#' Lists every pair of abstracts whose cosine similarity is at or above
#' `cutoff`, most similar first. Useful for cleaning a library where the same
#' article was entered twice.
#'
#' @param s A result from [doc_similarity()].
#' @param cutoff Minimum similarity to report (0 to 1).
#' @param data Optional: the data frame passed to [doc_similarity()]. If given,
#'   the `title` of each reference is added.
#' @param title Name of the title column in `data`.
#' @return A data frame with `id_1`, `id_2` and `similarity` (and `title_1`,
#'   `title_2`); zero rows if no pair reaches the cutoff.
#' @export
find_duplicates <- function(s, cutoff = 0.9, data = NULL, title = "title") {
  .check_sim(s)
  if (!is.numeric(cutoff) || cutoff < 0 || cutoff > 1) {
    stop("`cutoff` must be between 0 and 1.", call. = FALSE)
  }
  ix <- which(upper.tri(s$sim) & !is.na(s$sim) & s$sim >= cutoff - 1e-9, arr.ind = TRUE)
  ix <- ix[order(s$sim[ix], decreasing = TRUE), , drop = FALSE]
  out <- data.frame(id_1 = s$doc_ids[ix[, 1]], id_2 = s$doc_ids[ix[, 2]],
                    similarity = s$sim[ix], stringsAsFactors = FALSE)
  if (!is.null(data) && title %in% names(data)) {
    tt <- as.character(data[[title]])
    out$title_1 <- tt[s$doc_rows[ix[, 1]]]
    out$title_2 <- tt[s$doc_rows[ix[, 2]]]
  }
  rownames(out) <- NULL
  out
}

#' Heatmap of document similarity
#'
#' @param s A result from [doc_similarity()].
#' @param order If `TRUE` (default), reorder abstracts so that similar ones sit
#'   together (hierarchical clustering).
#' @param labels Show reference ids on the axes? Defaults to `TRUE` for up to 40
#'   abstracts.
#' @param values Print the similarity number inside each box? Defaults to `TRUE`
#'   for up to 30 abstracts; with more, the numbers get too small to read.
#' @param digits Decimal places for the numbers (default 2).
#' @return A ggplot object.
#' @export
plot_similarity <- function(s, order = TRUE, labels = length(s$doc_ids) <= 40,
                            values = length(s$doc_ids) <= 30, digits = 2) {
  .check_sim(s)
  m <- s$sim
  ids <- s$doc_ids
  if (isTRUE(order) && length(ids) > 2) {
    d <- stats::as.dist(1 - m)
    d[is.na(d)] <- 1
    ids <- ids[stats::hclust(d, "average")$order]
  }
  g <- expand.grid(a = ids, b = ids, stringsAsFactors = FALSE)
  g$similarity <- m[cbind(match(g$a, s$doc_ids), match(g$b, s$doc_ids))]
  g$a <- factor(g$a, levels = ids)
  g$b <- factor(g$b, levels = rev(ids))

  g$label <- ifelse(is.na(g$similarity), "", formatC(g$similarity, format = "f", digits = digits))
  g$dark <- !is.na(g$similarity) & g$similarity > 0.55

  p <- ggplot2::ggplot(g, ggplot2::aes(x = .data$a, y = .data$b, fill = .data$similarity)) +
    ggplot2::geom_tile() +
    ggplot2::scale_fill_gradient(low = "#f7fbff", high = "#08306b", limits = c(0, 1),
                                 name = "Cosine\nsimilarity") +
    ggplot2::coord_equal() +
    ggplot2::labs(title = "Document similarity", x = NULL, y = NULL) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(panel.grid = ggplot2::element_blank())
  if (isTRUE(values)) {
    n <- length(ids)
    p <- p +
      ggplot2::geom_text(ggplot2::aes(label = .data$label, colour = .data$dark),
                         size = max(1.6, min(3.5, 70 / n)), show.legend = FALSE) +
      ggplot2::scale_colour_manual(values = c("FALSE" = "#1a1a1a", "TRUE" = "white"))
  }
  if (isTRUE(labels)) {
    p <- p + ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 90, hjust = 1, vjust = 0.5))
  } else {
    p <- p + ggplot2::theme(axis.text = ggplot2::element_blank())
  }
  p
}

#' Similarity results as a data frame (optionally saved to Excel)
#'
#' Turns the result of [doc_similarity()] into a data frame you can view, filter
#' and save. Two layouts are available:
#'
#' * `type = "matrix"`: one row and one column per reference, with the cosine
#'   similarity in each cell (the table behind the heatmap).
#' * `type = "pairs"`: one row per pair of references, most similar first, which
#'   is easier to sort, filter and scan.
#'
#' If you give `xlsx`, an Excel workbook is written with **both** layouts, on
#' sheets named `similarity_matrix` and `pairs`, whichever `type` you asked for.
#'
#' @param s A result from [doc_similarity()].
#' @param type `"matrix"` (default) or `"pairs"`.
#' @param data Optional: the data frame passed to [doc_similarity()]. If given,
#'   the `title` column is added (`title` in the matrix; `title_1` and `title_2`
#'   in the pairs).
#' @param title Name of the title column in `data`.
#' @param digits Decimal places to round the similarities to (default 3). Use
#'   `NULL` for no rounding.
#' @param cutoff For `type = "pairs"` (and the pairs sheet in Excel): keep only
#'   pairs at or above this similarity (0 to 1). Default 0 keeps every pair.
#' @param xlsx Optional path for an Excel file (e.g. `"~/Desktop/similarity.xlsx"`).
#'   A missing `.xlsx` ending is added. When given, the data frame is returned
#'   invisibly.
#' @return A data frame. For `"matrix"`: `id` (plus `title`) and one column per
#'   reference. For `"pairs"`: `id_1`, `id_2`, `similarity` (plus `title_1`,
#'   `title_2`).
#' @examples
#' f <- system.file("extdata", "sample_abstracts.bib", package = "citelens")
#' refs <- bib_to_df(f)
#' s <- doc_similarity(refs)
#' head(similarity_to_df(s, "pairs", data = refs), 3)
#' out <- tempfile(fileext = ".xlsx")
#' similarity_to_df(s, data = refs, xlsx = out)
#' @export
similarity_to_df <- function(s, type = c("matrix", "pairs"), data = NULL, title = "title",
                             digits = 3, cutoff = 0, xlsx = NULL) {
  .check_sim(s)
  type <- match.arg(type)
  if (!is.null(xlsx)) xlsx <- .xlsx_path(xlsx)      # fail early on a bad path
  if (!is.null(digits) && (!is.numeric(digits) || length(digits) != 1 || digits < 0)) {
    stop("`digits` must be a non-negative number, or NULL.", call. = FALSE)
  }

  titles <- NULL
  if (!is.null(data) && title %in% names(data)) {
    titles <- as.character(data[[title]])[s$doc_rows]
  }

  make_matrix <- function() {
    m <- s$sim
    if (!is.null(digits)) m <- round(m, digits)
    colnames(m) <- make.unique(s$doc_ids)
    rownames(m) <- NULL
    out <- data.frame(id = s$doc_ids, stringsAsFactors = FALSE)
    if (!is.null(titles)) out$title <- titles
    cbind(out, as.data.frame(m, check.names = FALSE, stringsAsFactors = FALSE))
  }
  make_pairs <- function() {
    p <- find_duplicates(s, cutoff = cutoff, data = data, title = title)
    if (!is.null(digits)) p$similarity <- round(p$similarity, digits)
    p
  }

  result <- if (type == "matrix") make_matrix() else make_pairs()

  if (!is.null(xlsx)) {
    mat <- if (type == "matrix") result else make_matrix()
    prs <- if (type == "pairs") result else make_pairs()
    sheets <- list(similarity_matrix = mat, pairs = prs)
    if (ncol(mat) > 16384) {
      stop("Too many references (", length(s$doc_ids), ") for an Excel sheet; ",
           "use type = \"pairs\" with a cutoff instead.", call. = FALSE)
    }
    if (nrow(prs) > 1048575) {
      message("The pairs table has ", nrow(prs), " rows, more than an Excel sheet holds; ",
              "leaving it out. Raise `cutoff` to keep only the most similar pairs.")
      sheets$pairs <- NULL
    }
    writexl::write_xlsx(sheets, xlsx)
    message("Wrote the similarity matrix (", nrow(mat), " x ", length(s$doc_ids), ") and ",
            nrow(prs), " pair(s) to ", xlsx)
    return(invisible(result))
  }
  result
}

#' @export
as.data.frame.citelens_similarity <- function(x, row.names = NULL, optional = FALSE,
                                            type = "pairs", ...) {
  similarity_to_df(x, type = type, ...)
}
