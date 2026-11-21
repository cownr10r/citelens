# Topic trends over time

Average share of each topic among the abstracts published in each year
(or group of years). Shares in a period add up to 1.

## Usage

``` r
topic_trends(model, data, year = "year", bin = 1, n_terms = 3)
```

## Arguments

- model:

  A model from \[topic_model()\].

- data:

  The same data frame that was passed to \[topic_model()\].

- year:

  Name of the column holding the publication year.

- bin:

  Width of each period in years.

- n_terms:

  Number of top words shown in each topic's label.

## Value

A data frame with \`period\`, \`topic\`, \`label\`, \`share\` (average
share of an abstract) and \`n_period\` (abstracts in the period).
