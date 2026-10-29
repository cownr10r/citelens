# ---------------------------------------------------------------------------
# Google Scholar results page -> data frame / BibTeX
# ---------------------------------------------------------------------------

# Built with intToUtf8(): a "\u...." escape in source becomes literal text in a C locale.
.ELLIPSIS <- intToUtf8(0x2026)
.NBSP <- intToUtf8(0xA0)

# Read one saved page (file path) or a string of HTML into an xml2 document.
.read_scholar_page <- function(x) {
  if (length(x) != 1 || is.na(x) || !nzchar(x)) {
    stop("`input` must be a file path or HTML text.", call. = FALSE)
  }
  if (!grepl("<", x, fixed = TRUE) && !file.exists(x)) {
    stop("File not found: ", x, call. = FALSE)
  }
  if (!grepl("<", x, fixed = TRUE)) {
    raw <- readBin(x, "raw", file.info(x)$size)
    return(xml2::read_html(raw, encoding = "UTF-8"))
  }
  xml2::read_html(x)
}

.squish <- function(x) trimws(gsub(paste0("[[:space:]", .NBSP, "]+"), " ", x))

# "OA Marzouk" -> "Marzouk, O. A.";  "Vincent Tinto" -> "Tinto, Vincent"
.scholar_author <- function(a) {
  a <- .squish(a)
  tok <- strsplit(a, " ", fixed = TRUE)[[1]]
  if (length(tok) < 2) return(a)
  if (grepl("^[A-Z]{1,3}$", tok[1])) {
    init <- paste0(strsplit(tok[1], "")[[1]], ".", collapse = " ")
    paste0(paste(tok[-1], collapse = " "), ", ", init)
  } else {
    paste0(tok[length(tok)], ", ", paste(tok[-length(tok)], collapse = " "))
  }
}

# Split the grey line "OA Marzouk - Cogent Education, 2025 - Taylor & Francis".
.parse_gs_a <- function(txt) {
  s <- .squish(txt)
  parts <- strsplit(s, " - ", fixed = TRUE)[[1]]
  authors <- if (length(parts) >= 1) parts[1] else NA_character_
  venue_year <- NA_character_
  source <- NA_character_
  if (length(parts) == 2) {
    venue_year <- parts[2]
  } else if (length(parts) >= 3) {
    venue_year <- paste(parts[2:(length(parts) - 1)], collapse = " - ")
    source <- parts[length(parts)]
  }

  year <- NA_integer_
  venue <- NA_character_
  if (!is.na(venue_year)) {
    m <- regmatches(venue_year, regexec("^(.*?)[, ]*\\b((?:1[5-9]|20)[0-9]{2})$", venue_year, perl = TRUE))[[1]]
    if (length(m) == 3) {
      year <- as.integer(m[3])
      venue <- m[2]
    } else {
      venue <- venue_year
    }
  }
  v_trunc <- !is.na(venue) && grepl(paste0("^", .ELLIPSIS, "|", .ELLIPSIS, "$|^\\.\\.\\.|\\.\\.\\.$"), .squish(venue))
  if (!is.na(venue)) {
    venue <- .squish(gsub(paste0("^[ ,", .ELLIPSIS, ".]+|[ ,", .ELLIPSIS, ".]+$"), "", venue))
    if (!nzchar(venue)) venue <- NA_character_
  }

  a_trunc <- !is.na(authors) && grepl(.ELLIPSIS, authors, fixed = TRUE)
  if (!is.na(authors)) {
    authors <- gsub(.ELLIPSIS, "", authors, fixed = TRUE)
    authors <- trimws(strsplit(authors, ",", fixed = TRUE)[[1]])
    authors <- authors[nzchar(authors)]
  } else {
    authors <- character(0)
  }

  # a "source" that looks like a web address is not a publisher
  if (!is.na(source) && grepl("^[^ ]+\\.[a-z]{2,}(/.*)?$", source)) source <- NA_character_

  list(authors = authors, authors_truncated = a_trunc, venue = venue,
       venue_truncated = isTRUE(v_trunc), year = year, publisher = source)
}

#' Parse a saved Google Scholar results page
#'
#' Reads a Google Scholar search-results page that you saved from your browser
#' and pulls out what the results list shows for each hit: title, authors,
#' venue, year, publisher, link, snippet, citation count and number of versions.
#' It parses the page's HTML/XML with the xml2 package; it does **not** contact
#' Google Scholar, which blocks automated requests and whose terms do not allow
#' them.
#'
#' To save a page in Chrome or Safari: open the results, then File > Save Page
#' As (choose "Webpage, HTML Only" or "Page Source"). Save each results page you
#' want as its own file.
#'
#' The results list shortens long author lists and venue names with "...", and
#' does not show volume, pages or DOI. Entries affected are flagged in
#' `authors_truncated` and `venue_truncated`. For complete records, use Scholar's
#' **Cite > BibTeX** (or **My library > Export**) instead.
#'
#' @param input One or more paths to saved `.html` files, **a folder** (every
#'   `.html` / `.htm` file in it is read), or a string of HTML text. Results
#'   from several pages are combined.
#' @param recursive If `input` is a folder, also read files in its subfolders.
#' @return A data frame with one row per result: `source_file` (the file it came
#'   from), `title`, `authors` (as shown,
#'   with initials), `author_list` (a list column of names), `authors_truncated`,
#'   `venue`, `venue_truncated`, `year`, `publisher`, `url`, `snippet`,
#'   `cited_by`, `versions` and `cid` (Scholar's internal id for the result).
#' @examples
#' page <- '<div class="gs_r" data-cid="x1"><div class="gs_ri">
#'   <h3 class="gs_rt"><a href="https://example.org/a">Retention and <b>advising</b></a></h3>
#'   <div class="gs_a">A Smith, B Jones - Journal of Examples, 2019 - Example Press</div>
#'   <div class="gs_fl"><a>Cite</a> <a>Cited by 12</a></div></div></div>'
#' scholar_parse_html(page)
#' @export
scholar_parse_html <- function(input, recursive = FALSE) {
  input <- .expand_html_inputs(input, recursive)
  if (length(input) > 1) {
    empty <- character()
    parts <- lapply(input, function(f) {
      r <- tryCatch(withCallingHandlers(
        .parse_scholar_one(f),
        warning = function(w) {
          if (grepl("No Google Scholar results", conditionMessage(w), fixed = TRUE)) {
            empty <<- c(empty, basename(f)); invokeRestart("muffleWarning")
          }
        }),
        error = function(e) {
          if (grepl("robot check", conditionMessage(e), fixed = TRUE)) {
            warning(basename(f), ": ", conditionMessage(e), call. = FALSE)
            return(.empty_scholar())
          }
          stop(e)
        })
      r
    })
    out <- do.call(rbind, parts)
    if (length(empty) > 0) {
      warning(length(empty), " file(s) contained no Google Scholar results and were skipped: ",
              paste(utils::head(empty, 5), collapse = ", "),
              if (length(empty) > 5) ", ..." else "", call. = FALSE)
    }
    message("Read ", length(input), " file(s): ", nrow(out), " result(s).")
    rownames(out) <- NULL
    return(out)
  }
  .parse_scholar_one(input)
}

# Turn folders into the .html files inside them; leave file paths and HTML text alone.
.expand_html_inputs <- function(input, recursive = FALSE) {
  if (length(input) == 0) stop("`input` is empty.", call. = FALSE)
  out <- character()
  for (x in input) {
    if (is.na(x)) next
    is_text <- grepl("<", x, fixed = TRUE)
    if (!is_text && dir.exists(path.expand(x))) {
      f <- list.files(path.expand(x), pattern = "\\.html?$", ignore.case = TRUE,
                      full.names = TRUE, recursive = recursive)
      f <- sort(f)
      if (length(f) == 0) stop("No .html files found in folder: ", x, call. = FALSE)
      out <- c(out, f)
    } else {
      out <- c(out, if (is_text) x else path.expand(x))
    }
  }
  out
}

.parse_scholar_one <- function(input) {
  doc <- .read_scholar_page(input)
  blocks <- xml2::xml_find_all(doc, "//div[contains(concat(' ', normalize-space(@class), ' '), ' gs_ri ')]")

  if (length(blocks) == 0) {
    txt <- tolower(xml2::xml_text(doc))
    if (grepl("unusual traffic|not a robot|captcha", txt)) {
      stop("This looks like a Google Scholar robot check page, not a results page. ",
           "Open the results in your browser, then save that page.", call. = FALSE)
    }
    warning("No Google Scholar results found. Was this a saved results page?", call. = FALSE)
    return(.empty_scholar())
  }

  src_name <- if (grepl("<", input, fixed = TRUE)) NA_character_ else basename(input)
  one <- function(b) {
    node1 <- function(xp) xml2::xml_find_first(b, xp)
    txt1 <- function(xp) {
      n <- node1(xp)
      if (inherits(n, "xml_missing")) NA_character_ else .squish(xml2::xml_text(n))
    }
    a <- node1(".//h3[contains(@class,'gs_rt')]//a")
    if (inherits(a, "xml_missing")) {
      title <- txt1(".//h3[contains(@class,'gs_rt')]")
      title <- .squish(sub("^\\[[A-Za-z]+\\]\\s*", "", title))
      url <- NA_character_
    } else {
      title <- .squish(xml2::xml_text(a))
      url <- xml2::xml_attr(a, "href")
    }
    gsa <- txt1(".//div[contains(@class,'gs_a')]")
    p <- .parse_gs_a(if (is.na(gsa)) "" else gsa)
    foot <- xml2::xml_text(xml2::xml_find_all(b, ".//div[contains(@class,'gs_fl')]//a"))
    num <- function(pat) {
      h <- grep(pat, foot, value = TRUE)
      if (length(h) == 0) return(NA_integer_)
      as.integer(sub(paste0(".*?", pat, ".*"), "\\1", h[1], perl = TRUE))
    }
    cid <- xml2::xml_attr(xml2::xml_find_first(b, "./ancestor::div[@data-cid][1]"), "data-cid")
    data.frame(
      source_file = src_name,
      title = title,
      authors = if (length(p$authors)) paste(vapply(p$authors, .scholar_author, ""), collapse = " and ") else NA_character_,
      author_list = I(list(vapply(p$authors, .scholar_author, "", USE.NAMES = FALSE))),
      authors_truncated = p$authors_truncated,
      venue = p$venue, venue_truncated = p$venue_truncated,
      year = p$year, publisher = p$publisher, url = url,
      snippet = txt1(".//div[contains(@class,'gs_rs')]"),
      cited_by = num("Cited by ([0-9]+)"), versions = num("All ([0-9]+) versions"),
      cid = cid, stringsAsFactors = FALSE
    )
  }
  out <- do.call(rbind, lapply(blocks, one))
  rownames(out) <- NULL
  out
}

.empty_scholar <- function() {
  data.frame(source_file = character(), title = character(), authors = character(),
             author_list = I(list()), authors_truncated = logical(),
             venue = character(), venue_truncated = logical(), year = integer(),
             publisher = character(), url = character(), snippet = character(),
             cited_by = integer(), versions = integer(), cid = character(),
             stringsAsFactors = FALSE)
}

#' Convert a saved Google Scholar results page to BibTeX
#'
#' Parses a saved Scholar results page with [scholar_parse_html()] and writes
#' BibTeX entries. Results with a venue become `@article`; others become
#' `@misc`. Entries whose author list or venue was cut short by Scholar get a
#' `note` field saying so, so you can find and complete them.
#'
#' The entries only contain what the results list shows (no volume, pages,
#' DOI or abstract). For complete records use Scholar's Cite > BibTeX.
#'
#' @inheritParams scholar_parse_html
#' @param output Path for the `.bib` file. If `NULL` (default), nothing is
#'   written and the entries are returned.
#' @param drop_duplicates Remove results that appear more than once (same title,
#'   case ignored) when you combine several pages.
#' @param abstracts If `TRUE`, look up each abstract in OpenAlex with
#'   [fetch_abstracts()] and include it in the entries. Needs internet access.
#' @param api_key Your OpenAlex API key, passed to [fetch_abstracts()]. Defaults to
#'   the `OPENALEX_API_KEY` environment variable.
#' @return A character vector with one BibTeX entry per result (invisibly when
#'   `output` is given).
#' @examples
#' page <- '<div class="gs_r"><div class="gs_ri">
#'   <h3 class="gs_rt"><a href="https://example.org/a">Retention and advising</a></h3>
#'   <div class="gs_a">A Smith, B Jones - Journal of Examples, 2019 - Example Press</div>
#'   </div></div>'
#' cat(scholar_html_to_bib(page))
#' @export
scholar_html_to_bib <- function(input, output = NULL, drop_duplicates = TRUE,
                                abstracts = FALSE,
                                api_key = Sys.getenv("OPENALEX_API_KEY")) {
  res <- scholar_parse_html(input)
  if (nrow(res) == 0) return(invisible(character(0)))
  if (isTRUE(drop_duplicates)) {
    dup <- duplicated(tolower(res$title))
    if (any(dup)) message(sum(dup), " duplicate result(s) removed.")
    res <- res[!dup, , drop = FALSE]
  }

  if (isTRUE(abstracts)) res <- fetch_abstracts(res, api_key = api_key)

  ris <- character()
  for (i in seq_len(nrow(res))) {
    r <- res[i, ]
    clean <- function(x) gsub("[\r\n]+", " ", x)
    ris <- c(ris, paste0("TY  - ", if (!is.na(r$venue)) "JOUR" else "GEN"))
    for (a in r$author_list[[1]]) ris <- c(ris, paste0("AU  - ", clean(a)))
    if (!is.na(r$title)) ris <- c(ris, paste0("TI  - ", clean(r$title)))
    if (!is.na(r$venue)) ris <- c(ris, paste0("JO  - ", clean(r$venue)))
    if (!is.na(r$year)) ris <- c(ris, paste0("PY  - ", r$year))
    if (!is.na(r$publisher)) ris <- c(ris, paste0("PB  - ", clean(r$publisher)))
    if (!is.na(r$url)) ris <- c(ris, paste0("UR  - ", clean(r$url)))
    if (isTRUE(abstracts) && !is.na(r$abstract)) ris <- c(ris, paste0("AB  - ", clean(r$abstract)))
    flags <- c(if (r$authors_truncated) "author list",
               if (r$venue_truncated) "venue name")
    if (length(flags)) {
      ris <- c(ris, paste0("N1  - Incomplete: Google Scholar shortened the ",
                           paste(flags, collapse = " and "), "; check against the source."))
    }
    ris <- c(ris, "ER  - ", "")
  }
  Encoding(ris) <- "UTF-8"
  entries <- refworks_to_bib(ris)

  n_flag <- sum(res$authors_truncated | res$venue_truncated)
  if (n_flag > 0) {
    message(n_flag, " of ", nrow(res), " result(s) had a shortened author list or venue ",
            "(marked in the note field).")
  }
  if (is.null(output)) return(entries)
  writeLines(paste(entries, collapse = "\n"), output, useBytes = TRUE)
  message("Converted ", length(entries), " result(s) -> ", output)
  invisible(entries)
}
