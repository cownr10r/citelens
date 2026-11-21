sample_papers <- function() {
  read.csv(system.file("extdata", "sample_authors.csv", package = "citelens"),
           stringsAsFactors = FALSE)
}

test_that("find_duplicate_papers flags the re-listed paper and keeps the most cited", {
  d <- find_duplicate_papers(sample_papers())
  expect_s3_class(d, "citelens_duplicates")
  expect_equal(nrow(d), 2)
  expect_equal(sort(d$row), c(1, 7))
  expect_equal(d$row[d$keep], 1)                 # 120 citations beats 1
  expect_equal(length(unique(d$group)), 1)
})

test_that("a same-title paper by different authors is not merged", {
  p <- sample_papers()
  expect_false(18 %in% find_duplicate_papers(p)$row)
  d <- find_duplicate_papers(p, require_author_overlap = FALSE)
  expect_true(18 %in% d$row)
  expect_equal(nrow(d), 3)
})

test_that("exact and near methods agree on clean duplicates", {
  p <- sample_papers()
  expect_equal(sort(find_duplicate_papers(p, method = "exact")$row), c(1, 7))
  p$title[7] <- "Persistence gaps in first year cohort"   # one word changed a little
  expect_false(7 %in% find_duplicate_papers(p, method = "exact")$row)
  expect_true(7 %in% find_duplicate_papers(p, method = "near", max_dist = 0.1)$row)
})

test_that("accents, case and punctuation are ignored", {
  p <- data.frame(title = c("Café culture: a study!", "cafe culture a study"),
                  authors = c("Ng, A. and Roe, B.", "Roe, B."),
                  year = c(2020, 2021), cited_by = c(5, 2), stringsAsFactors = FALSE)
  expect_equal(nrow(find_duplicate_papers(p, method = "exact")), 2)
})

test_that("the author column can be named author, as bib_to_df() does", {
  p <- sample_papers()
  names(p)[names(p) == "authors"] <- "author"
  expect_equal(sort(find_duplicate_papers(p)$row), c(1, 7))
})

test_that("missing titles and optional columns are handled", {
  p <- sample_papers()
  p$title[3] <- NA
  p$year <- NULL
  p$cited_by <- NULL
  d <- find_duplicate_papers(p)
  expect_equal(sort(d$row), c(1, 7))
  expect_equal(d$row[d$keep], 1)                 # tie on citations -> first row
  none <- find_duplicate_papers(sample_papers()[8:12, ])
  expect_equal(nrow(none), 0)
  expect_output(print(none), "No duplicate papers")
})

test_that("print shows what would be kept and dropped", {
  expect_output(print(find_duplicate_papers(sample_papers())), "KEEP row 1")
})

test_that("dedupe_papers drops the less-cited copy and records it", {
  p <- sample_papers()
  expect_message(out <- dedupe_papers(p), "Dropped 1 duplicate")
  expect_equal(nrow(out), nrow(p) - 1)
  expect_false("Persistence gaps in first-year cohorts." %in% out$title)
  expect_equal(attr(out, "dropped")$row, 7)
  expect_message(out2 <- dedupe_papers(p, drop_rows = 18), "Dropped 1")
  expect_equal(nrow(out2), nrow(p) - 1)
  expect_error(dedupe_papers(p, drop_rows = 99), "row numbers")
})

test_that("input problems give clear errors", {
  p <- sample_papers()
  expect_error(find_duplicate_papers(1:3), "data frame")
  expect_error(find_duplicate_papers(p, title = "nope"), "not found")
  expect_error(find_duplicate_papers(p, max_dist = 2), "max_dist")
})
