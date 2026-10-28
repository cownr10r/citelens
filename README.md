# biblio

Convert citations exported from **RefWorks** into **BibTeX** (`.bib`) files, read
BibTeX into an **R data frame**, and save the result as an **Excel** spreadsheet.
The parsing is written in C++ (via [Rcpp](https://www.rcpp.org/)), so it is fast
even on large libraries.

## Installation

```r
# install.packages("remotes")
remotes::install_github("cownr10r/biblio")
```

The C++ code is compiled on your machine when you install, so you need a C++
compiler:

- **Mac:** the Xcode command line tools (`xcode-select --install` in Terminal)
- **Windows:** [Rtools](https://cran.r-project.org/bin/windows/Rtools/)
- **Linux:** `build-essential` (or your distribution's equivalent)

## What it does

| Function | Purpose |
|---|---|
| `refworks_to_xlsx(input, xlsx)` | One step: RefWorks export to an Excel file (optionally saves a `.bib` too) |
| `convert_refworks(input, output)` | RefWorks export to BibTeX entries / a `.bib` file |
| `bib_to_df(input, xlsx = NULL)` | BibTeX file to a data frame (optionally also an Excel file) |

`convert_refworks()` and `refworks_to_xlsx()` accept both **RefWorks Tagged
Format** (lines like `RT`, `A1`, `T1`) and **RIS** (lines like `TY  -`, `AU  -`),
and detect which one you gave them.

## Quick start

```r
library(biblio)

# RefWorks / RIS export -> Excel in one step
refworks_to_xlsx("~/Downloads/export.ris", "~/Desktop/references.xlsx")

# ...and keep a BibTeX copy too
refworks_to_xlsx("~/Downloads/export.ris", "~/Desktop/references.xlsx",
                 bib = "~/Desktop/references.bib")

# RefWorks / RIS export -> BibTeX file
convert_refworks("~/Downloads/export.ris", "~/Desktop/references.bib")

# BibTeX file -> data frame (and optionally an Excel copy)
refs <- bib_to_df("~/Desktop/references.bib")
refs <- bib_to_df("~/Desktop/references.bib", xlsx = "~/Desktop/references.xlsx")
```

Sample files are included so you can try it right away:

```r
ris <- system.file("extdata", "sample_refworks.ris", package = "biblio")
cat(convert_refworks(ris)[1])
```

```
@article{tinto2006research,
  author   = {Tinto, Vincent},
  title    = {{Research and practice of student retention: What next?}},
  journal  = {Journal of College Student Retention: Research, Theory \& Practice},
  year     = 2006,
  volume   = {8},
  number   = {1},
  pages    = {1--19},
  issn     = {1521-0251},
  doi      = {10.2190/4NWK-STAC-2PLH-PJ3D},
  url      = {https://example.org/tinto2006},
  keywords = {retention, persistence},
  abstract = {This article reviews the last forty years of research ...}
}
```

`bib_to_df()` returns one row per entry. `bibtype` and `bibkey` come first, then
one column for every BibTeX field in the file (`author`, `title`, `journal`,
`year`, `doi`, ...). Fields an entry does not have are `NA`, and every column is
character.

## Good to know

- **Citation keys** are generated as author + year + first meaningful title word
  (e.g. `tinto2006research`), with a letter added to keep duplicates unique.
- **Reference types** are mapped to BibTeX types (journal article to `article`,
  book chapter to `incollection`, thesis to `phdthesis`, and so on). Anything
  unrecognised becomes `misc`.
- **Cleaning:** by default `bib_to_df()` removes grouping braces (`{{Title}}`
  becomes `Title`), unescapes `\&`, `\%`, `\$`, `\#`, `\_`, and collapses extra
  whitespace. Use `clean = FALSE` for the raw values. Accent commands such as
  `{\'e}` are left as LaTeX.
- **Odd characters:** files saved with Windows-1252 curly quotes or containing
  hidden control characters are repaired when read, so the Excel output always
  opens cleanly.
- **BibTeX features supported when reading:** `@string` macros, month names,
  `#` concatenation, `{...}`, `"..."` and `(...)` delimiters; `@comment` and
  `@preamble` blocks are ignored.

## Development

```r
devtools::load_all()   # compile and load
devtools::test()       # run the tests
devtools::check()      # full package check
```

## License

MIT
