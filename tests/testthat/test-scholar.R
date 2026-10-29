gs_page <- function() {
  el <- intToUtf8(0x2026)   # '...' as Scholar writes it
  paste0(
  '<html><body><div id="gs_res_ccl_mid">',
  # 1. full author, full venue, publisher
  '<div class="gs_r gs_or gs_scl" data-cid="cid1"><div class="gs_ri">',
  '<h3 class="gs_rt"><a id="a1" href="https://example.org/marzouk">Benchmarking <b>retention</b>, progression, and <b>graduation rates</b> in undergraduate <b>higher education</b> across different time windows</a></h3>',
  '<div class="gs_a"><a href="/citations?user=u1">OA Marzouk</a> - Cogent <b>Education</b>, 2025 - Taylor &amp; Francis</div>',
  '<div class="gs_rs">&hellip; first-year retention rate &hellip;</div>',
  '<div class="gs_fl gs_flb"><a class="gs_or_sav">Save</a> <a class="gs_or_cit">Cite</a> <a href="/scholar?cites=1">Cited by 53</a> <a>Related articles</a> <a>All 5 versions</a></div>',
  '</div></div>',
  # 2. Longden, accents-free
  '<div class="gs_r gs_or gs_scl" data-cid="cid2"><div class="gs_ri">',
  '<h3 class="gs_rt"><a href="https://example.org/longden">An institutional response to changing student expectations and their impact on <b>retention rates</b></a></h3>',
  '<div class="gs_a">B Longden - Journal of <b>higher education</b> policy and management, 2006 - Taylor &amp; Francis</div>',
  '<div class="gs_fl"><a>Cite</a> <a>Cited by 237</a> <a>All 6 versions</a></div>',
  '</div></div>',
  # 3. truncated authors and venue, web address as source
  '<div class="gs_r gs_or gs_scl" data-cid="cid3"><div class="gs_ri">',
  '<h3 class="gs_rt"><span class="gs_ct1">[PDF]</span> <a href="https://journals.sagepub.com/x">Predicting successful <b>college</b> experiences: Evidence from a <b>first year retention</b> program</a></h3>',
  '<div class="gs_a">K Noble, NT Flynn, <a href="/c?u=2">JD Lee</a>', el, ' - ', el, ' Student <b>Retention</b> ', el, ', 2007 - journals.sagepub.com</div>',
  '<div class="gs_fl"><a>Cite</a> <a>Cited by 240</a> <a>All 4 versions</a></div>',
  '</div></div>',
  # 4. book-like: no venue
  '<div class="gs_r gs_or gs_scl" data-cid="cid4"><div class="gs_ri">',
  '<h3 class="gs_rt"><span class="gs_ct1">[BOOK]</span><span class="gs_ct2">[B]</span> <a href="https://example.org/book">Leaving college</a></h3>',
  '<div class="gs_a">V Tinto - 1993 - University of Chicago Press</div>',
  '<div class="gs_fl"><a>Cite</a></div>',
  '</div></div>',
  # 5. citation only, no link
  '<div class="gs_r gs_or gs_scl" data-cid="cid5"><div class="gs_ri">',
  '<h3 class="gs_rt"><span class="gs_ctc"><span class="gs_ct1">[CITATION]</span></span> <span>Student attrition in higher education</span></h3>',
  '<div class="gs_a">J Bean - Research in Higher Education, 1980</div>',
  '</div></div>',
  '</div></body></html>')
}

test_that("results are parsed into a data frame", {
  r <- scholar_parse_html(gs_page())
  expect_equal(nrow(r), 5)
  expect_equal(r$title[1], "Benchmarking retention, progression, and graduation rates in undergraduate higher education across different time windows")
  expect_equal(r$authors[1], "Marzouk, O. A.")
  expect_equal(r$venue[1], "Cogent Education")
  expect_equal(r$year, c(2025L, 2006L, 2007L, 1993L, 1980L))
  expect_equal(r$publisher[1], "Taylor & Francis")
  expect_equal(r$url[1], "https://example.org/marzouk")
  expect_equal(r$cited_by, c(53L, 237L, 240L, NA, NA))
  expect_equal(r$versions, c(5L, 6L, 4L, NA, NA))
  expect_equal(r$cid[1:2], c("cid1", "cid2"))
  expect_match(r$snippet[1], "first-year retention rate")
})

test_that("truncation, web-address sources, books and citation-only rows are handled", {
  r <- scholar_parse_html(gs_page())
  expect_equal(r$authors_truncated, c(FALSE, FALSE, TRUE, FALSE, FALSE))
  expect_equal(r$author_list[[3]], c("Noble, K.", "Flynn, N. T.", "Lee, J. D."))
  expect_equal(r$venue[3], "Student Retention")
  expect_true(r$venue_truncated[3])
  expect_true(is.na(r$publisher[3]))                # journals.sagepub.com is not a publisher
  expect_equal(r$title[3], "Predicting successful college experiences: Evidence from a first year retention program")
  expect_true(is.na(r$venue[4]))                    # book: no venue
  expect_equal(r$publisher[4], "University of Chicago Press")
  expect_equal(r$title[4], "Leaving college")
  expect_equal(r$title[5], "Student attrition in higher education")
  expect_true(is.na(r$url[5]))
})

test_that("BibTeX output is built with the package's key and escaping rules", {
  msgs <- testthat::capture_messages(b <- scholar_html_to_bib(gs_page()))
  expect_length(b, 5)
  expect_match(b[1], "^@article\\{marzouk2025benchmarking,")
  expect_match(b[1], "author += \\{Marzouk, O\\. A\\.\\}")
  expect_match(b[1], "Taylor & Francis|Taylor \\\\& Francis")
  expect_match(b[3], "Incomplete: Google Scholar shortened the author list and venue name")
  expect_match(b[4], "^@misc\\{tinto1993leaving,")
  expect_false(grepl("Incomplete", b[1]))
  expect_match(paste(msgs, collapse = ""), "1 of 5")
  # round-trips through the data-frame reader
  f <- tempfile(fileext = ".bib")
  suppressMessages(scholar_html_to_bib(gs_page(), f))
  df <- bib_to_df(f)
  expect_equal(nrow(df), 5)
  expect_equal(df$year[1], "2025")
  expect_equal(df$journal[2], "Journal of higher education policy and management")
})

test_that("files, several pages and duplicates work", {
  f1 <- tempfile(fileext = ".html"); f2 <- tempfile(fileext = ".html")
  writeLines(gs_page(), f1, useBytes = TRUE); writeLines(gs_page(), f2, useBytes = TRUE)
  expect_equal(nrow(scholar_parse_html(f1)), 5)
  expect_equal(nrow(scholar_parse_html(c(f1, f2))), 10)
  expect_message(b <- scholar_html_to_bib(c(f1, f2)), "duplicate")
  expect_length(b, 5)
  expect_length(suppressMessages(scholar_html_to_bib(c(f1, f2), drop_duplicates = FALSE)), 10)
})

test_that("non-results pages and bad input give clear messages", {
  expect_warning(r <- scholar_parse_html("<html><body><p>hello</p></body></html>"), "No Google Scholar results")
  expect_equal(nrow(r), 0)
  expect_error(scholar_parse_html("<html><body>Our systems have detected unusual traffic</body></html>"), "robot check")
  expect_error(scholar_parse_html("/no/such/file.html"), "File not found")
})

test_that("a folder reads every .html file in it", {
  d <- tempfile("scholar"); dir.create(d)
  one <- sub('data-cid="cid1"', 'data-cid="cidA"', gs_page())
  writeLines(gs_page(), file.path(d, "page1.html"), useBytes = TRUE)
  writeLines(gs_page(), file.path(d, "page2.HTM"), useBytes = TRUE)
  writeLines("not a results page", file.path(d, "notes.txt"))            # ignored: not .html
  writeLines("<html><body><p>nothing</p></body></html>", file.path(d, "other.html"))
  expect_warning(r <- suppressMessages(scholar_parse_html(d)), "1 file\\(s\\) contained no Google Scholar results.*other\\.html")
  expect_equal(nrow(r), 10)
  expect_equal(sort(unique(r$source_file)), c("page1.html", "page2.HTM"))
  expect_message(suppressWarnings(scholar_parse_html(d)), "Read 3 file")
  # works for BibTeX too, with duplicates across pages removed
  b <- suppressWarnings(suppressMessages(scholar_html_to_bib(d)))
  expect_length(b, 5)
})

test_that("subfolders are only read when asked; empty folders error clearly", {
  d <- tempfile("scholar"); dir.create(file.path(d, "sub"), recursive = TRUE)
  writeLines(gs_page(), file.path(d, "top.html"), useBytes = TRUE)
  writeLines(gs_page(), file.path(d, "sub", "deep.html"), useBytes = TRUE)
  expect_equal(nrow(scholar_parse_html(d)), 5)
  expect_equal(nrow(suppressMessages(scholar_parse_html(d, recursive = TRUE))), 10)
  e <- tempfile("empty"); dir.create(e)
  expect_error(scholar_parse_html(e), "No .html files found")
})
