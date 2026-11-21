# Heatmap of document similarity

Heatmap of document similarity

## Usage

``` r
plot_similarity(
  s,
  order = TRUE,
  labels = length(s$doc_ids) <= 40,
  values = length(s$doc_ids) <= 30,
  digits = 2
)
```

## Arguments

- s:

  A result from \[doc_similarity()\].

- order:

  If \`TRUE\` (default), reorder abstracts so that similar ones sit
  together (hierarchical clustering).

- labels:

  Show reference ids on the axes? Defaults to \`TRUE\` for up to 40
  abstracts.

- values:

  Print the similarity number inside each box? Defaults to \`TRUE\` for
  up to 30 abstracts; with more, the numbers get too small to read.

- digits:

  Decimal places for the numbers (default 2).

## Value

A ggplot object.
