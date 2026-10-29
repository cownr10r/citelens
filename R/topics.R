#' @importFrom ggplot2 .data
NULL

# ---------------------------------------------------------------------------
# Text preparation (internal)
# ---------------------------------------------------------------------------

# Crude, conservative plural -> singular so "students"/"student" count together.
.singularize <- function(w) {
  if (length(w) == 0) return(w)
  protect <- w %in% c("series", "species", "news", "bias", "lens", "atlas") |
    grepl("(ss|us|is|ics)$", w) | nchar(w) <= 3
  v <- w[!protect]
  y <- grepl("[^aeiou]ies$", v)
  e <- !y & grepl("(ss|x|ch|sh|zz)es$", v)
  s <- !y & !e & grepl("s$", v)
  v[y] <- sub("ies$", "y", v[y])
  v[e] <- sub("es$", "", v[e])
  v[s] <- sub("s$", "", v[s])
  w[!protect] <- v
  w
}

# Lower-case, strip punctuation/digits, drop stop words and short words.
.tokenize <- function(text, stopwords, min_length, singularize) {
  x <- tolower(enc2utf8(text))
  x <- gsub("['\u2019]s\\b", "", x, perl = TRUE)   # possessives: student's -> student
  x <- gsub("['\u2019]", "", x, perl = TRUE)       # other apostrophes: don't -> dont
  x <- gsub("[^\\p{L}]+", " ", x, perl = TRUE)     # keep letters (any language) only
  lapply(strsplit(trimws(x), " ", fixed = TRUE), function(tok) {
    tok <- tok[nzchar(tok)]
    tok <- tok[!tok %in% stopwords]
    if (singularize) tok <- .singularize(tok)
    tok[nchar(tok) >= min_length & !tok %in% stopwords]
  })
}

# UMass topic coherence: do a topic's top words tend to appear in the same
# abstracts? Closer to zero is better; compare topics/models on the same data.
.coherence <- function(phi, doc_word_ids, n_top = 10) {
  K <- nrow(phi)
  n_top <- min(n_top, ncol(phi))
  if (n_top < 2) return(rep(NA_real_, K))
  top <- lapply(seq_len(K), function(k) order(phi[k, ], decreasing = TRUE)[seq_len(n_top)])
  uniq <- sort(unique(unlist(top)))
  present <- matrix(0, nrow = length(doc_word_ids), ncol = length(uniq))
  for (d in seq_along(doc_word_ids)) {
    m <- match(doc_word_ids[[d]], uniq)
    present[d, m[!is.na(m)]] <- 1
  }
  co <- crossprod(present)   # number of abstracts containing both words
  df <- diag(co)             # number of abstracts containing each word
  vapply(top, function(tw) {
    idx <- match(tw, uniq)
    total <- 0
    for (m in 2:length(idx)) {
      for (l in seq_len(m - 1)) {
        total <- total + log((co[idx[m], idx[l]] + 1) / df[idx[l]])
      }
    }
    total
  }, numeric(1))
}

.check_model <- function(model) {
  if (!inherits(model, "citelens_topics")) {
    stop("`model` must be the result of topic_model().", call. = FALSE)
  }
}

.topic_labels <- function(model, n_terms = 3) {
  tt <- topic_terms(model, n_terms)
  top <- vapply(split(tt$term, tt$topic), paste, character(1), collapse = ", ")
  paste0("Topic ", seq_len(model$k), ": ", top[as.character(seq_len(model$k))])
}

# ---------------------------------------------------------------------------
# Fitting
# ---------------------------------------------------------------------------

#' Topic modeling (LDA) of abstracts
#'
#' Fits a Latent Dirichlet Allocation topic model to the abstracts in a data
#' frame, such as the one returned by [bib_to_df()]. Each abstract is treated as
#' a mixture of `k` topics and each topic as a distribution over words. Fitting
#' uses a collapsed Gibbs sampler written in C++.
#'
#' Text is lower-cased, punctuation and numbers are removed, stop words (see
#' [citelens_stopwords()]) and very short words are dropped, and simple plurals are
#' merged (students and student count as one word). Words that occur in fewer
#' than `min_doc_freq` abstracts are ignored.
#'
#' Topic models need a reasonably large collection (dozens of abstracts or
#' more) to give stable themes. With a handful of abstracts the output is only
#' exploratory. Different `seed` values can give somewhat different topics;
#' use [topic_k_search()] to help choose `k`.
#'
#' @param data A data frame with one row per reference.
#' @param k Number of topics (at least 2).
#' @param text Name of the column holding the text to analyse.
#' @param id Name of a column that identifies each reference (default
#'   `"bibkey"`). If it does not exist, row numbers are used.
#' @param n_iter Number of Gibbs sampling sweeps.
#' @param alpha Prior on how many topics each abstract mixes. Smaller values
#'   mean each abstract concentrates on fewer topics. Default `5 / k`.
#' @param beta Prior on how many words each topic uses. Smaller values mean
#'   more focused topics.
#' @param min_doc_freq Drop words that occur in fewer than this many abstracts.
#' @param max_doc_prop Drop words that occur in more than this share of the
#'   abstracts (1 keeps everything; try 0.5 to remove words common to nearly
#'   every abstract).
#' @param min_word_length Drop words shorter than this many letters.
#' @param stopwords Extra words to drop, in addition to [citelens_stopwords()].
#' @param singularize Merge simple plurals (default `TRUE`).
#' @param seed Optional number passed to [set.seed()] so the fit can be
#'   reproduced.
#'
#' @return An object of class `citelens_topics`. Use [topic_terms()],
#'   [topic_documents()], [topic_summary()], [plot_topic_terms()] and
#'   [plot_topic_prevalence()] to explore it. Topics are numbered from the most
#'   to the least prevalent.
#' @examples
#' f <- system.file("extdata", "sample_abstracts.bib", package = "citelens")
#' refs <- bib_to_df(f)
#' filler <- c("note", "time", "follow", "shape", "touch", "studied", "evidence",
#'             "work", "attention", "discussion")   # words from the synthetic sample
#' m <- topic_model(refs, k = 3, stopwords = filler, seed = 1)
#' m
#' topic_terms(m, n = 5)
#' @export
topic_model <- function(data, k = 5, text = "abstract", id = "bibkey",
                        n_iter = 1000, alpha = 5 / k, beta = 0.01,
                        min_doc_freq = 2, max_doc_prop = 1, min_word_length = 3,
                        stopwords = NULL, singularize = TRUE, seed = NULL) {
  if (!is.data.frame(data)) stop("`data` must be a data frame.", call. = FALSE)
  if (!is.character(text) || length(text) != 1 || !text %in% names(data)) {
    stop("Column '", paste(text, collapse = ""), "' not found in `data`.", call. = FALSE)
  }
  if (!is.numeric(k) || length(k) != 1 || k < 2 || k != round(k)) {
    stop("`k` must be a whole number of at least 2.", call. = FALSE)
  }
  if (!is.numeric(n_iter) || n_iter < 10) stop("`n_iter` must be at least 10.", call. = FALSE)
  if (alpha <= 0 || beta <= 0) stop("`alpha` and `beta` must be positive.", call. = FALSE)

  raw <- as.character(data[[text]])
  has_text <- !is.na(raw) & nzchar(trimws(raw))
  if (sum(has_text) < 2) {
    stop("Need at least 2 non-empty '", text, "' values to fit a topic model.", call. = FALSE)
  }
  rows <- which(has_text)
  ids <- if (id %in% names(data)) as.character(data[[id]]) else as.character(seq_len(nrow(data)))

  sw <- unique(c(.citelens_stopwords, tolower(stopwords)))
  tokens <- .tokenize(raw[rows], sw, min_word_length, isTRUE(singularize))

  n_all <- length(tokens)
  doc_freq <- table(unlist(lapply(tokens, unique), use.names = FALSE))
  vocab <- names(doc_freq)[doc_freq >= min_doc_freq & doc_freq <= max_doc_prop * n_all]
  if (length(vocab) < k) {
    stop("Only ", length(vocab), " distinct words remain after filtering, fewer than k = ", k,
         ". Lower `min_doc_freq` or `k`, or supply more abstracts.", call. = FALSE)
  }

  word_ids <- lapply(tokens, function(t) {
    m <- match(t, vocab)
    m[!is.na(m)]
  })
  usable <- lengths(word_ids) >= 3
  if (sum(usable) < 2) {
    stop("Fewer than 2 abstracts have enough usable words. Lower `min_doc_freq`.", call. = FALSE)
  }
  n_dropped <- sum(!usable)
  if (n_dropped > 0) {
    message(n_dropped, " abstract(s) had fewer than 3 usable words and were left out.")
  }
  rows <- rows[usable]
  word_ids <- word_ids[usable]

  if (length(word_ids) < 20) {
    message("Only ", length(word_ids), " abstracts: topic models are most reliable with dozens ",
            "or more, so treat these topics as exploratory.")
  }

  if (!is.null(seed)) set.seed(seed)
  fit <- lda_gibbs_cpp(lapply(word_ids, function(x) x - 1L), length(vocab), as.integer(k),
                       alpha, beta, as.integer(n_iter), max(1L, as.integer(n_iter %/% 20)))

  # number topics from most to least prevalent
  ord <- order(colMeans(fit$theta), decreasing = TRUE)
  phi <- fit$phi[ord, , drop = FALSE]
  theta <- fit$theta[, ord, drop = FALSE]
  dimnames(phi) <- list(paste("Topic", seq_len(k)), vocab)
  dimnames(theta) <- list(ids[rows], paste("Topic", seq_len(k)))

  structure(
    list(
      k = as.integer(k), alpha = alpha, beta = beta, n_iter = as.integer(n_iter), seed = seed,
      vocab = vocab, phi = phi, theta = theta,
      doc_ids = ids[rows], doc_rows = rows, n_rows = nrow(data),
      doc_lengths = lengths(word_ids), n_dropped = n_dropped,
      loglik = data.frame(iteration = fit$loglik_iter, loglik = fit$loglik),
      coherence = .coherence(phi, word_ids)
    ),
    class = "citelens_topics"
  )
}

#' @export
print.citelens_topics <- function(x, ...) {
  cat("<citelens topic model>\n")
  cat(x$k, " topics from ", length(x$doc_ids), " abstracts (", length(x$vocab),
      " distinct words, ", sum(x$doc_lengths), " word occurrences)\n", sep = "")
  cat("alpha = ", format(x$alpha, digits = 3), ", beta = ", x$beta,
      ", sweeps = ", x$n_iter, "\n\n", sep = "")
  s <- topic_summary(x, 6)
  s$prevalence <- sprintf("%.0f%%", 100 * s$prevalence)
  s$coherence <- round(s$coherence, 1)
  print(s, row.names = FALSE)
  invisible(x)
}

#' @export
plot.citelens_topics <- function(x, ...) plot_topic_terms(x, ...)

# ---------------------------------------------------------------------------
# Results as data frames
# ---------------------------------------------------------------------------

#' Top terms of each topic
#'
#' @param model A model from [topic_model()].
#' @param n Number of terms to return per topic.
#' @return A data frame with columns `topic`, `rank`, `term` and `beta` (the
#'   probability of the term within the topic).
#' @export
topic_terms <- function(model, n = 10) {
  .check_model(model)
  out <- lapply(seq_len(model$k), function(t) {
    p <- model$phi[t, ]
    o <- order(p, decreasing = TRUE)[seq_len(min(n, length(p)))]
    data.frame(topic = t, rank = seq_along(o), term = colnames(model$phi)[o],
               beta = unname(p[o]), stringsAsFactors = FALSE)
  })
  do.call(rbind, out)
}

#' Topic assignments for each abstract
#'
#' Gives, for every abstract used in the model, its dominant topic, how strongly
#' it belongs to that topic, and its mix of all topics.
#'
#' @param model A model from [topic_model()].
#' @param data Optional: the same data frame you passed to [topic_model()]. If
#'   given, the topic columns are added to it (with `NA` for rows that had no
#'   usable abstract), so you can keep working with your reference table.
#' @return A data frame with `dominant_topic`, `dominant_prob` and one
#'   `topic_<number>` column per topic (an `id` and `row` column are included
#'   when `data` is not given).
#' @export
topic_documents <- function(model, data = NULL) {
  .check_model(model)
  theta <- model$theta
  dominant <- max.col(theta, ties.method = "first")
  mix <- as.data.frame(unname(theta))
  names(mix) <- paste0("topic_", seq_len(model$k))
  scores <- data.frame(
    dominant_topic = dominant,
    dominant_prob = theta[cbind(seq_len(nrow(theta)), dominant)],
    mix, stringsAsFactors = FALSE
  )

  if (is.null(data)) {
    return(data.frame(id = model$doc_ids, row = model$doc_rows, scores,
                      stringsAsFactors = FALSE, row.names = NULL))
  }
  if (!is.data.frame(data) || nrow(data) != model$n_rows) {
    stop("`data` must be the same data frame (", model$n_rows, " rows) used to fit the model.",
         call. = FALSE)
  }
  full <- scores[rep(NA_integer_, nrow(data)), , drop = FALSE]
  full[model$doc_rows, ] <- scores
  rownames(full) <- NULL
  data <- data[, setdiff(names(data), names(full)), drop = FALSE]
  cbind(data, full)
}

#' One-row-per-topic summary
#'
#' @param model A model from [topic_model()].
#' @param n_terms Number of top terms to list for each topic.
#' @return A data frame with `topic`, `prevalence` (average share of an
#'   abstract), `n_docs` (abstracts whose dominant topic it is), `coherence`
#'   (UMass; closer to zero is better) and `top_terms`.
#' @export
topic_summary <- function(model, n_terms = 5) {
  .check_model(model)
  tt <- topic_terms(model, n_terms)
  top <- vapply(split(tt$term, tt$topic), paste, character(1), collapse = ", ")
  dominant <- max.col(model$theta, ties.method = "first")
  data.frame(
    topic = seq_len(model$k),
    prevalence = unname(colMeans(model$theta)),
    n_docs = tabulate(dominant, model$k),
    coherence = model$coherence,
    top_terms = unname(top[as.character(seq_len(model$k))]),
    stringsAsFactors = FALSE
  )
}

# ---------------------------------------------------------------------------
# Charts
# ---------------------------------------------------------------------------

#' Bar charts of each topic's top terms
#'
#' @param model A model from [topic_model()].
#' @param n Number of terms to show per topic.
#' @return A ggplot object (add layers or save it with [ggplot2::ggsave()]).
#' @export
plot_topic_terms <- function(model, n = 8) {
  .check_model(model)
  tt <- topic_terms(model, n)
  labs_t <- paste("Topic", seq_len(model$k))
  tt$topic_label <- factor(labs_t[tt$topic], levels = labs_t)
  keys <- paste(tt$topic, tt$term, sep = "___")
  tt$key <- factor(keys, levels = rev(keys))

  ggplot2::ggplot(tt, ggplot2::aes(x = .data$beta, y = .data$key, fill = .data$topic_label)) +
    ggplot2::geom_col(show.legend = FALSE) +
    ggplot2::facet_wrap(ggplot2::vars(.data$topic_label), scales = "free_y") +
    ggplot2::scale_y_discrete(labels = function(x) sub("^.*___", "", x)) +
    ggplot2::labs(title = "Top terms by topic", x = "Probability of the term within the topic",
                  y = NULL) +
    ggplot2::theme_minimal(base_size = 12) +
    ggplot2::theme(strip.text = ggplot2::element_text(hjust = 0, face = "bold"))
}

#' Bar chart of how common each topic is
#'
#' @param model A model from [topic_model()].
#' @param n_terms Number of top terms shown in each topic's label.
#' @return A ggplot object.
#' @export
plot_topic_prevalence <- function(model, n_terms = 4) {
  .check_model(model)
  s <- topic_summary(model, n_terms)
  lab <- paste0("Topic ", s$topic, ": ", s$top_terms)
  s$topic_label <- factor(lab, levels = rev(lab))
  s$pct <- sprintf("%.0f%%", 100 * s$prevalence)

  ggplot2::ggplot(s, ggplot2::aes(x = .data$prevalence, y = .data$topic_label)) +
    ggplot2::geom_col(fill = "#2b6cb0") +
    ggplot2::geom_text(ggplot2::aes(label = .data$pct), hjust = -0.15, size = 3.6) +
    ggplot2::scale_x_continuous(labels = function(x) paste0(round(100 * x), "%"),
                                expand = ggplot2::expansion(mult = c(0, 0.15))) +
    ggplot2::labs(title = "Topic prevalence", x = "Average share of an abstract", y = NULL) +
    ggplot2::theme_minimal(base_size = 12)
}

# ---------------------------------------------------------------------------
# Choosing the number of topics
# ---------------------------------------------------------------------------

#' Compare different numbers of topics
#'
#' Fits a model for each value of `k` and reports the average topic coherence
#' (UMass; closer to zero means a topic's top words more often appear together).
#' Look for the `k` where coherence is best or stops improving, then read the
#' topics to see whether they make sense. This is a guide, not a verdict.
#'
#' @param data A data frame, as for [topic_model()].
#' @param k Vector of topic counts to try.
#' @param ... Other arguments passed to [topic_model()] (for example `seed`,
#'   `n_iter`, `stopwords`).
#' @return A data frame with `k`, `mean_coherence` and `loglik`; it has a
#'   `plot()` method.
#' @examples
#' f <- system.file("extdata", "sample_abstracts.bib", package = "citelens")
#' topic_k_search(bib_to_df(f), k = 2:4, n_iter = 200, seed = 1)
#' @export
topic_k_search <- function(data, k = 2:8, ...) {
  rows <- lapply(k, function(kk) {
    m <- suppressMessages(topic_model(data, k = kk, ...))
    data.frame(k = kk, mean_coherence = mean(m$coherence),
               loglik = m$loglik$loglik[nrow(m$loglik)])
  })
  out <- do.call(rbind, rows)
  class(out) <- c("citelens_k_search", "data.frame")
  out
}

#' @export
plot.citelens_k_search <- function(x, ...) {
  ggplot2::ggplot(as.data.frame(x), ggplot2::aes(x = .data$k, y = .data$mean_coherence)) +
    ggplot2::geom_line(colour = "#2b6cb0") +
    ggplot2::geom_point(size = 2.5, colour = "#2b6cb0") +
    ggplot2::scale_x_continuous(breaks = x$k) +
    ggplot2::labs(title = "Topic coherence by number of topics",
                  x = "Number of topics (k)", y = "Mean coherence (closer to 0 is better)") +
    ggplot2::theme_minimal(base_size = 12)
}
