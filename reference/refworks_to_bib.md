# Convert RefWorks citations (Tagged Format or RIS) to BibTeX entries

The format is detected automatically: lines starting with \`TY - \` mean
RIS, otherwise RefWorks Tagged Format (\`RT\`, \`A1\`, \`T1\`, ...) is
assumed.

## Usage

``` r
refworks_to_bib(lines)
```

## Arguments

- lines:

  Character vector of lines from the export (e.g. from readLines()).

## Value

Character vector with one BibTeX entry per record.
