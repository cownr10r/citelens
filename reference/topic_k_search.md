# Compare different numbers of topics

Fits a model for each value of \`k\` and reports the average topic
coherence (UMass; closer to zero means a topic's top words more often
appear together). Look for the \`k\` where coherence is best or stops
improving, then read the topics to see whether they make sense. This is
a guide, not a verdict.

## Usage

``` r
topic_k_search(data, k = 2:8, ...)
```

## Arguments

- data:

  A data frame, as for \[topic_model()\].

- k:

  Vector of topic counts to try.

- ...:

  Other arguments passed to \[topic_model()\] (for example \`seed\`,
  \`n_iter\`, \`stopwords\`).

## Value

A data frame with \`k\`, \`mean_coherence\` and \`loglik\`; it has a
\`plot()\` method.

## Examples

``` r
f <- system.file("extdata", "sample_abstracts.bib", package = "citelens")
topic_k_search(bib_to_df(f), k = 2:4, n_iter = 200, seed = 1)
#>   k mean_coherence    loglik
#> 1 2      -27.93096 -2973.204
#> 2 3      -25.20248 -2749.025
#> 3 4      -27.23311 -2486.507
```
