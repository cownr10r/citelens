ris <- system.file("extdata", "sample_refworks.ris", package = "biblio")
tag <- system.file("extdata", "sample_refworks.txt", package = "biblio")

test_that("RIS goes straight to an Excel file", {
  skip_if_not_installed("readxl")
  out <- tempfile(fileext = ".xlsx")
  expect_message(df <- refworks_to_xlsx(ris, out), "Wrote 4 entries")
  expect_equal(nrow(df), 4)
  x <- readxl::read_excel(out, col_types = "text")
  expect_equal(nrow(x), 4)
  expect_equal(x$bibkey[1], "tinto2006research")
  expect_equal(x$title[1], "Research and practice of student retention: What next?")
  expect_equal(x$bibtype, c("article", "book", "incollection", "phdthesis"))
})

test_that("RefWorks Tagged Format works too", {
  out <- tempfile(fileext = ".xlsx")
  suppressMessages(df <- refworks_to_xlsx(tag, out))
  expect_equal(nrow(df), 5)
  expect_true(file.exists(out))
})

test_that("the BibTeX file can be saved at the same time", {
  out <- tempfile(fileext = ".xlsx"); b <- tempfile(fileext = ".bib")
  suppressMessages(refworks_to_xlsx(ris, out, bib = b))
  expect_true(file.exists(b))
  expect_equal(nrow(bib_to_df(b)), 4)
})

test_that("messy characters still give an Excel file that opens", {
  skip_if_not_installed("readxl")
  f <- tempfile(fileext = ".txt")
  txt <- "RT Journal Article\nA1 Smith, Jo\nT1 It\x92s \x93fine\x94\x0b\nYR 2020\n"
  con <- file(f, "wb"); writeBin(charToRaw(txt), con); close(con)
  out <- tempfile(fileext = ".xlsx")
  suppressMessages(refworks_to_xlsx(f, out))
  x <- readxl::read_excel(out, col_types = "text")
  expect_equal(x$title, "It’s “fine”")
})

test_that("bad input is handled", {
  expect_error(refworks_to_xlsx("no_such_file.txt", tempfile(fileext = ".xlsx")), "not found")
  expect_error(refworks_to_xlsx(ris, file.path(tempdir(), "nope", "x.xlsx")), "Folder does not exist")
  empty <- tempfile(); writeLines("nothing here", empty)
  out <- tempfile(fileext = ".xlsx")
  expect_warning(refworks_to_xlsx(empty, out), "No records found")
  expect_false(file.exists(out))
})
