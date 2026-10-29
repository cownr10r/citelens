# Mock OpenAlex: a fake downloader that looks like jsonlite::fromJSON(simplifyVector = FALSE) output.
idx <- function(txt) {
  w <- strsplit(txt, " ")[[1]]
  out <- list()
  for (i in seq_along(w)) out[[w[i]]] <- c(out[[w[i]]], i - 1L)
  out
}
work <- function(id, title, year, abstract = NULL) {
  list(id = paste0("https://openalex.org/", id), title = title, publication_year = year,
       abstract_inverted_index = if (is.null(abstract)) NULL else idx(abstract))
}
make_fetch <- function(log = NULL) {
  force(log)
  function(url) {
    if (!is.null(log)) log$urls <- c(log$urls, url)
    url <- tolower(url)
    if (grepl("/doi:10.1000%2Fabc|/doi:10.1000/abc", url)) {
      return(work("W1", "A study of doi lookup", 2020, "the abstract found by doi lookup"))
    }
    if (grepl("/doi:", url)) return(NULL)                       # unknown DOI -> request fails
    if (grepl("retention%20of%20first", url)) {
      return(list(results = list(
        work("W10", "Retention of first year students in college", 2010, "wrong paper on a similar topic"),
        work("W11", "Retention of first-generation students", 2018, "the right abstract about first generation retention"),
        work("W12", "Something unrelated entirely", 2018, "nope"))))
    }
    if (grepl("no%20abstract%20paper", url)) {
      return(list(results = list(work("W20", "No abstract paper", 2015, NULL))))
    }
    if (grepl("wrong%20year%20paper", url)) {
      return(list(results = list(work("W30", "Wrong year paper", 1990, "abstract from another decade"))))
    }
    if (grepl("a%20very%20long%20title%20that%20scholar", url)) {
      return(list(results = list(work("W40", "A very long title that Scholar cut short because it never ended", 2012,
                                      "abstract for the truncated title"))))
    }
    list(results = list())
  }
}

refs <- function() {
  data.frame(
    title = c("Retention of first-generation students", "No abstract paper", "Wrong year paper",
              "Nothing matches this at all", "Doesn't matter"),
    year = c(2018L, 2015L, 2005L, 2019L, 2020L),
    doi = c(NA, NA, NA, NA, "https://doi.org/10.1000/abc"),
    stringsAsFactors = FALSE
  )
}

test_that("abstracts are rebuilt in word order from OpenAlex's inverted index", {
  expect_equal(citelens:::.rebuild_abstract(idx("to be or not to be")), "to be or not to be")
  expect_equal(citelens:::.rebuild_abstract(list(world = 1L, hello = 0L)), "hello world")
  expect_true(is.na(citelens:::.rebuild_abstract(NULL)))
  expect_true(is.na(citelens:::.rebuild_abstract(list())))
})

test_that("title similarity and DOI cleaning behave", {
  expect_equal(citelens:::.title_similarity("Leaving College!", "leaving   college"), 1)
  expect_lt(citelens:::.title_similarity("Leaving college", "Completely different words"), 0.5)
  expect_equal(citelens:::.title_similarity("A very long title that goes on and on", "A very long title that goes on and on and then some more words", TRUE), 1)
  expect_equal(citelens:::.clean_doi("https://doi.org/10.1000/ABC"), "10.1000/ABC")
  expect_equal(citelens:::.clean_doi("doi:10.1000/x"), "10.1000/x")
  expect_true(is.na(citelens:::.clean_doi("not a doi")))
  expect_true(is.na(citelens:::.clean_doi(NA)))
})

test_that("fetch_abstracts fills matches and leaves uncertain ones NA", {
  msgs <- testthat::capture_messages(
    out <- fetch_abstracts(refs(), fetch = make_fetch(), delay = 0))
  expect_equal(out$abstract[1], "the right abstract about first generation retention")  # best of 3 candidates
  expect_equal(out$abstract_source[1], "openalex:W11")
  expect_gte(out$abstract_match[1], 0.85)
  expect_true(is.na(out$abstract[2]))      # found, but no abstract on file
  expect_true(is.na(out$abstract[3]))      # right title, wrong decade
  expect_true(is.na(out$abstract[4]))      # no match
  expect_equal(out$abstract[5], "the abstract found by doi lookup")   # by DOI
  expect_equal(out$abstract_match[5], 1)
  expect_match(paste(msgs, collapse = ""), "Found abstracts for 2 of 5")
})

test_that("existing abstracts are kept unless overwrite = TRUE", {
  d <- refs()
  d$abstract <- c("mine", NA, NA, NA, NA)
  out <- suppressMessages(fetch_abstracts(d, fetch = make_fetch(), delay = 0))
  expect_equal(out$abstract[1], "mine")
  out2 <- suppressMessages(fetch_abstracts(d, fetch = make_fetch(), delay = 0, overwrite = TRUE))
  expect_equal(out2$abstract[1], "the right abstract about first generation retention")
})

test_that("a title cut short by Scholar still matches on its beginning", {
  d <- data.frame(title = paste0("A very long title that Scholar", intToUtf8(0x2026)), year = 2012L,
                  stringsAsFactors = FALSE)
  out <- suppressMessages(fetch_abstracts(d, fetch = make_fetch(), delay = 0))
  expect_equal(out$abstract, "abstract for the truncated title")
})

test_that("the API key is only sent when supplied, is URL-encoded, and can come from the environment", {
  log <- new.env(); log$urls <- character()
  d <- refs()[1, ]
  withr::with_envvar(c(OPENALEX_API_KEY = ""), {
    suppressMessages(fetch_abstracts(d, fetch = make_fetch(log), delay = 0))
    expect_false(any(grepl("api_key", log$urls)))
    expect_true(all(grepl("^https://api\\.openalex\\.org/works\\?search=", log$urls)))
    expect_false(any(grepl(" ", log$urls)))
    log$urls <- character()
    suppressMessages(fetch_abstracts(d, api_key = "abc 123"[0], fetch = make_fetch(log), delay = 0))
    expect_false(any(grepl("api_key", log$urls)))
    log$urls <- character()
    suppressMessages(fetch_abstracts(d, api_key = "k+e/y", fetch = make_fetch(log), delay = 0))
    expect_true(all(grepl("api_key=k%2Be%2Fy", log$urls)))
  })
  withr::with_envvar(c(OPENALEX_API_KEY = "envkey"), {
    log$urls <- character()
    suppressMessages(fetch_abstracts(d, fetch = make_fetch(log), delay = 0))
    expect_true(all(grepl("api_key=envkey", log$urls)))
  })
  expect_error(fetch_abstracts(d, api_key = "two words"), "api_key")
})

test_that("a missing key is mentioned up front when many lookups are needed", {
  d <- data.frame(title = paste("paper number", 1:8), year = 2020L, stringsAsFactors = FALSE)
  msgs <- testthat::capture_messages(
    withr::with_envvar(c(OPENALEX_API_KEY = ""), fetch_abstracts(d, fetch = function(u) list(results = list()), delay = 0)))
  expect_match(paste(msgs, collapse = ""), "No OpenAlex API key")
  msgs2 <- testthat::capture_messages(fetch_abstracts(d, api_key = "k", fetch = function(u) list(results = list()), delay = 0))
  expect_false(grepl("No OpenAlex API key", paste(msgs2, collapse = "")))
})

test_that("quota / key / auth errors stop the run with a useful message and keep earlier results", {
  d <- refs()[c(1, 4, 4), ]
  d$title[2] <- "second paper"; d$title[3] <- "third paper"
  for (kind in c("quota", "key", "auth")) {
    calls <- 0
    f <- function(url) {
      calls <<- calls + 1
      if (calls == 1) make_fetch()(url) else citelens:::.http_error(kind, 429L)
    }
    expect_warning(out <- suppressMessages(fetch_abstracts(d, api_key = "k", fetch = f, delay = 0)),
                   switch(kind, quota = "allowance is used up", key = "requires an API key",
                          auth = "rejected the API key"))
    expect_equal(out$abstract[1], "the right abstract about first generation retention")
    expect_equal(calls, 2)                   # stopped at the first refusal, no more requests
  }
  w <- tryCatch(fetch_abstracts(d, fetch = function(u) citelens:::.http_error("quota", 429L), delay = 0),
                warning = function(w) conditionMessage(w))
  expect_match(w, "openalex.org/settings/api", fixed = TRUE)
  expect_match(w, "run fetch_abstracts\\(\\) again", perl = TRUE)
})

test_that("a missing DOI (not found) falls back to the title and is not counted as a failure", {
  d <- data.frame(title = "Retention of first-generation students", year = 2018L,
                  doi = "10.5555/unknown", stringsAsFactors = FALSE)
  f <- function(url) if (grepl("/doi:", url)) list() else make_fetch()(url)   # 404 -> list()
  out <- suppressMessages(fetch_abstracts(d, api_key = "k", fetch = f, delay = 0))
  expect_equal(out$abstract, "the right abstract about first generation retention")
})

test_that("repeated failures stop the run but keep earlier results", {
  calls <- 0
  flaky <- function(url) { calls <<- calls + 1; if (calls == 1) make_fetch()(url) else NULL }
  d <- refs()[c(1, 4, 4, 4, 4, 4, 4), ]
  expect_warning(out <- suppressMessages(fetch_abstracts(d, fetch = flaky, delay = 0)), "5 failed requests")
  expect_equal(out$abstract[1], "the right abstract about first generation retention")
  expect_lt(calls, nrow(d) + 1)
})

test_that("input checks, and nothing-to-do case", {
  expect_error(fetch_abstracts("x"), "data frame")
  expect_error(fetch_abstracts(data.frame(a = 1)), "needs a")
  d <- data.frame(title = "x", abstract = "have it", stringsAsFactors = FALSE)
  expect_message(out <- fetch_abstracts(d, fetch = function(u) stop("should not be called")), "Nothing to look up")
  expect_equal(out$abstract, "have it")
})

test_that("scholar_html_to_bib(abstracts = TRUE) puts the abstract into the entry", {
  page <- '<div class="gs_r" data-cid="c1"><div class="gs_ri">
    <h3 class="gs_rt"><a href="https://example.org/a">Retention of first-generation students</a></h3>
    <div class="gs_a">A Smith - Journal of Examples, 2018 - Example Press</div></div></div>'
  testthat::local_mocked_bindings(.get_json = make_fetch(), .package = "citelens")
  b <- suppressMessages(scholar_html_to_bib(page, abstracts = TRUE))
  expect_match(b, "abstract +=  *\\{the right abstract about first generation retention\\}")
  b0 <- suppressMessages(scholar_html_to_bib(page))
  expect_false(grepl("abstract", b0))
})

test_that("abstract_status explains why an abstract is missing", {
  d <- refs()
  d$title[4] <- "Retention of first-year students in college"   # candidates exist but none close enough
  mk <- make_fetch()
  f <- function(url) {
    if (grepl("first-year%20students%20in%20college", tolower(url))) {
      return(list(results = list(work("W50", "Something about dropping out", 2019, "x"))))
    }
    mk(url)
  }
  out <- suppressMessages(fetch_abstracts(d, fetch = f, delay = 0))
  expect_equal(out$abstract_status, c("found", "no abstract on file", "year differs", "title not matched", "found"))
  expect_equal(out$closest_title[4], "Something about dropping out")
  expect_lt(out$closest_score[4], 0.85)
  expect_true(is.na(out$closest_title[1]))
  # nothing matched at all
  d2 <- data.frame(title = "Zzz qqq", year = 2020L, stringsAsFactors = FALSE)
  expect_equal(suppressMessages(fetch_abstracts(d2, fetch = function(u) list(results = list()), delay = 0))$abstract_status, "no results")
  # a failed request
  d3 <- data.frame(title = "Zzz qqq", year = 2020L, stringsAsFactors = FALSE)
  expect_equal(suppressMessages(fetch_abstracts(d3, fetch = function(u) NULL, delay = 0))$abstract_status, "lookup failed")
  # a second pass keeps earlier statuses and only changes what it looks up again
  again <- suppressMessages(fetch_abstracts(out, fetch = make_fetch(), delay = 0))
  expect_equal(again$abstract_status[c(1, 5)], c("found", "found"))
})

test_that("max_year_diff accepts a title match whose year is further off, and closest_year is recorded", {
  d <- refs()[3, ]                                   # "Wrong year paper", year 2005; OpenAlex says 1990
  out <- suppressMessages(fetch_abstracts(d, fetch = make_fetch(), delay = 0))
  expect_equal(out$abstract_status, "year differs")
  expect_equal(out$closest_year, 1990L)
  expect_true(is.na(out$abstract))
  again <- suppressMessages(fetch_abstracts(out, max_year_diff = 20, fetch = make_fetch(), delay = 0))
  expect_equal(again$abstract, "abstract from another decade")
  expect_equal(again$abstract_status, "found")
  expect_true("max_year_diff" %in% names(formals(fetch_abstracts)))
})

test_that("a title cut short at the start, the end, or both still matches the full title", {
  el <- intToUtf8(0x2026)
  full <- "An Understanding of the Improved Grades, Retention and Graduation Rates of STEM Majors at the Academic Investment in Math and Science (AIMS) Program of Bowling Green State University (BGSU)"
  both <- paste0(el, " improved grades, retention and graduation rates of STEM majors at the Academic Investment in Math and Science (AIMS) Program of Bowling Green State University ", el)
  start <- paste0(el, " retention and graduation rates of STEM majors at the Academic Investment in Math and Science (AIMS) Program")
  expect_gte(citelens:::.title_similarity(both, full, TRUE), 0.95)
  expect_gte(citelens:::.title_similarity(start, full, TRUE), 0.9)
  expect_lt(citelens:::.title_similarity(both, full, FALSE), 0.85)       # without the flag it is a poor match
  expect_lt(citelens:::.title_similarity("improved grades in something else entirely here", full, TRUE), 0.7)
  f <- function(url) list(results = list(work("W77", full, 2012, "the BGSU abstract")))
  d <- data.frame(title = both, year = 2012L, stringsAsFactors = FALSE)
  out <- suppressMessages(fetch_abstracts(d, api_key = "k", fetch = f, delay = 0))
  expect_equal(out$abstract, "the BGSU abstract")
  expect_equal(out$abstract_status, "found")
})
