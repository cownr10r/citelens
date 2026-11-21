# Abstracts most similar to a given one

Abstracts most similar to a given one

## Usage

``` r
similar_to(s, which, n = 5, data = NULL, title = "title")
```

## Arguments

- s:

  A result from \[doc_similarity()\].

- which:

  The reference to look up: its id (for example the \`bibkey\`) or its
  position among the abstracts used.

- n:

  Number of similar abstracts to return.

- data:

  Optional: the data frame passed to \[doc_similarity()\]. If given, the
  \`title\` column (see \`title\`) is added to the result.

- title:

  Name of the title column in \`data\`.

## Value

A data frame with \`rank\`, \`id\`, \`similarity\` (and \`title\`).
