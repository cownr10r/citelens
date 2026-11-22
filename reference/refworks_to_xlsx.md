# Convert a RefWorks export straight to an Excel file

One step from a RefWorks export (Tagged Format or RIS, detected
automatically) to an Excel spreadsheet with one row per reference.
Internally it runs \[convert_refworks()\] and then \[bib_to_df()\], so
the same cleaning of odd characters applies. Optionally it also saves
the intermediate BibTeX file.

## Usage

``` r
refworks_to_xlsx(input, xlsx, bib = NULL, clean = TRUE)
```

## Arguments

- input:

  Path to the RefWorks export (\`.txt\` or \`.ris\`).

- xlsx:

  Path for the Excel file, e.g. \`"~/Desktop/references.xlsx"\`. A
  missing \`.xlsx\` extension is added and an existing file is
  overwritten.

- bib:

  Optional path for a BibTeX file to save as well (e.g.
  \`"~/Desktop/references.bib"\`). Leave as \`NULL\` to skip it.

- clean:

  Passed to \[bib_to_df()\]: tidy braces, LaTeX escapes and extra
  whitespace in the values (default \`TRUE\`).

## Value

The data frame of references, invisibly.

## Examples

``` r
ris <- system.file("extdata", "sample_refworks.ris", package = "citelens")
refworks_to_xlsx(ris, tempfile(fileext = ".xlsx"))
#> Wrote 4 entries to /tmp/RtmpN9Gj0s/file19d13f1bb442.xlsx
```
