## Test environments
* local macOS (Apple silicon), R <R 4.5.1>
* GitHub Actions: macOS (release), Windows (release),
  Ubuntu (devel, release, oldrel-1)

## R CMD check results
0 errors | 0 warnings | 0 notes (local and GitHub Actions).

This is a new submission.

## Notes for the reviewer
* The package has no external C++ libraries; the compiled code uses only
  standard C++ and Rcpp.
* The functions that use the OpenAlex API (`fetch_abstracts()`,
  `scholar_html_to_bib(abstracts = TRUE)`) need a free API key and fail
  gracefully with an informative error if the network or key is unavailable.
  Their examples are in \dontrun{}, and the tests use a mock fetch function,
  so no tests touch the network.
* Google Scholar is never contacted; `scholar_parse_html()` only parses
  HTML files the user has saved locally.
* Related packages (bibtex, bib2df) exist; citelens adds RefWorks/RIS
  conversion and text analytics (topic models, similarity, trends) on abstracts.