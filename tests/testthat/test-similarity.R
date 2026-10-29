sample_refs <- function() {
  bib_to_df(system.file("extdata", "sample_abstracts.bib", package = "biblio"))
}

toy <- function() {
  data.frame(
    bibkey = c("a", "b", "c", "d", "e"),
    title = c("A", "B", "C", "D", "E"),
    abstract = c(
      "tuition financial aid scholarship debt loan grant",
      "tuition financial aid scholarship debt loan grant",       # exact copy of a
      "advising mentoring retention persistence attrition cohort",
      "advising mentoring retention persistence dropout cohort",
      "dashboard metrics reporting analytics benchmarking survey"),
    stringsAsFactors = FALSE
  )
}

test_that("cosine similarity is symmetric, bounded, and 1 for identical text", {
  s <- suppressMessages(doc_similarity(toy(), min_doc_freq = 1))
  m <- s$sim
  expect_equal(dim(m), c(5, 5))
  expect_equal(m, t(m))
  expect_true(all(m >= 0 & m <= 1))
  expect_equal(unname(diag(m)), rep(1, 5), tolerance = 1e-8)
  expect_equal(m["a", "b"], 1, tolerance = 1e-8)
  expect_equal(m["a", "e"], 0)
  expect_gt(m["c", "d"], m["c", "a"])
})

test_that("C++ result matches a plain-R calculation", {
  s <- suppressMessages(doc_similarity(sample_refs()))
  x <- s$sim
  expect_equal(dim(x), c(30, 30))
  expect_true(all(x[!is.na(x)] <= 1 + 1e-12))
  # abstracts from the same synthetic theme are on average more alike than across themes
  theme <- rep(1:3, each = 10)
  same <- outer(theme, theme, "==") & upper.tri(x)
  diff <- outer(theme, theme, "!=") & upper.tri(x)
  expect_gt(mean(x[same]), mean(x[diff]))
})

test_that("similar_to and find_duplicates work", {
  d <- toy()
  s <- suppressMessages(doc_similarity(d, min_doc_freq = 1))
  top <- similar_to(s, "a", n = 2, data = d)
  expect_equal(top$id[1], "b")
  expect_equal(top$title[1], "B")
  expect_equal(similar_to(s, 1, n = 1)$id, "b")
  dup <- find_duplicates(s, cutoff = 0.99, data = d)
  expect_equal(nrow(dup), 1)
  expect_equal(c(dup$id_1, dup$id_2), c("a", "b"))
  expect_gte(nrow(find_duplicates(s, cutoff = 1, data = d)), 1)
  expect_error(similar_to(s, "zzz"), "not found")
  expect_error(find_duplicates(s, cutoff = 2), "between 0 and 1")
})

test_that("rows without usable text are left out and printing/plotting work", {
  d <- toy()
  d$abstract[5] <- NA
  s <- suppressMessages(doc_similarity(d, min_doc_freq = 1))
  expect_equal(length(s$doc_ids), 4)
  expect_output(print(s), "document similarity")
  expect_s3_class(plot_similarity(s), "ggplot")
  expect_s3_class(plot(s), "ggplot")
  tf <- tempfile(fileext = ".png")
  expect_no_error(suppressWarnings(ggplot2::ggsave(tf, plot_similarity(s), width = 5, height = 4)))
})

test_that("bad input gives clear errors", {
  expect_error(doc_similarity("x"), "data frame")
  expect_error(doc_similarity(toy(), text = "nope"), "not found")
  expect_error(similar_to(list(), "a"), "doc_similarity")
  expect_error(doc_similarity(toy()[1, ]), "at least 2")
})
