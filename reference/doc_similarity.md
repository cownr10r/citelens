# Document similarity (cosine similarity of TF-IDF vectors)

Measures how alike the abstracts in a data frame are. Each abstract is
turned into a vector of word weights (TF-IDF: a word counts for more
when it is frequent in that abstract and rare across the collection),
and two abstracts are compared by the cosine of the angle between their
vectors: 0 means no words in common, 1 means the same word profile. Text
is cleaned the same way as in \[topic_model()\].

## Usage

``` r
doc_similarity(
  data,
  text = "abstract",
  id = "bibkey",
  min_doc_freq = 2,
  max_doc_prop = 1,
  min_word_length = 3,
  stopwords = NULL,
  singularize = TRUE
)
```

## Arguments

- data:

  A data frame with one row per reference.

- text:

  Name of the column holding the text to analyse.

- id:

  Name of a column that identifies each reference (default
  \`"bibkey"\`). If it does not exist, row numbers are used.

- min_doc_freq:

  Drop words that occur in fewer than this many abstracts. The default
  of 2 ignores words that cannot link two abstracts.

- max_doc_prop:

  Drop words that occur in more than this share of the abstracts (1
  keeps everything; try 0.5 to remove words common to nearly every
  abstract).

- min_word_length:

  Drop words shorter than this many letters.

- stopwords:

  Extra words to drop, in addition to \[citelens_stopwords()\].

- singularize:

  Merge simple plurals (default \`TRUE\`).

## Value

An object of class \`citelens_similarity\`. Use \[similar_to()\],
\[find_duplicates()\] and \[plot_similarity()\] to explore it; the
matrix itself is in \`\$sim\`.

## Details

Similarity reflects shared vocabulary, not meaning, so two abstracts
that use different words for the same idea can look less alike than they
are. The result stores a full abstract-by-abstract matrix, which is fine
for thousands of abstracts but grows with the square of their number.

## Examples

``` r
f <- system.file("extdata", "sample_abstracts.bib", package = "citelens")
refs <- bib_to_df(f)
s <- doc_similarity(refs)
similar_to(s, "syn01", n = 3)
#>   rank    id similarity
#> 1    1 syn05  0.6022649
#> 2    2 syn08  0.5754191
#> 3    3 syn02  0.5753822
```
