# Default stop words used by \`topic_model()\`

Common English function words plus words that appear in almost every
abstract ("study", "results", "findings", ...). Pass your own additions
to the \`stopwords\` argument of \[topic_model()\].

## Usage

``` r
citelens_stopwords()
```

## Value

A character vector.

## Examples

``` r
head(citelens_stopwords())
#> [1] "a"       "about"   "above"   "after"   "again"   "against"
```
