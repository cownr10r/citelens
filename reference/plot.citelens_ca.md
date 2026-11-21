# Plot an abstract correspondence analysis

Map of two dimensions: periods as large labelled squares, and the
\`n_terms\` words contributing most to those two dimensions as labelled
points.

## Usage

``` r
# S3 method for class 'citelens_ca'
plot(x, dims = c(1, 2), n_terms = 30, ...)
```

## Arguments

- x:

  An object from \[abstract_ca()\].

- dims:

  Two dimensions to plot (default 1 and 2).

- n_terms:

  Number of words to label.

- ...:

  Ignored.

## Value

\`x\`, invisibly.
