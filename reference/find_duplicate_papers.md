# Find papers that appear more than once in a Scholar export

Google Scholar sometimes lists the same paper twice: a journal version
and a preprint, a re-indexed copy with one citation, or a reprint with a
new year. In a co-authorship network that makes two authors look as if
they wrote more papers together than they did. This function flags
likely duplicates without changing your data.

## Usage

``` r
find_duplicate_papers(
  data,
  title = "title",
  authors = "authors",
  year = "year",
  cites = "cited_by",
  sep = "\\s+and\\s+",
  method = c("near", "exact"),
  max_dist = 0.08,
  require_author_overlap = TRUE
)
```

## Arguments

- data:

  A data frame of papers, such as the result of \[scholar_parse_html()\]
  or \[bib_to_df()\].

- title, authors, year, cites:

  Names of the columns holding the title, the author string, the year,
  and the citation count. If there is no \`authors\` column but there is
  an \`author\` column (as from \[bib_to_df()\]), that one is used.
  Missing year or citation columns are allowed.

- sep:

  Regular expression separating authors in the author string. Default
  \`"\s+and\s+"\`.

- method:

  \`"near"\` (default) or \`"exact"\`.

- max_dist:

  For \`"near"\`: the largest edit distance, as a share of the longer
  title. Default 0.08 (about 1 character in 12).

- require_author_overlap:

  Only flag pairs that share an author surname. Default \`TRUE\`.

## Value

A data frame of class \`citelens_duplicates\` with one row per flagged
paper: \`group\`, \`row\` (row number in \`data\`), \`title\`, \`year\`,
\`cited_by\`, \`authors\`, and \`keep\` (\`TRUE\` for the most-cited row
in each group). It has zero rows if nothing is flagged.

## Details

Two rows are treated as the same paper when their titles match after
lower-casing, folding accents, and removing punctuation and extra spaces
(\`method = "exact"\`), or when they are within \`max_dist\` of each
other by edit distance (\`method = "near"\`, the default, which also
catches a missing word or a typo). By default a pair is flagged only
when the rows also share at least one author surname, so two different
papers that happen to have a generic title are not merged.

The \`"near"\` method compares every pair of titles, so memory and time
grow with the square of the number of rows. It is fine for a few
thousand references; for much larger files use \`method = "exact"\`.

## See also

\[dedupe_papers()\] to remove the copies, \[find_duplicates()\] to find
near-duplicate entries by abstract similarity instead of by title.

## Examples

``` r
f <- system.file("extdata", "sample_authors.csv", package = "citelens")
papers <- read.csv(f, stringsAsFactors = FALSE)
dups <- find_duplicate_papers(papers)
dups   # review before removing anything
#> 1 group(s) of likely duplicates; 1 row(s) would be dropped.
#> 
#> Group 1
#>   KEEP row 1    2018 | Alder, A. and Birch, B. | 120 cites | Persistence gaps in first-year cohorts
#>   drop row 7    2019 | Alder, A. and Birch, B. | 1 cites | Persistence gaps in first-year cohorts.
#> 
```
