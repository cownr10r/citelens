# Convert a RefWorks export (Tagged Format or RIS) to a .bib file

Reads citations exported from RefWorks in either RefWorks Tagged Format
or RIS format (detected automatically) and converts them to BibTeX
entries using compiled C++ code.

## Usage

``` r
convert_refworks(input, output = NULL)
```

## Arguments

- input:

  Path to the exported citation file (\`.txt\` or \`.ris\`).

- output:

  Path for the .bib file. If \`NULL\` (the default), nothing is written
  and the entries are returned.

## Value

A character vector with one BibTeX entry per record (invisibly when
\`output\` is given).

## Examples

``` r
f <- system.file("extdata", "sample_refworks.txt", package = "citelens")
cat(convert_refworks(f)[1])
#> @article{tinto2006research,
#>   author   = {Tinto, Vincent},
#>   title    = {{Research and practice of student retention: What next?}},
#>   journal  = {Journal of College Student Retention: Research, Theory \& Practice},
#>   year     = 2006,
#>   volume   = {8},
#>   number   = {1},
#>   pages    = {1--19},
#>   issn     = {1521-0251},
#>   doi      = {10.2190/4NWK-STAC-2PLH-PJ3D},
#>   url      = {https://example.org/tinto2006},
#>   keywords = {retention, persistence, higher education},
#>   abstract = {This article reviews the last forty years of research on student retention and argues that institutions should focus on the conditions that promote persistence in the classroom.}
#> }
```
