sample_bib <- system.file("extdata", "sample.bib", package = "biblio")

test_that("entries are parsed into rows with type and key", {
  df <- bib_to_df(sample_bib)
  expect_s3_class(df, "data.frame")
  expect_equal(nrow(df), 3)
  expect_equal(df$bibtype, c("article", "book", "inproceedings"))
  expect_equal(df$bibkey, c("tinto2006", "bailey2015", "nobody2020"))
})

test_that("macros, concatenation and months are expanded", {
  df <- bib_to_df(sample_bib)
  expect_equal(df$journal[1],
               "Journal of College Student Retention: Research, Theory & Practice")
  expect_equal(df$month[1], "January")
  expect_equal(df$year[1], "2006")
})

test_that("cleaning removes braces and collapses whitespace", {
  df <- bib_to_df(sample_bib)
  expect_equal(df$title[1], "Research and practice of student retention: What next?")
  expect_equal(df$title[2], "Redesigning America's Community Colleges")
  expect_equal(df$title[3], "A title with a nested brace group")
  expect_equal(df$abstract[1], "Line one continues on line two.")
  expect_equal(df$pages[1], "1--19")
})

test_that("clean = FALSE keeps the raw values", {
  df <- bib_to_df(sample_bib, clean = FALSE)
  expect_equal(df$title[1], "{Research and practice of student retention: What next?}")
  expect_match(df$journal[1], "\\\\&")
})

test_that("missing fields are NA and parentheses/quotes delimiters work", {
  df <- bib_to_df(sample_bib)
  expect_true(is.na(df$author[3]))
  expect_equal(df$author[2], "Bailey, Thomas R. and Jaggars, Shanna Smith")
  expect_equal(df$publisher[2], "Harvard University Press")
})

test_that("round trip: RefWorks -> .bib -> data frame", {
  rw  <- system.file("extdata", "sample_refworks.txt", package = "biblio")
  tmp <- tempfile(fileext = ".bib")
  suppressMessages(convert_refworks(rw, tmp))
  df <- bib_to_df(tmp)
  expect_equal(nrow(df), 5)
  expect_equal(df$bibkey[1], "tinto2006research")
  expect_equal(df$title[1], "Research and practice of student retention: What next?")
  expect_match(df$journal[1], "Theory & Practice", fixed = TRUE)
  expect_equal(df$doi[1], "10.2190/4NWK-STAC-2PLH-PJ3D")
})

test_that("bad input is handled", {
  expect_error(bib_to_df("no_such_file.bib"), "not found")
  empty <- tempfile(); writeLines("nothing here", empty)
  expect_warning(df <- bib_to_df(empty), "No BibTeX entries")
  expect_equal(nrow(df), 0)
})
