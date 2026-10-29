# Pull a 4-digit year out of whatever is in the year column ("2019", "2019/03", "Spring 2019").
.parse_year <- function(x) {
  y <- suppressWarnings(as.integer(sub("^.*?(\\d{4}).*$", "\\1", as.character(x), perl = TRUE)))
  y[!grepl("\\d{4}", as.character(x))] <- NA_integer_
  y
}

.check_bin <- function(bin) {
  if (!is.numeric(bin) || length(bin) != 1 || bin < 1 || bin != round(bin)) {
    stop("`bin` must be a whole number of years (1 or more).", call. = FALSE)
  }
}

.year_axis <- function(p, periods, bin) {
  pers <- sort(unique(periods))
  if (bin > 1) {
    # label only the real periods, e.g. "2015-2019"
    p + ggplot2::scale_x_continuous(breaks = pers, labels = paste0(pers, "-", pers + bin - 1))
  } else {
    p + ggplot2::scale_x_continuous(breaks = function(x) unique(round(pretty(x))))
  }
}

#' Word trends over time
#'
#' For each year (or group of years), reports the share of abstracts that
#' mention a word. Words are cleaned the same way as in [topic_model()], so
#' "student" also counts "students". Use it to see whether a concept is rising
#' or fading across the literature.
#'
#' Years with only a few abstracts give jumpy shares, so check `n_period` (the
#' number of abstracts in that year) before reading much into a change. Use
#' `bin` to group years, for example `bin = 5`.
#'
#' @inheritParams topic_model
#' @param words Words to track, such as `c("equity", "belonging")`. If `NULL`,
#'   the `n` words found in the most abstracts overall are used.
#' @param n Number of words to track when `words` is `NULL`.
#' @param year Name of the column holding the publication year. Text such as
#'   "2019" or "Spring 2019" is fine; the first 4-digit number is used.
#' @param bin Width of each period in years (1 = one row per year).
#' @return A data frame with `period` (first year of the period), `term`,
#'   `n_docs` (abstracts mentioning it), `n_period` (abstracts in the period)
#'   and `share` (`n_docs / n_period`). Periods with no abstracts are omitted.
#' @examples
#' f <- system.file("extdata", "sample_abstracts.bib", package = "citelens")
#' refs <- bib_to_df(f)
#' word_trends(refs, words = c("retention", "tuition"), bin = 5)
#' @export
word_trends <- function(data, words = NULL, n = 8, year = "year", text = "abstract",
                        bin = 1, stopwords = NULL, min_word_length = 3, singularize = TRUE) {
  if (!is.data.frame(data)) stop("`data` must be a data frame.", call. = FALSE)
  for (col in c(text, year)) {
    if (!is.character(col) || length(col) != 1 || !col %in% names(data)) {
      stop("Column '", paste(col, collapse = ""), "' not found in `data`.", call. = FALSE)
    }
  }
  .check_bin(bin)

  raw <- as.character(data[[text]])
  yr <- .parse_year(data[[year]])
  keep <- !is.na(raw) & nzchar(trimws(raw)) & !is.na(yr)
  if (sum(keep) < 2) {
    stop("Need at least 2 references with both an abstract and a year.", call. = FALSE)
  }
  if (sum(keep) < nrow(data)) {
    message(nrow(data) - sum(keep), " reference(s) without an abstract or year were left out.")
  }

  sw <- unique(c(.citelens_stopwords, tolower(stopwords)))
  tokens <- .tokenize(raw[keep], sw, min_word_length, isTRUE(singularize))
  uniq <- lapply(tokens, unique)
  period <- (yr[keep] %/% bin) * bin

  if (is.null(words)) {
    freq <- sort(table(unlist(uniq, use.names = FALSE)), decreasing = TRUE)
    if (length(freq) == 0) stop("No words left after cleaning.", call. = FALSE)
    stems <- names(freq)[seq_len(min(n, length(freq)))]
    shown <- stems
  } else {
    words <- as.character(words)
    stems <- vapply(words, function(w) {
      t <- .tokenize(w, character(0), 1, isTRUE(singularize))[[1]]
      if (length(t) == 0) NA_character_ else t[1]
    }, character(1), USE.NAMES = FALSE)
    if (anyNA(stems)) {
      stop("Could not use word(s): ", paste(words[is.na(stems)], collapse = ", "), call. = FALSE)
    }
    shown <- words
  }

  pers <- sort(unique(period))
  n_period <- vapply(pers, function(p) sum(period == p), integer(1))
  rows <- lapply(seq_along(stems), function(i) {
    has <- vapply(uniq, function(u) stems[i] %in% u, logical(1))
    cnt <- vapply(pers, function(p) sum(has & period == p), integer(1))
    data.frame(period = pers, term = shown[i], n_docs = cnt, n_period = n_period,
               share = cnt / n_period, stringsAsFactors = FALSE)
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  attr(out, "bin") <- bin
  out
}

#' Topic trends over time
#'
#' Average share of each topic among the abstracts published in each year (or
#' group of years). Shares in a period add up to 1.
#'
#' @param model A model from [topic_model()].
#' @param data The same data frame that was passed to [topic_model()].
#' @param year Name of the column holding the publication year.
#' @param bin Width of each period in years.
#' @param n_terms Number of top words shown in each topic's label.
#' @return A data frame with `period`, `topic`, `label`, `share` (average
#'   share of an abstract) and `n_period` (abstracts in the period).
#' @export
topic_trends <- function(model, data, year = "year", bin = 1, n_terms = 3) {
  .check_model(model)
  if (!is.data.frame(data) || nrow(data) != model$n_rows) {
    stop("`data` must be the same data frame (", model$n_rows, " rows) used to fit the model.",
         call. = FALSE)
  }
  if (!is.character(year) || length(year) != 1 || !year %in% names(data)) {
    stop("Column '", paste(year, collapse = ""), "' not found in `data`.", call. = FALSE)
  }
  .check_bin(bin)

  yr <- .parse_year(data[[year]])[model$doc_rows]
  ok <- !is.na(yr)
  if (sum(ok) < 1) stop("No usable years found in column '", year, "'.", call. = FALSE)
  if (sum(!ok) > 0) message(sum(!ok), " abstract(s) without a year were left out.")
  period <- (yr[ok] %/% bin) * bin
  theta <- model$theta[ok, , drop = FALSE]

  pers <- sort(unique(period))
  labs <- .topic_labels(model, n_terms)
  rows <- lapply(pers, function(p) {
    sel <- period == p
    data.frame(period = p, topic = seq_len(model$k), label = labs,
               share = unname(colMeans(theta[sel, , drop = FALSE])),
               n_period = sum(sel), stringsAsFactors = FALSE)
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  attr(out, "bin") <- bin
  out
}

#' Line chart of word trends
#'
#' @param trends The result of [word_trends()].
#' @return A ggplot object.
#' @export
plot_word_trends <- function(trends) {
  if (!all(c("period", "term", "share") %in% names(trends))) {
    stop("`trends` must be the result of word_trends().", call. = FALSE)
  }
  bin <- if (is.null(attr(trends, "bin"))) 1 else attr(trends, "bin")
  trends$term <- factor(trends$term, levels = unique(trends$term))
  p <- ggplot2::ggplot(trends, ggplot2::aes(x = .data$period, y = .data$share,
                                            colour = .data$term, group = .data$term)) +
    ggplot2::geom_line(linewidth = 0.9) +
    ggplot2::geom_point(size = 2) +
    ggplot2::scale_y_continuous(labels = function(x) paste0(round(100 * x), "%"),
                                limits = c(0, NA)) +
    ggplot2::labs(title = "Word trends over time", x = NULL,
                  y = "Share of abstracts mentioning the word", colour = NULL) +
    ggplot2::theme_minimal(base_size = 12)
  .year_axis(p, trends$period, bin)
}

#' Line chart of topic trends
#'
#' @param trends The result of [topic_trends()].
#' @return A ggplot object.
#' @export
plot_topic_trends <- function(trends) {
  if (!all(c("period", "label", "share") %in% names(trends))) {
    stop("`trends` must be the result of topic_trends().", call. = FALSE)
  }
  bin <- if (is.null(attr(trends, "bin"))) 1 else attr(trends, "bin")
  trends$label <- factor(trends$label, levels = unique(trends$label))
  p <- ggplot2::ggplot(trends, ggplot2::aes(x = .data$period, y = .data$share,
                                            colour = .data$label, group = .data$label)) +
    ggplot2::geom_line(linewidth = 0.9) +
    ggplot2::geom_point(size = 2) +
    ggplot2::scale_y_continuous(labels = function(x) paste0(round(100 * x), "%"),
                                limits = c(0, NA)) +
    ggplot2::labs(title = "Topic trends over time", x = NULL,
                  y = "Average share of an abstract", colour = NULL) +
    ggplot2::theme_minimal(base_size = 12) +
    ggplot2::theme(legend.position = "bottom", legend.direction = "vertical")
  .year_axis(p, trends$period, bin)
}
