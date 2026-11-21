# Write a map for every cluster

Calls \[plot_cluster()\] for each cluster and saves one PNG file per
cluster and, optionally, a single multi-page PDF with all of them.
Nothing is written unless you give a \`dir\` or a \`pdf\`.

## Usage

``` r
cluster_maps(
  x,
  dir = NULL,
  pdf = NULL,
  min_authors = 2,
  order = c("citations", "papers", "authors", "id"),
  width = 8,
  height = 5,
  res = 150
)
```

## Arguments

- x:

  An object from \[author_network()\].

- dir:

  Folder for the PNG files (created if needed), or \`NULL\` for none.

- pdf:

  File name for the combined PDF, or \`NULL\` for none.

- min_authors:

  Skip clusters with fewer authors than this. Default 2.

- order:

  How to order the clusters in the PDF: \`"citations"\` (default),
  \`"papers"\`, \`"authors"\` or \`"id"\`.

- width, height:

  Size in inches. Default 8 by 5.

- res:

  PNG resolution. Default 150.

## Value

Invisibly, the vector of cluster IDs drawn.

## Examples

``` r
if (requireNamespace("igraph", quietly = TRUE)) {
  f <- system.file("extdata", "sample_authors.csv", package = "citelens")
  net <- suppressMessages(author_network(read.csv(f, stringsAsFactors = FALSE),
                                         min_component_papers = 2))
  out <- tempfile("maps")
  cluster_maps(net, dir = out, pdf = file.path(tempdir(), "maps.pdf"))
}
#> Wrote 3 PNG files to /tmp/RtmpJIvsnT/maps193472538386
#> Wrote /tmp/RtmpJIvsnT/maps.pdf
```
