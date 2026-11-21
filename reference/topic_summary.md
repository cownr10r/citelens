# One-row-per-topic summary

One-row-per-topic summary

## Usage

``` r
topic_summary(model, n_terms = 5)
```

## Arguments

- model:

  A model from \[topic_model()\].

- n_terms:

  Number of top terms to list for each topic.

## Value

A data frame with \`topic\`, \`prevalence\` (average share of an
abstract), \`n_docs\` (abstracts whose dominant topic it is),
\`coherence\` (UMass; closer to zero is better) and \`top_terms\`.
