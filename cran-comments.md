## Submission

This is a new submission.

## Test environments

* (fill in) local macOS, R 4.6.1
* (fill in) win-builder, R-devel and R-release (`devtools::check_win_devel()`)
* (fill in) R-hub, if used (`rhub::rhub_check()`)

## R CMD check results

(fill in from your own `devtools::check(cran = TRUE)` and the win-builder emails)

0 errors | 0 warnings | 1 note

* NOTE: "New submission" (expected).

## Notes for the CRAN team

* `fetch_abstracts()` and `scholar_html_to_bib(abstracts = TRUE)` query the
  'OpenAlex' web API and need a free API key. Examples that need it are in
  `\dontrun{}` because they require that key; the tests use mocked responses
  and need no internet access or key. The functions fail with an informative
  message when the service is unavailable or the key is missing or rejected.
* `scholar_parse_html()` only reads HTML files saved by the user; the package
  never contacts 'Google Scholar'.
* The C++ code uses only the standard library and 'Rcpp'; there are no external
  libraries and no `Makevars` or `configure` files.
* Overlap with existing packages: other packages read 'BibTeX' files
  (for example 'bibtex' and 'bib2df'); this package additionally converts
  'RefWorks'/'RIS' exports and saved 'Google Scholar' pages, and adds text
  analytics on the abstracts.
