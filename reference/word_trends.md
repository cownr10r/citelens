# Word trends over time

For each year (or group of years), reports the share of abstracts that
mention a word. Words are cleaned the same way as in \[topic_model()\],
so "student" also counts "students". Use it to see whether a concept is
rising or fading across the literature.

## Usage

``` r
word_trends(
  data,
  words = NULL,
  n = 8,
  year = "year",
  text = "abstract",
  bin = 1,
  stopwords = NULL,
  min_word_length = 3,
  singularize = TRUE
)
```

## Arguments

- data:

  A data frame with one row per reference.

- words:

  Words to track, such as \`c("equity", "belonging")\`. If \`NULL\`, the
  \`n\` words found in the most abstracts overall are used.

- n:

  Number of words to track when \`words\` is \`NULL\`.

- year:

  Name of the column holding the publication year. Text such as "2019"
  or "Spring 2019" is fine; the first 4-digit number is used.

- text:

  Name of the column holding the text to analyse.

- bin:

  Width of each period in years (1 = one row per year).

- stopwords:

  Extra words to drop, in addition to \[citelens_stopwords()\].

- min_word_length:

  Drop words shorter than this many letters.

- singularize:

  Merge simple plurals (default \`TRUE\`).

## Value

A data frame with \`period\` (first year of the period), \`term\`,
\`n_docs\` (abstracts mentioning it), \`n_period\` (abstracts in the
period) and \`share\` (\`n_docs / n_period\`). Periods with no abstracts
are omitted.

## Details

Years with only a few abstracts give jumpy shares, so check \`n_period\`
(the number of abstracts in that year) before reading much into a
change. Use \`bin\` to group years, for example \`bin = 5\`.

## Examples

``` r
f <- system.file("extdata", "sample_abstracts.bib", package = "citelens")
refs <- bib_to_df(f)
word_trends(refs, words = c("retention", "tuition"), bin = 5)
#>   period      term n_docs n_period     share
#> 1   2015 retention      7       18 0.3888889
#> 2   2020 retention      4       12 0.3333333
#> 3   2015   tuition      4       18 0.2222222
#> 4   2020   tuition      4       12 0.3333333
```
