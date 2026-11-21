# Similarity results as a data frame (optionally saved to Excel)

Turns the result of \[doc_similarity()\] into a data frame you can view,
filter and save. Two layouts are available:

## Usage

``` r
similarity_to_df(
  s,
  type = c("matrix", "pairs"),
  data = NULL,
  title = "title",
  digits = 3,
  cutoff = 0,
  xlsx = NULL
)
```

## Arguments

- s:

  A result from \[doc_similarity()\].

- type:

  \`"matrix"\` (default) or \`"pairs"\`.

- data:

  Optional: the data frame passed to \[doc_similarity()\]. If given, the
  \`title\` column is added (\`title\` in the matrix; \`title_1\` and
  \`title_2\` in the pairs).

- title:

  Name of the title column in \`data\`.

- digits:

  Decimal places to round the similarities to (default 3). Use \`NULL\`
  for no rounding.

- cutoff:

  For \`type = "pairs"\` (and the pairs sheet in Excel): keep only pairs
  at or above this similarity (0 to 1). Default 0 keeps every pair.

- xlsx:

  Optional path for an Excel file (e.g.
  \`"~/Desktop/similarity.xlsx"\`). A missing \`.xlsx\` ending is added.
  When given, the data frame is returned invisibly.

## Value

A data frame. For \`"matrix"\`: \`id\` (plus \`title\`) and one column
per reference. For \`"pairs"\`: \`id_1\`, \`id_2\`, \`similarity\` (plus
\`title_1\`, \`title_2\`).

## Details

\* \`type = "matrix"\`: one row and one column per reference, with the
cosine similarity in each cell (the table behind the heatmap). \* \`type
= "pairs"\`: one row per pair of references, most similar first, which
is easier to sort, filter and scan.

If you give \`xlsx\`, an Excel workbook is written with \*\*both\*\*
layouts, on sheets named \`similarity_matrix\` and \`pairs\`, whichever
\`type\` you asked for.

## Examples

``` r
f <- system.file("extdata", "sample_abstracts.bib", package = "citelens")
refs <- bib_to_df(f)
s <- doc_similarity(refs)
head(similarity_to_df(s, "pairs", data = refs), 3)
#>    id_1  id_2 similarity                               title_1
#> 1 syn02 syn06      0.761        Predicting student persistence
#> 2 syn21 syn29      0.724 Assessment and accountability metrics
#> 3 syn04 syn05      0.702        Predicting student persistence
#>                                 title_2
#> 1     Advising and first-year retention
#> 2 Predictive models in higher education
#> 3     Advising and first-year retention
out <- tempfile(fileext = ".xlsx")
similarity_to_df(s, data = refs, xlsx = out)
#> Wrote the similarity matrix (30 x 30) and 435 pair(s) to /tmp/RtmpvqUOhq/file1bc25ae7b365.xlsx
```
