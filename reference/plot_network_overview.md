# Overview plot of the whole network (dots coloured by citations)

Collections of unrelated papers give many tiny disconnected components,
so by default only components with at least \`min_component\` authors
are drawn.

## Usage

``` r
plot_network_overview(
  x,
  min_component = 3,
  giant_only = FALSE,
  label_top = 15,
  ...
)
```

## Arguments

- x:

  An object from \[author_network()\].

- min_component:

  Smallest component (in authors) to draw. Default 3.

- giant_only:

  Plot only the largest connected component.

- label_top:

  Label this many authors with the highest strength.

- ...:

  Ignored.

## Value

\`x\`, invisibly.

## Examples

``` r
if (requireNamespace("igraph", quietly = TRUE)) {
  f <- system.file("extdata", "sample_authors.csv", package = "citelens")
  net <- suppressMessages(author_network(read.csv(f, stringsAsFactors = FALSE)))
  plot_network_overview(net, label_top = 8)
}
```
