# Topic assignments for each abstract

Gives, for every abstract used in the model, its dominant topic, how
strongly it belongs to that topic, and its mix of all topics.

## Usage

``` r
topic_documents(model, data = NULL)
```

## Arguments

- model:

  A model from \[topic_model()\].

- data:

  Optional: the same data frame you passed to \[topic_model()\]. If
  given, the topic columns are added to it (with \`NA\` for rows that
  had no usable abstract), so you can keep working with your reference
  table.

## Value

A data frame with \`dominant_topic\`, \`dominant_prob\` and one
\`topic\_\<number\>\` column per topic (an \`id\` and \`row\` column are
included when \`data\` is not given).
