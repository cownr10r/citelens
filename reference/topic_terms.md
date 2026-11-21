# Top terms of each topic

Top terms of each topic

## Usage

``` r
topic_terms(model, n = 10)
```

## Arguments

- model:

  A model from \[topic_model()\].

- n:

  Number of terms to return per topic.

## Value

A data frame with columns \`topic\`, \`rank\`, \`term\` and \`beta\`
(the probability of the term within the topic).
