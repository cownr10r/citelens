sample_refs <- function() {
  bib_to_df(system.file("extdata", "sample_abstracts.bib", package = "biblio"))
}

test_that("topic_model recovers the three synthetic themes", {
  refs <- sample_refs()
  m <- suppressMessages(topic_model(refs, k = 3, n_iter = 300, seed = 1))
  expect_s3_class(m, "biblio_topics")
  expect_equal(dim(m$theta), c(30, 3))
  expect_equal(unname(rowSums(m$theta)), rep(1, 30), tolerance = 1e-8)
  expect_equal(unname(rowSums(m$phi)), rep(1, 3), tolerance = 1e-8)
  d <- topic_documents(m)
  # documents 1-10, 11-20, 21-30 come from different themes: each block should
  # be dominated by a single topic, and the three blocks by different topics
  major <- vapply(split(d$dominant_topic, rep(1:3, each = 10)),
                  function(x) as.integer(names(which.max(table(x)))), integer(1))
  expect_equal(length(unique(major)), 3)
  expect_gte(mean(d$dominant_topic == rep(major, each = 10)), 0.85)
})

test_that("fits are reproducible with a seed", {
  refs <- sample_refs()
  a <- suppressMessages(topic_model(refs, k = 3, n_iter = 50, seed = 7))
  b <- suppressMessages(topic_model(refs, k = 3, n_iter = 50, seed = 7))
  expect_equal(a$theta, b$theta)
})

test_that("result helpers return tidy data frames", {
  refs <- sample_refs()
  m <- suppressMessages(topic_model(refs, k = 3, n_iter = 100, seed = 2))
  tt <- topic_terms(m, 4)
  expect_equal(names(tt), c("topic", "rank", "term", "beta"))
  expect_equal(nrow(tt), 12)
  s <- topic_summary(m)
  expect_equal(nrow(s), 3)
  expect_equal(sum(s$n_docs), 30)
  expect_true(all(diff(s$prevalence) <= 1e-12))   # ordered by prevalence
  joined <- topic_documents(m, refs)
  expect_equal(nrow(joined), 30)
  expect_true(all(c("bibkey", "dominant_topic", "topic_1") %in% names(joined)))
  expect_output(print(m), "biblio topic model")
})

test_that("rows without an abstract get NA when joined back", {
  refs <- sample_refs()
  refs$abstract[c(3, 8)] <- NA
  m <- suppressMessages(topic_model(refs, k = 3, n_iter = 50, seed = 3))
  expect_equal(length(m$doc_ids), 28)
  j <- topic_documents(m, refs)
  expect_true(all(is.na(j$dominant_topic[c(3, 8)])))
  expect_false(anyNA(j$dominant_topic[-c(3, 8)]))
})

test_that("charts are ggplot objects", {
  refs <- sample_refs()
  m <- suppressMessages(topic_model(refs, k = 3, n_iter = 50, seed = 4))
  expect_s3_class(plot_topic_terms(m), "ggplot")
  expect_s3_class(plot_topic_prevalence(m), "ggplot")
  ks <- topic_k_search(refs, k = 2:3, n_iter = 50, seed = 4)
  expect_equal(ks$k, 2:3)
  expect_s3_class(plot(ks), "ggplot")
  tf <- tempfile(fileext = ".png")
  expect_no_error(suppressWarnings(ggplot2::ggsave(tf, plot_topic_terms(m), width = 6, height = 4)))
})

test_that("bad input gives clear errors", {
  refs <- sample_refs()
  expect_error(topic_model(refs, k = 1), "at least 2")
  expect_error(topic_model(refs, text = "nope"), "not found")
  expect_error(topic_model("x"), "data frame")
  expect_error(topic_terms(list()), "topic_model")
  expect_error(topic_model(refs[1, ], k = 2), "at least 2")
})

test_that("tokenizer handles accents, apostrophes and plurals", {
  tk <- biblio:::.tokenize("Students\u2019 \u00e9tude on the college\u2019s retention, 2020!", c("the", "on"), 3, TRUE)[[1]]
  expect_equal(tk, c("student", "\u00e9tude", "college", "retention"))
})
