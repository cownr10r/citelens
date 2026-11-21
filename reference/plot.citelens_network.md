# Plot a co-authorship network

The default view is one page of small maps, one per group of authors who
published together: a single dot colour, equal-sized dots, every name
shown, orange lines for pairs who published together more than once and
gray lines for pairs who shared one paper (see \[plot_clusters()\]).
Groups supported by fewer than \`min_papers\` papers are left out and,
if more than \`max_panels\` qualify, the ones with the most papers are
drawn.

## Usage

``` r
# S3 method for class 'citelens_network'
plot(x, type = c("groups", "overview"), ...)
```

## Arguments

- x:

  An object from \[author_network()\].

- type:

  \`"groups"\` (default) for the page of small maps, or \`"overview"\`
  for the single combined plot with dots coloured by citations and sized
  by collaboration strength (see \[plot_network_overview()\]).

- ...:

  For \`type = "groups"\`: \`min_papers\`, \`max_panels\`,
  \`components\`, \`ncol\`, \`core_only\`, \`seed\`. For \`type =
  "overview"\`: \`min_component\`, \`giant_only\`, \`label_top\`.

## Value

\`x\`, invisibly.

## Examples

``` r
if (requireNamespace("igraph", quietly = TRUE)) {
  f <- system.file("extdata", "sample_authors.csv", package = "citelens")
  net <- suppressMessages(author_network(read.csv(f, stringsAsFactors = FALSE)))
  plot(net)                      # the page of group maps
  plot(net, max_panels = 3)      # only the three groups with the most papers
  plot(net, type = "overview")   # the all-in-one plot
}


```
