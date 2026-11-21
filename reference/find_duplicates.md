# Find likely duplicate or near-duplicate references

Lists every pair of abstracts whose cosine similarity is at or above
\`cutoff\`, most similar first. Useful for cleaning a library where the
same article was entered twice.

## Usage

``` r
find_duplicates(s, cutoff = 0.9, data = NULL, title = "title")
```

## Arguments

- s:

  A result from \[doc_similarity()\].

- cutoff:

  Minimum similarity to report (0 to 1).

- data:

  Optional: the data frame passed to \[doc_similarity()\]. If given, the
  \`title\` of each reference is added.

- title:

  Name of the title column in \`data\`.

## Value

A data frame with \`id_1\`, \`id_2\` and \`similarity\` (and
\`title_1\`, \`title_2\`); zero rows if no pair reaches the cutoff.
