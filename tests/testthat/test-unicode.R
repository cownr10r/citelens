# Accented and typographic characters must pass through untouched and must not
# leak stray bytes into citation keys (a bug on macOS before ASCII-only handling).

write_utf8 <- function(lines, ext = ".txt") {
  f <- tempfile(fileext = ext)
  con <- file(f, "wb")
  writeBin(charToRaw(enc2utf8(paste(lines, collapse = "\n"))), con)
  close(con)
  f
}

test_that("accented names and titles keep their characters; keys are plain ASCII", {
  f <- write_utf8(c(
    "RT Journal Article",
    "A1 García, María",
    "T1 Éducation à l’université",
    "YR 2020"
  ))
  out <- suppressMessages(convert_refworks(f))
  expect_true(all(validUTF8(out)))
  expect_match(out, "^@article\\{garcia2020education,")
  expect_match(out, "García, María", fixed = TRUE)
  expect_match(out, "Éducation à l’université", fixed = TRUE)
})

test_that("keys fold accents and drop apostrophes", {
  f <- write_utf8(c(
    "RT Journal Article", "A1 Martínez-Ríos, José", "T1 It’s a test", "YR 2019",
    "RT Journal Article", "A1 Müller, Hans", "T1 Ñandú and friends", "YR 2018"
  ))
  out <- suppressMessages(convert_refworks(f))
  expect_true(all(validUTF8(out)))
  expect_match(out[1], "^@article\\{martinezrios2019its,")
  expect_match(out[2], "^@article\\{muller2018nandu,")
  keys <- sub("(?s)^@[a-z]+\\{([^,]*),.*$", "\\1", out, perl = TRUE)
  expect_equal(keys, c("martinezrios2019its", "muller2018nandu"))
  expect_true(all(grepl("^[a-z0-9]+$", keys)))   # keys are plain ASCII
})

test_that("bib_to_df cleaning does not damage multi-byte characters", {
  f <- write_utf8(c(
    "@article{k1,",
    "  title = {{Café à la   carte — résumé … señor}},",
    "  author = {García, María and Núñez, Ángel},",
    "  note = {café au lait}",
    "}"
  ), ".bib")
  df <- bib_to_df(f)
  expect_true(all(validUTF8(unlist(df))))
  # repeated ASCII spaces collapse, accents / dashes / ellipsis / no-break spaces survive
  expect_equal(df$title, "Café à la carte — résumé … señor")
  expect_equal(df$author, "García, María and Núñez, Ángel")
  expect_equal(df$note, "café au lait")
})

test_that("accents survive RIS -> bib -> data frame -> xlsx", {
  skip_if_not_installed("readxl")
  ris <- write_utf8(c(
    "TY  - JOUR", "AU  - García, María", "TI  - Educación y niñez",
    "JO  - Revista de Educación", "PY  - 2021", "ER  - "
  ), ".ris")
  out <- tempfile(fileext = ".xlsx")
  suppressMessages(df <- refworks_to_xlsx(ris, out))
  x <- readxl::read_excel(out, col_types = "text")
  expect_equal(x$bibkey, "garcia2021educacion")
  expect_equal(x$author, "García, María")
  expect_equal(x$title, "Educación y niñez")
  expect_equal(x$journal, "Revista de Educación")
})
