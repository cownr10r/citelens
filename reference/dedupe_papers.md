# Remove the less-cited copy of each duplicated paper

Runs \[find_duplicate_papers()\] and drops every flagged row except the
most-cited one in each group. Review the result of
\[find_duplicate_papers()\] first.

## Usage

``` r
dedupe_papers(data, ..., drop_rows = NULL)
```

## Arguments

- data:

  A data frame of papers.

- ...:

  Passed to \[find_duplicate_papers()\].

- drop_rows:

  Optional integer vector of row numbers to drop instead of the
  automatic choice, for example after reviewing the list.

## Value

\`data\` without the duplicate rows, with an attribute \`"dropped"\`
holding the flagged rows that were removed.

## Examples

``` r
f <- system.file("extdata", "sample_authors.csv", package = "citelens")
papers <- read.csv(f, stringsAsFactors = FALSE)
clean <- dedupe_papers(papers)
#> Dropped 1 duplicate row(s); 17 papers remain.
attr(clean, "dropped")
#> 1 group(s) of likely duplicates; 1 row(s) would be dropped.
#> 
#> Group 1
#>   drop row 7    2019 | Alder, A. and Birch, B. | 1 cites | Persistence gaps in first-year cohorts.
#> 
```
