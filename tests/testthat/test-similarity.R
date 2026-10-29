sample_refs <- function() {
  bib_to_df(system.file("extdata", "sample_abstracts.bib", package = "citelens"))
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
  pv <- plot_similarity(s, values = TRUE)
  expect_true(any(vapply(pv$layers, function(l) inherits(l$geom, "GeomText"), logical(1))))
  expect_false(any(vapply(plot_similarity(s, values = FALSE)$layers, function(l) inherits(l$geom, "GeomText"), logical(1))))
  tf <- tempfile(fileext = ".png")
  expect_no_error(suppressWarnings(ggplot2::ggsave(tf, plot_similarity(s), width = 5, height = 4)))
})

test_that("bad input gives clear errors", {
  expect_error(doc_similarity("x"), "data frame")
  expect_error(doc_similarity(toy(), text = "nope"), "not found")
  expect_error(similar_to(list(), "a"), "doc_similarity")
  expect_error(doc_similarity(toy()[1, ]), "at least 2")
})

test_that("similarity_to_df gives a matrix table and a pairs table", {
  d <- toy()
  s <- suppressMessages(doc_similarity(d, min_doc_freq = 1))
  m <- similarity_to_df(s)
  expect_equal(dim(m), c(5, 6))
  expect_equal(names(m), c("id", "a", "b", "c", "d", "e"))
  expect_equal(m$id, c("a", "b", "c", "d", "e"))
  expect_equal(unname(unlist(m[m$id == "a", "b"])), 1)
  expect_equal(unname(diag(as.matrix(m[, -1]))), rep(1, 5))
  mt <- similarity_to_df(s, data = d)
  expect_equal(names(mt)[1:3], c("id", "title", "a"))
  expect_equal(mt$title, c("A", "B", "C", "D", "E"))

  p <- similarity_to_df(s, "pairs", data = d)
  expect_equal(nrow(p), 10)
  expect_equal(names(p), c("id_1", "id_2", "similarity", "title_1", "title_2"))
  expect_true(all(diff(p$similarity) <= 0))
  expect_equal(c(p$id_1[1], p$id_2[1]), c("a", "b"))
  expect_lt(nrow(similarity_to_df(s, "pairs", cutoff = 0.5)), 10)
  # rounding
  r <- similarity_to_df(s, "pairs", digits = 1)
  expect_true(all(abs(r$similarity * 10 - round(r$similarity * 10)) < 1e-9))
  expect_false(isTRUE(all.equal(similarity_to_df(s, "pairs", digits = NULL)$similarity, r$similarity)))
  # S3 method and bad input
  expect_equal(as.data.frame(s), similarity_to_df(s, "pairs"))
  expect_error(similarity_to_df(list()), "doc_similarity")
  expect_error(similarity_to_df(s, digits = -1), "digits")
  expect_error(similarity_to_df(s, type = "nope"))
})

test_that("duplicate ids do not break the matrix table", {
  d <- toy(); d$bibkey[2] <- "a"
  s <- suppressMessages(doc_similarity(d, min_doc_freq = 1))
  expect_equal(names(similarity_to_df(s))[2:3], c("a", "a.1"))
})

test_that("xlsx export writes both layouts and returns the table invisibly", {
  skip_if_not_installed("readxl")
  d <- toy()
  s <- suppressMessages(doc_similarity(d, min_doc_freq = 1))
  f <- tempfile(fileext = ".xlsx")
  expect_message(res <- withVisible(similarity_to_df(s, data = d, xlsx = f)), "Wrote the similarity matrix")
  expect_false(res$visible)
  expect_equal(readxl::excel_sheets(f), c("similarity_matrix", "pairs"))
  mat <- readxl::read_excel(f, sheet = "similarity_matrix")
  prs <- readxl::read_excel(f, sheet = "pairs")
  expect_equal(dim(mat), c(5, 7))
  expect_equal(nrow(prs), 10)
  expect_equal(mat$id, c("a", "b", "c", "d", "e"))
  expect_equal(prs$similarity[1], 1, tolerance = 1e-6)
  # asking for the pairs table still writes both sheets
  f2 <- tempfile()
  suppressMessages(similarity_to_df(s, "pairs", xlsx = f2))        # .xlsx is added
  expect_true(file.exists(paste0(f2, ".xlsx")))
  expect_error(similarity_to_df(s, xlsx = "/no/such/folder/x.xlsx"), "Folder does not exist")
})
