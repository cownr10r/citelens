# Read a BibTeX (.bib) file into a data frame

Parses a BibTeX file with compiled C++ code and returns one row per
entry. The entry type is in \`bibtype\`, the citation key in \`bibkey\`,
and every BibTeX field found in the file (author, title, year, ...)
becomes a column. Fields an entry doesn't have are \`NA\`. All columns
are character vectors.

## Usage

``` r
bib_to_df(input, clean = TRUE, xlsx = NULL)
```

## Arguments

- input:

  Path to the \`.bib\` (or \`.txt\`) file.

- clean:

  If \`TRUE\` (the default), tidy each value: remove grouping braces
  (e.g. a title wrapped in double braces becomes plain text), unescape
  backslash-escaped ampersands, percent signs, dollar signs, hashes and
  underscores, and collapse line breaks and repeated spaces. Other LaTeX
  commands, such as accents, are left as they are. Use \`FALSE\` to get
  the raw values.

- xlsx:

  Optional path for an Excel file (e.g. \`"~/Desktop/refs.xlsx"\`). If
  given, the data frame is also written there as a single sheet with a
  header row, and the data frame is returned invisibly. A missing
  \`.xlsx\` extension is added. An existing file at that path is
  overwritten.

## Value

A data frame with one row per BibTeX entry (invisibly when \`xlsx\` is
given).

## Details

\`@string\` macros and the standard month abbreviations (\`jan\`,
\`feb\`, ...) are expanded, \`#\` concatenation is handled, and
\`@comment\` / \`@preamble\` blocks are ignored.

## Examples

``` r
f <- system.file("extdata", "sample.bib", package = "citelens")
bib_to_df(f)
#>         bibtype     bibkey                                      author
#> 1       article  tinto2006                              Tinto, Vincent
#> 2          book bailey2015 Bailey, Thomas R. and Jaggars, Shanna Smith
#> 3 inproceedings nobody2020                                        <NA>
#>                                                    title
#> 1 Research and practice of student retention: What next?
#> 2               Redesigning America's Community Colleges
#> 3                      A title with a nested brace group
#>                                                             journal year
#> 1 Journal of College Student Retention: Research, Theory & Practice 2006
#> 2                                                              <NA> 2015
#> 3                                                              <NA> 2020
#>     month pages                         doi                        abstract
#> 1 January 1--19 10.2190/4NWK-STAC-2PLH-PJ3D Line one continues on line two.
#> 2    <NA>  <NA>                        <NA>                            <NA>
#> 3    <NA>  <NA>                        <NA>                            <NA>
#>                  publisher
#> 1                     <NA>
#> 2 Harvard University Press
#> 3                     <NA>

# Also save an Excel copy
out <- tempfile(fileext = ".xlsx")
bib_to_df(f, xlsx = out)
#> Wrote 3 entries to /tmp/RtmpvqUOhq/file1bc214698dc.xlsx
```
