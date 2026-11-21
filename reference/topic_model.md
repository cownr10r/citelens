# Topic modeling (LDA) of abstracts

Fits a Latent Dirichlet Allocation topic model to the abstracts in a
data frame, such as the one returned by \[bib_to_df()\]. Each abstract
is treated as a mixture of \`k\` topics and each topic as a distribution
over words. Fitting uses a collapsed Gibbs sampler written in C++.

## Usage

``` r
topic_model(
  data,
  k = 5,
  text = "abstract",
  id = "bibkey",
  n_iter = 1000,
  alpha = 5/k,
  beta = 0.01,
  min_doc_freq = 2,
  max_doc_prop = 1,
  min_word_length = 3,
  stopwords = NULL,
  singularize = TRUE,
  seed = NULL
)
```

## Arguments

- data:

  A data frame with one row per reference.

- k:

  Number of topics (at least 2).

- text:

  Name of the column holding the text to analyse.

- id:

  Name of a column that identifies each reference (default
  \`"bibkey"\`). If it does not exist, row numbers are used.

- n_iter:

  Number of Gibbs sampling sweeps.

- alpha:

  Prior on how many topics each abstract mixes. Smaller values mean each
  abstract concentrates on fewer topics. Default \`5 / k\`.

- beta:

  Prior on how many words each topic uses. Smaller values mean more
  focused topics.

- min_doc_freq:

  Drop words that occur in fewer than this many abstracts.

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

- seed:

  Optional number passed to \[set.seed()\] so the fit can be reproduced.

## Value

An object of class \`citelens_topics\`. Use \[topic_terms()\],
\[topic_documents()\], \[topic_summary()\], \[plot_topic_terms()\] and
\[plot_topic_prevalence()\] to explore it. Topics are numbered from the
most to the least prevalent.

## Details

Text is lower-cased, punctuation and numbers are removed, stop words
(see \[citelens_stopwords()\]) and very short words are dropped, and
simple plurals are merged (students and student count as one word).
Words that occur in fewer than \`min_doc_freq\` abstracts are ignored.

Topic models need a reasonably large collection (dozens of abstracts or
more) to give stable themes. With a handful of abstracts the output is
only exploratory. Different \`seed\` values can give somewhat different
topics; use \[topic_k_search()\] to help choose \`k\`.

## Examples

``` r
f <- system.file("extdata", "sample_abstracts.bib", package = "citelens")
refs <- bib_to_df(f)
filler <- c("note", "time", "follow", "shape", "touch", "studied", "evidence",
            "work", "attention", "discussion")   # words from the synthetic sample
m <- topic_model(refs, k = 3, stopwords = filler, seed = 1)
m
#> <citelens topic model>
#> 3 topics from 30 abstracts (51 distinct words, 496 word occurrences)
#> alpha = 1.67, beta = 0.01, sweeps = 1000
#> 
#>  topic prevalence n_docs coherence
#>      1        36%     10     -25.5
#>      2        33%     10     -27.2
#>      3        32%     10     -22.2
#>                                                                 top_terms
#>                               college, cost, financial, aid, budget, debt
#>  predictive, reporting, analytics, institutional, benchmarking, dashboard
#>               retention, support, advising, attrition, dropout, mentoring
topic_terms(m, n = 5)
#>    topic rank          term       beta
#> 1      1    1       college 0.07676292
#> 2      1    2          cost 0.07676292
#> 3      1    3     financial 0.07676292
#> 4      1    4           aid 0.07128377
#> 5      1    5        budget 0.07128377
#> 6      2    1    predictive 0.10036988
#> 7      2    2     reporting 0.10036988
#> 8      2    3     analytics 0.07529309
#> 9      2    4 institutional 0.07529309
#> 10     2    5  benchmarking 0.06902389
#> 11     3    1     retention 0.09652112
#> 12     3    2       support 0.09652112
#> 13     3    3      advising 0.08366021
#> 14     3    4     attrition 0.07722976
#> 15     3    5       dropout 0.07722976
```
