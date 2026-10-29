# citelens

Convert citations exported from **RefWorks** into **BibTeX** (`.bib`) files, read
BibTeX into an **R data frame**, save the result as an **Excel** spreadsheet, and
run **text analytics on the abstracts**: topic modeling, document similarity
(including duplicate finding), and trends over time. The parsing and the heavy
calculations are written in C++ (via [Rcpp](https://www.rcpp.org/)), so it is fast
even on large libraries.

## Installation

```r
# install.packages("remotes")
remotes::install_github("cownr10r/citelens")
```

The C++ code is compiled on your machine when you install, so you need a C++
compiler:

- **Mac:** the Xcode command line tools (`xcode-select --install` in Terminal)
- **Windows:** [Rtools](https://cran.r-project.org/bin/windows/Rtools/)
- **Linux:** `build-essential` (or your distribution's equivalent)

## What it does

**Convert and load references**

| Function | Purpose |
|---|---|
| `refworks_to_xlsx(input, xlsx)` | One step: RefWorks export to an Excel file (optionally saves a `.bib` too) |
| `convert_refworks(input, output)` | RefWorks export to BibTeX entries / a `.bib` file |
| `bib_to_df(input, xlsx = NULL)` | BibTeX file to a data frame (optionally also an Excel file) |
| `scholar_html_to_bib(input, output)` | A saved Google Scholar results page to BibTeX |
| `scholar_parse_html(input)` | A saved Google Scholar results page to a data frame |
| `fetch_abstracts(refs)` | Look up missing abstracts in OpenAlex (by DOI or title) |

**Text analytics on abstracts** (these work on the data frame from `bib_to_df()`)

| Function | Purpose |
|---|---|
| `topic_model(refs, k)` | Find `k` topics in the abstracts (LDA) |
| `topic_terms()`, `topic_summary()`, `topic_documents()` | Top words per topic, a one-row-per-topic summary, and each abstract's topic added to your table |
| `plot_topic_terms()`, `plot_topic_prevalence()` | Charts of a topic model |
| `topic_k_search(refs, k = 2:8)` | Compare numbers of topics to help choose `k` |
| `doc_similarity(refs)` | Cosine similarity between every pair of abstracts |
| `similar_to()`, `find_duplicates()`, `plot_similarity()` | Closest matches to one paper, likely duplicate entries, and a heatmap with the numbers in each box |
| `similarity_to_df(s, xlsx = )` | The similarities as a data frame (matrix or pairs layout), optionally saved to Excel |
| `word_trends(refs, words)` | Share of abstracts mentioning a word, by year or group of years |
| `topic_trends(model, refs)` | Each topic's share by year or group of years |
| `plot_word_trends()`, `plot_topic_trends()` | Line charts of the trends |
| `citelens_stopwords()` | The list of ignored words (add your own with `stopwords = `) |

`convert_refworks()` and `refworks_to_xlsx()` accept both **RefWorks Tagged
Format** (lines like `RT`, `A1`, `T1`) and **RIS** (lines like `TY  -`, `AU  -`),
and detect which one you gave them.

## Quick start

```r
library(citelens)

# RefWorks / RIS export -> Excel in one step
refworks_to_xlsx("~/Downloads/export.ris", "~/Desktop/references.xlsx")

# ...and keep a BibTeX copy too
refworks_to_xlsx("~/Downloads/export.ris", "~/Desktop/references.xlsx",
                 bib = "~/Desktop/references.bib")

# RefWorks / RIS export -> BibTeX file
convert_refworks("~/Downloads/export.ris", "~/Desktop/references.bib")

# BibTeX file -> data frame (and optionally an Excel copy)
refs <- bib_to_df("~/Desktop/references.bib")
refs <- bib_to_df("~/Desktop/references.bib", xlsx = "~/Desktop/references.xlsx")
```

Sample files are included so you can try it right away:

```r
ris <- system.file("extdata", "sample_refworks.ris", package = "citelens")
cat(convert_refworks(ris)[1])

# 30 synthetic abstracts for trying the text analytics
refs <- bib_to_df(system.file("extdata", "sample_abstracts.bib", package = "citelens"))
```

```
@article{tinto2006research,
  author   = {Tinto, Vincent},
  title    = {{Research and practice of student retention: What next?}},
  journal  = {Journal of College Student Retention: Research, Theory \& Practice},
  year     = 2006,
  volume   = {8},
  number   = {1},
  pages    = {1--19},
  issn     = {1521-0251},
  doi      = {10.2190/4NWK-STAC-2PLH-PJ3D},
  url      = {https://example.org/tinto2006},
  keywords = {retention, persistence},
  abstract = {This article reviews the last forty years of research ...}
}
```

`bib_to_df()` returns one row per entry. `bibtype` and `bibkey` come first, then
one column for every BibTeX field in the file (`author`, `title`, `journal`,
`year`, `doi`, ...). Fields an entry does not have are `NA`, and every column is
character.

## Google Scholar results

Save a Google Scholar results page from your browser (File > Save Page As,
"Webpage, HTML Only"), then:

```r
scholar_parse_html("~/Downloads/scholar_page1.html")            # data frame of results
scholar_html_to_bib("~/Downloads/scholar_page1.html", "scholar.bib")

# a whole folder: every .html file in it is read and combined
scholar_parse_html("~/Documents/scholar_pages")
scholar_html_to_bib("~/Documents/scholar_pages", "scholar.bib")   # repeated results are removed

# or a list of files; recursive = TRUE also reads subfolders
scholar_html_to_bib(c("page1.html", "page2.html"), "scholar.bib")
scholar_parse_html("~/Documents/scholar_pages", recursive = TRUE)
```

Files in the folder that are not Scholar results pages are skipped with a warning
naming them. The `source_file` column shows which file each result came from.

This reads only the saved file; it never contacts Google Scholar, which blocks
automated requests. The results list shows title, authors, venue, year,
publisher and link, but it shortens long author lists and venue names with "..."
and has no volume, pages, DOI or abstract. Shortened entries get a `note` field
in the BibTeX (and `authors_truncated` / `venue_truncated` in the data frame) so
you can find them. For complete records use Scholar's **Cite > BibTeX** (or
**My library > Export**), which `bib_to_df()` reads directly, or its
**RefWorks / RefMan** exports, which `convert_refworks()` reads.

### Getting abstracts for Scholar results

Scholar's results list has no abstracts (only short search snippets), so look them
up in [OpenAlex](https://openalex.org), a free scholarly index with an official API.
OpenAlex now requires a free **API key**:

1. Create a free account at <https://openalex.org>.
2. Copy your key from <https://openalex.org/settings/api>.
3. Save it once in R (it is picked up automatically afterwards):
   ```r
   Sys.setenv(OPENALEX_API_KEY = "your-key")        # this session
   usethis::edit_r_environ()                        # permanently: add OPENALEX_API_KEY=your-key
   ```

```r
res <- scholar_parse_html("~/Downloads/scholar_page1.html")
res <- fetch_abstracts(res)                       # or fetch_abstracts(res, api_key = "your-key")
topic_model(res, k = 4, id = "title")             # then use the text analytics

# or straight into BibTeX, abstracts included
scholar_html_to_bib("scholar_page1.html", "scholar.bib", abstracts = TRUE)
```

A free key allows 100,000 credits a day; a title lookup costs 10, so a few
thousand references fit in a day. Without a key you get only about 100 credits a
day. If OpenAlex says the allowance is used up, the function stops and keeps what
it found; run it again on that result and it looks up only what is still missing.

Each title (or DOI) and your key are sent to OpenAlex. A match is accepted only when
the title is very close and the year agrees within a year; otherwise the abstract
stays `NA` rather than risk the wrong paper. Many but not all works have an abstract
in OpenAlex, so expect some gaps. Check `abstract_match` and `abstract_source` to
spot-check results. `fetch_abstracts()` also works on a `bib_to_df()` table that has
DOIs.

To see why some references have no abstract, look at `abstract_status`:

```r
table(res$abstract_status)
res[res$abstract_status == "title not matched", c("title", "closest_title", "closest_score")]

# if the closest titles are the right papers, accept looser matches (only missing ones are retried)
res <- fetch_abstracts(res, min_match = 0.75)

# "year differs": the title matched but the years are far apart (re-editions, online-first dates)
res[res$abstract_status == "year differs", c("title", "year", "closest_year")]
res <- fetch_abstracts(res, max_year_diff = 10)
```

Statuses: `found`, `no abstract on file` (OpenAlex has the paper but no abstract),
`title not matched`, `year differs`, `no results`, `lookup failed`.

## Topic modeling of abstracts

Find the main themes in the abstracts of a reference data frame (LDA, fitted in C++):

```r
refs <- bib_to_df("references.bib")

m <- topic_model(refs, k = 5, seed = 1)   # 5 topics
m                                          # summary: prevalence, coherence, top words

topic_terms(m, n = 10)        # top words per topic (data frame)
topic_summary(m)              # one row per topic
refs2 <- topic_documents(m, refs)   # your table + dominant_topic, dominant_prob, topic_1..k

plot_topic_terms(m)           # bar charts of each topic's top words
plot_topic_prevalence(m)      # how common each topic is

ks <- topic_k_search(refs, k = 2:8, seed = 1)   # which k?
plot(ks)
```

Tips: topic models work best with dozens of abstracts or more. Add words that
carry no meaning for your field with `stopwords = c("student", "college")`, and
use `max_doc_prop = 0.5` to drop words found in over half the abstracts. A
sample file lives at `system.file("extdata", "sample_abstracts.bib", package = "citelens")`
(synthetic text, for trying things out).

## Document similarity

Find which abstracts are most alike (cosine similarity of TF-IDF word weights):

```r
s <- doc_similarity(refs)               # compares every pair of abstracts
s                                       # quick summary

similar_to(s, "smith2019retention", n = 5, data = refs)   # closest matches to one paper
find_duplicates(s, cutoff = 0.9, data = refs)             # likely duplicate entries
plot_similarity(s)                      # heatmap, similar abstracts grouped together
```

Get the numbers as a data frame, and optionally save them to Excel:

```r
similarity_to_df(s, data = refs)                    # matrix: one row and column per reference
similarity_to_df(s, "pairs", data = refs)           # pairs: one row per pair, most similar first
similarity_to_df(s, "pairs", cutoff = 0.5)          # only pairs at or above 0.5
similarity_to_df(s, data = refs, xlsx = "~/Desktop/similarity.xlsx")   # Excel, both layouts
as.data.frame(s)                                    # same as the pairs layout
```

The Excel workbook has two sheets, `similarity_matrix` and `pairs`, whichever
layout you asked for. Similarities are rounded to 3 decimals (`digits = NULL` for
no rounding).

Similarity reflects shared vocabulary, not meaning. Use `stopwords = ` to drop
words common to your whole collection.

## Trends over time

See whether words or topics rise and fall across publication years:

```r
w <- word_trends(refs, words = c("equity", "belonging", "enrollment"), bin = 5)
w                       # share of abstracts mentioning each word, per period
plot_word_trends(w)

m <- topic_model(refs, k = 5, seed = 1)
tt <- topic_trends(m, refs, bin = 5)
plot_topic_trends(tt)
```

`bin` groups years (5 = five-year periods). Check `n_period`, the number of
abstracts in each period: periods with only a few abstracts give jumpy shares.

## Good to know

- **Citation keys** are generated as author + year + first meaningful title word
  (e.g. `tinto2006research`), with a letter added to keep duplicates unique.
- **Reference types** are mapped to BibTeX types (journal article to `article`,
  book chapter to `incollection`, thesis to `phdthesis`, and so on). Anything
  unrecognised becomes `misc`.
- **Cleaning:** by default `bib_to_df()` removes grouping braces (`{{Title}}`
  becomes `Title`), unescapes `\&`, `\%`, `\$`, `\#`, `\_`, and collapses extra
  whitespace. Use `clean = FALSE` for the raw values. Accent commands such as
  `{\'e}` are left as LaTeX.
- **Odd characters:** files saved with Windows-1252 curly quotes or containing
  hidden control characters are repaired when read, so the Excel output always
  opens cleanly.
- **Text analytics need an `abstract` column** (and a `year` column for the
  trend functions). If your column has another name, pass it with `text = "..."`
  or `year = "..."`. References with no abstract are skipped, and you are told how
  many.
- **Text cleaning for the analytics:** words are lower-cased, punctuation and
  numbers are removed, common English words and abstract boilerplate ("study",
  "results", ...) are dropped, and simple plurals are merged ("student" and
  "students" count as one).
- **Small collections:** topic models and trends are most reliable with dozens of
  abstracts or more. The functions warn when you have very few.
- **Charts** use ggplot2, which is installed with the package.
- **BibTeX features supported when reading:** `@string` macros, month names,
  `#` concatenation, `{...}`, `"..."` and `(...)` delimiters; `@comment` and
  `@preamble` blocks are ignored.

## Development

```r
devtools::load_all()   # compile and load
devtools::test()       # run the tests
devtools::check()      # full package check
```

## License

MIT
