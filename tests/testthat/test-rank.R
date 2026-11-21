sample_papers <- function() {
  read.csv(system.file("extdata", "sample_authors.csv", package = "citelens"),
           stringsAsFactors = FALSE)
}

rank_quiet <- function(...) suppressMessages(citation_rank(...))

test_that("the citation indices are computed correctly", {
  ix <- citelens:::.cite_index(c(10, 8, 5, 4, 3))
  expect_equal(ix$h_index, 4)
  expect_equal(ix$g_index, 5)
  expect_equal(ix$i10_index, 1)
  expect_equal(ix$total, 30)
  expect_equal(ix$median, 5)
  ix0 <- citelens:::.cite_index(c(0, 0, NA))
  expect_equal(c(ix0$h_index, ix0$g_index, ix0$uncited), c(0, 0, 2))
  expect_equal(citelens:::.cite_index(numeric())$n_papers, 0)
})

test_that("paper ranking works and drops the duplicate listing", {
  expect_message(res <- citation_rank(sample_papers(), current_year = 2024),
                 "Dropped 1 duplicate")
  expect_s3_class(res, "citelens_rank")
  expect_equal(res$index$n_papers, 17)
  expect_equal(res$index$total, 818)
  expect_equal(res$index$h_index, 12)
  expect_equal(res$index$i10_index, 13)
  r <- res$ranked
  expect_equal(r$rank[1], 1)
  expect_match(r$title[1], "Transfer pathways")
  expect_equal(r$citations[1], 200)
  expect_equal(r$age[1], 8)                       # 2017 -> 2024
  expect_equal(r$cites_per_year[1], 25)
  expect_equal(r$percentile[1], round(100 * 16 / 17, 1))
  expect_equal(r$cum_share[nrow(r)], 1)
  expect_equal(nrow(res$duplicates), 1)
})

test_that("dedupe = FALSE counts every row", {
  res <- rank_quiet(sample_papers(), dedupe = FALSE)
  expect_equal(res$index$n_papers, 18)
  expect_null(res$duplicates)
})

test_that("ties share a rank", {
  d <- data.frame(title = c("A one", "B two", "C three"), cited_by = c(5, 5, 1),
                  stringsAsFactors = FALSE)
  res <- rank_quiet(d, dedupe = FALSE)
  expect_equal(res$ranked$rank, c(1, 1, 3))
})

test_that("author ranking credits every author with the full count", {
  res <- rank_quiet(sample_papers(), by = "author")
  a <- res$ranked
  expect_equal(a$author[1], "Elm, E.")           # 200 + 95 + 30
  expect_equal(a$total_citations[1], 325)
  expect_equal(a$n_papers[1], 3)
  expect_equal(a$rank[1], 1)
  b <- a[a$author == "Birch, B.", ]              # 120 + 85 + 60 + 25 + 10
  expect_equal(b$total_citations, 300)
  expect_equal(b$n_papers, 5)
  expect_equal(b$rank, 2)
  expect_equal(nrow(a), 21)
  expect_equal(rank_quiet(sample_papers(), by = "author", top_n = 3)$ranked |> nrow(), 3)
  expect_equal(rank_quiet(sample_papers(), by = "author", top_n = 3)$n_total, 21)
})

test_that("the author column can be named author", {
  p <- sample_papers()
  names(p)[names(p) == "authors"] <- "author"
  expect_equal(rank_quiet(p, by = "author")$ranked$author[1], "Elm, E.")
})

test_that("venue ranking works and needs a venue column", {
  p <- sample_papers()
  expect_error(rank_quiet(p, by = "venue"), "venue")
  p$venue <- rep(c("Journal A", "Journal B", NA), length.out = nrow(p))
  v <- rank_quiet(p, by = "venue")$ranked
  expect_true(all(c("venue", "h_index") %in% names(v)))
  expect_false(any(is.na(v$venue)))
})

test_that("missing counts, untitled rows and bad input are handled", {
  d <- data.frame(title = c("A one", NA, "C three", "D four"),
                  cited_by = c(5, 9, NA, 2), stringsAsFactors = FALSE)
  expect_message(res <- citation_rank(d, dedupe = FALSE), "no title")
  expect_equal(res$index$n_papers, 3)
  expect_equal(res$index$uncited, 1)
  res2 <- rank_quiet(d, dedupe = FALSE, na_cites_as_zero = FALSE)
  expect_equal(res2$index$n_papers, 2)
  expect_error(citation_rank(1:3), "data frame")
  expect_error(citation_rank(d, cites = "nope"), "not found")
  expect_error(citation_rank(d, top_n = 0), "top_n")
  expect_error(rank_quiet(data.frame(title = NA, cited_by = 1), dedupe = FALSE),
               "No rows left")
})

test_that("print gives the index and a top table", {
  expect_output(print(rank_quiet(sample_papers())), "Citation index")
})
