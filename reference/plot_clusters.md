# Several clusters on one page

Draws each cluster as a small map in one figure: one dot colour,
equal-sized dots, every name shown, and an orange line where two authors
published together more than once (the number is how many papers). Each
panel is named after the author with the most papers in that group. A
single key at the bottom explains the lines.

## Usage

``` r
plot_clusters(
  x,
  components = NULL,
  ncol = NULL,
  max_panels = 6,
  min_papers = 2,
  core_only = FALSE,
  seed = 1
)
```

## Arguments

- x:

  An object from \[author_network()\].

- components:

  Cluster IDs to draw. Default: every cluster with two or more authors
  and at least \`min_papers\` papers, those with the most papers first
  (at most \`max_panels\`).

- ncol:

  Panels per row. Default: 2 when there are 2 to 4 clusters, 3 for more.

- max_panels:

  Most panels on one page. Default 6.

- min_papers:

  Only clusters supported by at least this many papers (default 2) are
  drawn, so one-paper author lists don't fill the page. When more
  clusters qualify than fit, the ones with the most papers are shown.

- core_only:

  Passed to \[plot_cluster()\]: drop one-paper co-authors.

- seed:

  Layout seed, as in \[plot_cluster()\].

## Value

Invisibly, the cluster IDs drawn.

## Examples

``` r
if (requireNamespace("igraph", quietly = TRUE)) {
  f <- system.file("extdata", "sample_authors.csv", package = "citelens")
  net <- suppressMessages(author_network(read.csv(f, stringsAsFactors = FALSE)))
  plot_clusters(net)
}
```
