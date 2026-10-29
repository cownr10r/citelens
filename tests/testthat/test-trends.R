toy <- function() {
  data.frame(
    bibkey = paste0("k", 1:6),
    year = c("2018", "2018", "2019", "2019", "Spring 2020", NA),
    abstract = c(
      "retention and advising of students", "tuition and aid for students",
      "retention retention advising", "tuition aid debt",
      "retention advising mentoring", "retention advising"),
    stringsAsFactors = FALSE
  )
}

test_that("years are parsed from messy text", {
  expect_equal(citelens:::.parse_year(c("2019", "Spring 2020", "2018/03", NA, "n.d.")),
               c(2019L, 2020L, 2018L, NA, NA))
})

test_that("word_trends counts the share of abstracts per year", {
  expect_message(w <- word_trends(toy(), words = c("retention", "tuition")), "left out")
  r <- w[w$term == "retention", ]
  expect_equal(r$period, c(2018, 2019, 2020))
  expect_equal(r$n_docs, c(1, 1, 1))
  expect_equal(r$n_period, c(2, 2, 1))
  expect_equal(r$share, c(0.5, 0.5, 1))
  t <- w[w$term == "tuition", ]
  expect_equal(t$n_docs, c(1, 1, 0))            # zero rows are kept
  expect_equal(nrow(w), 6)
})

test_that("plurals are merged and default words are chosen automatically", {
  w <- suppressMessages(word_trends(toy(), words = "students"))
  expect_equal(w$n_docs, c(2, 0, 0))
  auto <- suppressMessages(word_trends(toy(), n = 2))
  expect_equal(length(unique(auto$term)), 2)
  expect_true(all(c("advising", "retention") %in% auto$term))   # the two most common words
})

test_that("bin groups years", {
  w <- suppressMessages(word_trends(toy(), words = "retention", bin = 2))
  expect_equal(w$period, c(2018, 2020))
  expect_equal(w$n_period, c(4, 1))
  expect_error(word_trends(toy(), bin = 0), "whole number")
})

test_that("topic_trends gives shares that add to 1 per period", {
  refs <- bib_to_df(system.file("extdata", "sample_abstracts.bib", package = "citelens"))
  m <- suppressMessages(topic_model(refs, k = 3, n_iter = 100, seed = 1))
  tt <- topic_trends(m, refs, bin = 5)
  expect_equal(names(tt), c("period", "topic", "label", "share", "n_period"))
  sums <- tapply(tt$share, tt$period, sum)
  expect_equal(as.numeric(sums), rep(1, length(sums)), tolerance = 1e-8)
  expect_equal(sum(unique(tt[, c("period", "n_period")])$n_period), 30)
  expect_error(topic_trends(m, refs[1:5, ]), "same data frame")
})

test_that("charts are ggplot objects and bad input errors clearly", {
  refs <- bib_to_df(system.file("extdata", "sample_abstracts.bib", package = "citelens"))
  w <- word_trends(refs, words = c("retention", "tuition"), bin = 5)
  expect_s3_class(plot_word_trends(w), "ggplot")
  m <- suppressMessages(topic_model(refs, k = 3, n_iter = 50, seed = 1))
  expect_s3_class(plot_topic_trends(topic_trends(m, refs)), "ggplot")
  tf <- tempfile(fileext = ".png")
  expect_no_error(suppressWarnings(ggplot2::ggsave(tf, plot_word_trends(w), width = 6, height = 4)))
  expect_error(word_trends("x"), "data frame")
  expect_error(word_trends(refs, year = "nope"), "not found")
  expect_error(plot_word_trends(data.frame(a = 1)), "word_trends")
  expect_error(plot_topic_trends(data.frame(a = 1)), "topic_trends")
})
