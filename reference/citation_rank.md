# Citation index and ranking

Ranks papers (or venues, or authors) by citation count and computes
summary citation indices (h-index, g-index, i10-index and more) for the
whole collection. Written in base R, so it adds no package dependencies.

## Usage

``` r
citation_rank(
  data,
  by = c("paper", "venue", "author"),
  cites = "cited_by",
  year = "year",
  title = "title",
  venue = "venue",
  authors = "authors",
  sep = "\\s+and\\s+",
  current_year = as.integer(format(Sys.Date(), "%Y")),
  na_cites_as_zero = TRUE,
  drop_untitled = TRUE,
  dedupe = TRUE,
  top_n = NULL
)
```

## Arguments

- data:

  A data frame with one row per paper, such as the result of
  \[scholar_parse_html()\] or \[bib_to_df()\].

- by:

  What to rank: \`"paper"\` (default), \`"venue"\` or \`"author"\`. For
  \`"author"\`, each author is credited with the full citation count of
  every paper they appear on.

- cites, year, title, venue, authors:

  Names of the columns in \`data\`. Defaults match the Google Scholar
  layout. If there is no \`authors\` column but there is an \`author\`
  column (as from \[bib_to_df()\]), that one is used.

- sep:

  Regular expression separating authors. Default \`"\s+and\s+"\`.

- current_year:

  Year used to compute paper age. Defaults to this year.

- na_cites_as_zero:

  If \`TRUE\` (default), a missing citation count is treated as 0, which
  is how Google Scholar reports an uncited paper (no "Cited by" link).
  If \`FALSE\`, those rows are dropped.

- drop_untitled:

  If \`TRUE\` (default), rows with no title (usually parse failures) are
  dropped with a message.

- dedupe:

  If \`TRUE\` (default), remove duplicate listings of the same paper
  before counting (see \[find_duplicate_papers()\]): the less-cited copy
  is dropped, a message names the rows, and they are returned in
  \`\$duplicates\`. Use \`FALSE\` to count every row.

- top_n:

  Optional. Keep only the top \`n\` rows of the ranked table. Indices
  are always computed on the full data.

## Value

An object of class \`citelens_rank\`, a list with:

- ranked:

  Data frame sorted by rank. For \`by = "paper"\`: \`rank\`, \`title\`,
  \`authors\`, \`venue\`, \`year\`, \`citations\`, \`percentile\`,
  \`share\`, \`cum_share\`, \`age\`, \`cites_per_year\`,
  \`rank_per_year\`. For \`"venue"\` and \`"author"\`: \`rank\`, the
  entity name, \`n_papers\`, \`total_citations\`, \`mean_citations\`,
  \`max_citations\`, \`h_index\`, \`share\`, \`cum_share\`.

- index:

  One-row data frame of whole-collection indices: \`n_papers\`,
  \`total\`, \`mean\`, \`median\`, \`max\`, \`uncited\`, \`h_index\`,
  \`g_index\`, \`i10_index\`.

- by, n_total:

  What was ranked, and the number of rows before \`top_n\`.

- duplicates:

  Rows dropped as duplicate listings, or \`NULL\`.

## Details

\* \*\*h-index\*\*: the largest h such that h papers each have at least
h citations. \* \*\*g-index\*\*: the largest g such that the top g
papers together have at least g^2 citations (capped at the number of
papers). \* \*\*i10-index\*\*: number of papers with at least 10
citations. \* \*\*rank\*\* uses competition ranking (\`ties.method =
"min"\`), so tied papers share a rank and the next rank is skipped. \*
\*\*percentile\*\* is the percent of papers with strictly fewer
citations. \* \*\*cites_per_year\*\* is citations divided by the paper's
age, where age = \`current_year - year + 1\`, so a paper from this year
has age 1.

Author and venue tables are built from the papers that remain after
de-duplication and cleaning.

## See also

\[find_duplicate_papers()\], \[author_network()\]

## Examples

``` r
f <- system.file("extdata", "sample_authors.csv", package = "citelens")
d <- read.csv(f, stringsAsFactors = FALSE)
res <- citation_rank(d, current_year = 2024)
#> Dropped 1 duplicate paper listing(s): row 7. Use dedupe = FALSE to keep them; see $duplicates.
res
#> Citation index (paper ranking)
#>  n_papers total mean median max uncited h_index g_index i10_index
#>        17   818 48.1     30 200       0      12      17        13
#> 
#> Top 10 of 17:
#>  rank                                              title
#>     1 Transfer pathways between two-year and four-year c
#>     2             Persistence gaps in first-year cohorts
#>     3                 Credit transfer and time to degree
#>     4              Advising models and degree completion
#>     5                  Peer mentoring and course success
#>     6     Dual credit participation and later enrollment
#>     7            Financial aid packaging and persistence
#>     8                    Early alerts in gateway courses
#>     9                Articulation agreements in practice
#>    10                   Summer bridge programs revisited
#>                    authors venue year citations percentile  share cum_share age
#>        Elm, E. and Fir, F.  <NA> 2017       200       94.1 0.2445    0.2445   8
#>    Alder, A. and Birch, B.  <NA> 2018       120       88.2 0.1467    0.3912   7
#>  Elm, E. and Fir, F. and G  <NA> 2019        95       82.4 0.1161    0.5073   6
#>  Alder, A. and Birch, B. a  <NA> 2019        85       76.5 0.1039    0.6112   6
#>    Birch, B. and Cedar, C.  <NA> 2020        60       70.6 0.0733    0.6846   5
#>      Hazel, H. and Ivy, I.  <NA> 2020        55       64.7 0.0672    0.7518   5
#>  Juniper, J. and Kapok, K.  <NA> 2016        44       58.8 0.0538    0.8056   9
#>  Alder, A. and Dogwood, D.  <NA> 2021        40       52.9 0.0489    0.8545   4
#>        Elm, E. and Gum, G.  <NA> 2021        30       47.1 0.0367    0.8912   4
#>    Alder, A. and Birch, B.  <NA> 2022        25       41.2 0.0306    0.9218   3
#>  cites_per_year rank_per_year
#>           25.00             1
#>           17.14             2
#>           15.83             3
#>           14.17             4
#>           12.00             5
#>           11.00             6
#>            4.89            12
#>           10.00             7
#>            7.50             9
#>            8.33             8
res$index
#>   n_papers total mean median max uncited h_index g_index i10_index
#> 1       17   818 48.1     30 200       0      12      17        13
citation_rank(d, by = "author", top_n = 5)$ranked
#> Dropped 1 duplicate paper listing(s): row 7. Use dedupe = FALSE to keep them; see $duplicates.
#>   rank    author n_papers total_citations mean_citations max_citations h_index
#> 1    1   Elm, E.        3             325          108.3           200       3
#> 2    2 Birch, B.        5             300           60.0           120       5
#> 3    3   Fir, F.        2             295          147.5           200       2
#> 4    4 Alder, A.        5             280           56.0           120       5
#> 5    5 Cedar, C.        2             145           72.5            85       2
#>    share cum_share
#> 1 0.1775    0.1775
#> 2 0.1638    0.3413
#> 3 0.1611    0.5025
#> 4 0.1529    0.6554
#> 5 0.0792    0.7346
```
