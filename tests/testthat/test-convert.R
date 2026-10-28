sample_file <- system.file("extdata", "sample_refworks.txt", package = "biblio")

test_that("all sample records are converted", {
  out <- convert_refworks(sample_file)
  expect_length(out, 5)
  expect_match(out[1], "^@article\\{tinto2006research,")
  expect_match(out[2], "^@book\\{")
  expect_match(out[3], "^@incollection\\{")
  expect_match(out[4], "^@phdthesis\\{")
})

test_that("pages, DOI and LaTeX escaping are handled", {
  out <- convert_refworks(sample_file)
  expect_match(out[1], "pages\\s+= \\{1--19\\}")
  expect_match(out[1], "doi\\s+= \\{10\\.2190/4NWK-STAC-2PLH-PJ3D\\}")
  expect_match(out[1], "Theory \\\\& Practice")
})

test_that("duplicate keys get a suffix", {
  out <- convert_refworks(sample_file)
  expect_match(out[5], "^@article\\{tinto2006researcha,")
})

test_that("writing to a file works", {
  tmp <- tempfile(fileext = ".bib")
  expect_message(convert_refworks(sample_file, tmp), "Converted 5")
  expect_true(any(grepl("^@article", readLines(tmp))))
})

test_that("bad input is handled", {
  expect_error(convert_refworks("no_such_file.txt"), "not found")
  empty <- tempfile(); writeLines("nothing here", empty)
  expect_warning(convert_refworks(empty), "No RefWorks records")
})
