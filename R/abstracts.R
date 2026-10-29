# ---------------------------------------------------------------------------
# Look up abstracts in OpenAlex
# ---------------------------------------------------------------------------

.OPENALEX <- "https://api.openalex.org/works"
.OPENALEX_FIELDS <- "id,title,publication_year,doi,abstract_inverted_index"

.http_error <- function(kind, status = NA_integer_) {
  structure(list(kind = kind, status = status), class = "citelens_http_error")
}

# Download and parse JSON from OpenAlex.
# Returns the parsed list; list() when the item does not exist (404); or a
# "citelens_http_error" saying what went wrong: "quota" (429), "key" (409),
# "auth" (401/403), "server", "network" or "parse". Never contains the URL, so an
# API key cannot leak into messages.
.get_json <- function(url, tries = 3) {
  h <- curl::new_handle(timeout = 30)
  curl::handle_setheaders(h, `User-Agent` = "citelens-R-package", Accept = "application/json")
  wait <- 1
  for (attempt in seq_len(tries)) {
    r <- tryCatch(curl::curl_fetch_memory(url, h), error = function(e) NULL)
    if (is.null(r)) {
      if (attempt < tries) { Sys.sleep(wait); wait <- wait * 2; next }
      return(.http_error("network"))
    }
    st <- r$status_code
    if (st == 200) {
      txt <- rawToChar(r$content)
      Encoding(txt) <- "UTF-8"
      return(tryCatch(jsonlite::fromJSON(txt, simplifyVector = FALSE),
                      error = function(e) .http_error("parse", st)))
    }
    if (st == 404) return(list())
    if (st == 409) return(.http_error("key", st))
    if (st %in% c(401L, 403L)) return(.http_error("auth", st))
    if (st == 429) {
      hd <- curl::parse_headers_list(r$headers)
      left <- suppressWarnings(as.numeric(hd[["x-ratelimit-remaining"]]))
      if (!is.na(left) && left <= 0) return(.http_error("quota", st))   # daily credits used up
      if (attempt < tries) { Sys.sleep(wait); wait <- wait * 2; next }   # too fast: slow down
      return(.http_error("quota", st))
    }
    if (st >= 500 && attempt < tries) { Sys.sleep(wait); wait <- wait * 2; next }
    return(.http_error("server", st))
  }
}

# OpenAlex stores abstracts as {"word": [positions]}; put the words back in order.
.rebuild_abstract <- function(index) {
  if (is.null(index) || length(index) == 0) return(NA_character_)
  words <- rep(names(index), lengths(index))
  pos <- unlist(index, use.names = FALSE)
  if (length(pos) == 0) return(NA_character_)
  out <- paste(words[order(pos)], collapse = " ")
  Encoding(out) <- "UTF-8"
  out
}

.norm_title <- function(x) {
  x <- tolower(.squish(x))
  .squish(gsub("[^a-z0-9]+", " ", x))
}

# 0 (nothing alike) to 1 (same) from edit distance. When Scholar cut the title short at the
# start and/or end (an "..." on either side), the Scholar text only needs to match some
# stretch of the candidate title, so it is compared as a partial match.
.title_similarity <- function(query, candidate, truncated = FALSE) {
  q <- .norm_title(query)
  cand <- .norm_title(candidate)
  if (!nzchar(q) || !nzchar(cand)) return(0)
  if (truncated && nchar(q) >= 20 && nchar(q) < nchar(cand)) {
    d <- as.numeric(utils::adist(q, cand, partial = TRUE))
    return(1 - d / nchar(q))
  }
  d <- as.numeric(utils::adist(q, cand))
  1 - d / max(nchar(q), nchar(cand))
}

.works_url <- function(path_or_query, api_key) {
  sep <- if (grepl("?", path_or_query, fixed = TRUE)) "&" else "?"
  url <- paste0(path_or_query, sep, "select=", .OPENALEX_FIELDS)
  if (!is.null(api_key)) url <- paste0(url, "&api_key=", utils::URLencode(api_key, reserved = TRUE))
  url
}

.fatal_message <- function(kind) {
  how <- paste0("Get a free key at https://openalex.org/settings/api (100,000 credits a day) and pass it ",
                "as `api_key = `, or save it once with Sys.setenv(OPENALEX_API_KEY = \"your-key\"). ")
  switch(kind,
    quota = paste0("OpenAlex says the allowance is used up (HTTP 429): without an API key it is only ",
                   "about 100 credits a day. ", how,
                   "Results so far were kept; run fetch_abstracts() again on the result and it will ",
                   "only look up what is still missing."),
    key = paste0("OpenAlex now requires an API key (HTTP 409). ", how,
                 "Results so far were kept; run fetch_abstracts() again on the result and it will ",
                 "only look up what is still missing."),
    auth = paste0("OpenAlex rejected the API key (HTTP 401/403). Check that it was copied correctly ",
                  "from https://openalex.org/settings/api. Results so far were kept."),
    "Stopped.")
}

.clean_doi <- function(x) {
  x <- trimws(as.character(x))
  x <- sub("^(https?://(dx\\.)?doi\\.org/|doi:)", "", x, ignore.case = TRUE)
  if (is.na(x) || !grepl("^10\\.[0-9]{4,9}/", x)) NA_character_ else x
}

#' Look up abstracts for a table of references
#'
#' Fills in an `abstract` column by looking each reference up in
#' [OpenAlex](https://openalex.org), a free, open index of scholarly works with
#' an official API. Use it on the results of [scholar_parse_html()], whose
#' results list has titles but no abstracts, or on any data frame with titles
#' (and optionally DOIs).
#'
#' A reference is looked up by DOI when it has one, otherwise by title. A title
#' search is only accepted when the best match is very similar to your title
#' (see `min_match`) and the publication years agree to within a year; anything
#' less certain is left as `NA` instead of risking the wrong abstract. Many, but
#' not all, works in OpenAlex have an abstract, and coverage is best for recent
#' articles, so expect some `NA`s. Check a few matches by eye using
#' `abstract_match` and `abstract_source`.
#'
#' OpenAlex now requires an **API key**, which is free: create an account at
#' <https://openalex.org>, then copy the key from
#' <https://openalex.org/settings/api>. A free key allows 100,000 credits a day;
#' a title search costs 10 credits and a DOI lookup 1, so a few thousand
#' references fit in a day. Without a key you get only about 100 credits a day
#' (roughly ten lookups). Pass the key as `api_key`, or save it once with
#' `Sys.setenv(OPENALEX_API_KEY = "your-key")` (or in your `~/.Renviron` file) and
#' it is picked up automatically.
#'
#' Each title (or DOI) is sent to OpenAlex over the internet, along with your
#' key. Nothing is sent to Google. If OpenAlex says the allowance is used up,
#' the function stops and returns what it has; run it again on that result and
#' it looks up only the references still missing an abstract.
#'
#' @param data A data frame, for example from [scholar_parse_html()] or
#'   [bib_to_df()].
#' @param title,doi,year Names of the columns holding the title, DOI and year.
#'   Missing columns are skipped.
#' @param text Name of the abstract column to create or fill (default
#'   `"abstract"`).
#' @param api_key Your OpenAlex API key (see above). Defaults to the
#'   `OPENALEX_API_KEY` environment variable.
#' @param min_match Minimum title similarity (0 to 1) needed to accept a title
#'   search result.
#' @param max_year_diff Largest difference in publication year (your `year` vs
#'   OpenAlex's) accepted for a title match. The default of 1 allows for online-first
#'   dates; raise it (or use `Inf`) for references whose year differs because of
#'   re-editions, then check them with `closest_year`.
#' @param overwrite If `FALSE` (default), references that already have an
#'   abstract keep it.
#' @param delay Seconds to wait between requests.
#' @param fetch Function used to download JSON; for testing.
#' @return `data` with the abstract column filled in, plus:
#'   `abstract_source` (the OpenAlex id), `abstract_match` (title similarity,
#'   1 for a DOI match), `abstract_status` (why a reference has no abstract:
#'   `"found"`, `"no abstract on file"`, `"title not matched"`, `"year differs"`,
#'   `"no results"` or `"lookup failed"`), and `closest_title` / `closest_score` /
#'   `closest_year` (the nearest OpenAlex title, for references that were not
#'   matched, so you can see whether `min_match` or `max_year_diff` would help).
#' @examples
#' \dontrun{
#' res <- scholar_parse_html("~/Downloads/scholar_page1.html")
#' res <- fetch_abstracts(res, api_key = "your-openalex-key")
#' topic_model(res, k = 4, id = "title")
#' }
#' @export
fetch_abstracts <- function(data, title = "title", doi = "doi", year = "year",
                            text = "abstract", api_key = Sys.getenv("OPENALEX_API_KEY"),
                            min_match = 0.85, max_year_diff = 1,
                            overwrite = FALSE, delay = 0.1, fetch = .get_json) {
  if (!is.data.frame(data)) stop("`data` must be a data frame.", call. = FALSE)
  if (!title %in% names(data) && !doi %in% names(data)) {
    stop("`data` needs a '", title, "' or '", doi, "' column.", call. = FALSE)
  }
  if (is.null(api_key) || length(api_key) == 0 || (length(api_key) == 1 && is.na(api_key)) ||
      (length(api_key) == 1 && !nzchar(trimws(api_key)))) {
    api_key <- NULL
  } else if (!is.character(api_key) || length(api_key) != 1 || grepl("[[:space:]]", trimws(api_key))) {
    stop("`api_key` must be a single string (copy it from https://openalex.org/settings/api).",
         call. = FALSE)
  } else {
    api_key <- trimws(api_key)
  }
  n <- nrow(data)
  get_col <- function(nm) if (nm %in% names(data)) as.character(data[[nm]]) else rep(NA_character_, n)
  ttl <- get_col(title); dois <- vapply(get_col(doi), .clean_doi, "", USE.NAMES = FALSE)
  yrs <- suppressWarnings(as.integer(sub("^.*?([0-9]{4}).*$", "\\1", get_col(year), perl = TRUE)))
  yrs[!grepl("[0-9]{4}", get_col(year))] <- NA_integer_

  have <- if (text %in% names(data)) as.character(data[[text]]) else rep(NA_character_, n)
  out_abs <- have
  src <- if ("abstract_source" %in% names(data)) as.character(data$abstract_source) else rep(NA_character_, n)
  mat <- if ("abstract_match" %in% names(data)) as.numeric(data$abstract_match) else rep(NA_real_, n)
  stat <- if ("abstract_status" %in% names(data)) as.character(data$abstract_status) else rep(NA_character_, n)
  close_t <- if ("closest_title" %in% names(data)) as.character(data$closest_title) else rep(NA_character_, n)
  close_s <- if ("closest_score" %in% names(data)) as.numeric(data$closest_score) else rep(NA_real_, n)
  close_y <- if ("closest_year" %in% names(data)) as.integer(data$closest_year) else rep(NA_integer_, n)
  finish <- function(d) {
    stat[!is.na(out_abs) & nzchar(trimws(out_abs)) & is.na(stat)] <- "found"
    d[[text]] <- out_abs
    d$abstract_source <- src
    d$abstract_match <- mat
    d$abstract_status <- stat
    d$closest_title <- close_t
    d$closest_score <- close_s
    d$closest_year <- close_y
    d
  }

  todo <- which(overwrite | is.na(have) | !nzchar(trimws(have)))
  todo <- todo[!is.na(dois[todo]) | (!is.na(ttl[todo]) & nzchar(trimws(ttl[todo])))]
  if (length(todo) == 0) {
    message("Nothing to look up.")
    return(finish(data))
  }

  if (is.null(api_key) && length(todo) > 5) {
    message("No OpenAlex API key supplied. OpenAlex's allowance without a key is tiny (about ",
            "100 credits a day; a title lookup costs 10). Get a free key at ",
            "https://openalex.org/settings/api and pass it as `api_key = `.")
  }

  found <- 0L; failures <- 0L; fatal <- NULL; last_failed <- FALSE
  req <- function(url) {
    r <- fetch(url)
    last_failed <<- FALSE
    if (is.null(r) || inherits(r, "citelens_http_error")) {
      last_failed <<- TRUE
      kind <- if (is.null(r)) "network" else r$kind
      if (kind %in% c("quota", "key", "auth")) fatal <<- kind else failures <<- failures + 1L
      return(NULL)
    }
    failures <<- 0L
    r
  }
  for (k in seq_along(todo)) {
    i <- todo[k]
    work <- NULL; score <- NA_real_
    status <- "no results"; closest <- NA_character_; closest_sc <- NA_real_; closest_yr <- NA_integer_
    if (!is.na(dois[i])) {
      res <- req(.works_url(paste0(.OPENALEX, "/doi:", utils::URLencode(dois[i], reserved = FALSE)), api_key))
      if (!is.null(fatal)) break
      if (!is.null(res) && !is.null(res$id)) { work <- res; score <- 1 }
    }
    if (is.null(work) && !is.na(ttl[i]) && nzchar(trimws(ttl[i]))) {
      t0 <- .squish(ttl[i])
      truncated <- grepl(paste0("^[", .ELLIPSIS, "]|^\\.\\.\\.|[", .ELLIPSIS, "]$|\\.\\.\\.$"), t0)
      q <- .squish(gsub(paste0("^[", .ELLIPSIS, ". ]+|[", .ELLIPSIS, ". ]+$"), "", t0))
      url <- .works_url(paste0(.OPENALEX, "?search=", utils::URLencode(q, reserved = TRUE),
                               "&per-page=5"), api_key)
      res <- req(url)
      if (!is.null(fatal)) break
      if (last_failed) status <- "lookup failed"
      if (!is.null(res)) {
        cands <- res$results
        if (length(cands) > 0) {
          raw <- vapply(cands, function(w) .title_similarity(q, if (is.null(w$title)) "" else w$title, truncated), numeric(1))
          ok <- vapply(cands, function(w) {
            yw <- w$publication_year
            is.na(yrs[i]) || is.null(yw) || abs(as.integer(yw) - yrs[i]) <= max_year_diff
          }, logical(1))
          sc <- raw
          sc[!ok] <- -1
          best <- which.max(sc)
          if (sc[best] >= min_match) {
            work <- cands[[best]]; score <- sc[best]
          } else {
            top <- which.max(raw)
            status <- if (raw[top] >= min_match) "year differs" else "title not matched"
            closest <- if (is.null(cands[[top]]$title)) NA_character_ else cands[[top]]$title
            closest_sc <- raw[top]
            closest_yr <- if (is.null(cands[[top]]$publication_year)) NA_integer_ else as.integer(cands[[top]]$publication_year)
          }
        }
      }
    }
    if (failures >= 5) {
      warning("Stopped after 5 failed requests in a row (a network or OpenAlex server problem). ",
              "Check your internet connection and try again. Results so far were kept.", call. = FALSE)
      break
    }
    if (!is.null(work)) {
      ab <- .rebuild_abstract(work$abstract_inverted_index)
      src[i] <- sub("^https?://openalex.org/", "openalex:", work$id)
      mat[i] <- score
      if (!is.na(ab)) {
        out_abs[i] <- ab; found <- found + 1L; status <- "found"
      } else {
        status <- "no abstract on file"
      }
    }
    stat[i] <- status; close_t[i] <- closest; close_s[i] <- closest_sc; close_y[i] <- closest_yr
    if (k %% 10 == 0) message("  looked up ", k, " of ", length(todo))
    if (delay > 0 && k < length(todo)) Sys.sleep(delay)
  }
  if (!is.null(fatal)) warning(.fatal_message(fatal), call. = FALSE)
  message("Found abstracts for ", found, " of ", length(todo), " reference(s) looked up.")
  finish(data)
}
