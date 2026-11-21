# Convert a saved Google Scholar results page to BibTeX

Parses a saved Scholar results page with \[scholar_parse_html()\] and
writes BibTeX entries. Results with a venue become \`@article\`; others
become \`@misc\`. Entries whose author list or venue was cut short by
Scholar get a \`note\` field saying so, so you can find and complete
them.

## Usage

``` r
scholar_html_to_bib(
  input,
  output = NULL,
  drop_duplicates = TRUE,
  abstracts = FALSE,
  api_key = Sys.getenv("OPENALEX_API_KEY")
)
```

## Arguments

- input:

  One or more paths to saved \`.html\` files, \*\*a folder\*\* (every
  \`.html\` / \`.htm\` file in it is read), or a string of HTML text.
  Results from several pages are combined.

- output:

  Path for the \`.bib\` file. If \`NULL\` (default), nothing is written
  and the entries are returned.

- drop_duplicates:

  Remove results that appear more than once (same title, case ignored)
  when you combine several pages.

- abstracts:

  If \`TRUE\`, look up each abstract in OpenAlex with
  \[fetch_abstracts()\] and include it in the entries. Needs internet
  access.

- api_key:

  Your OpenAlex API key, passed to \[fetch_abstracts()\]. Defaults to
  the \`OPENALEX_API_KEY\` environment variable.

## Value

A character vector with one BibTeX entry per result (invisibly when
\`output\` is given).

## Details

The entries only contain what the results list shows (no volume, pages,
DOI or abstract). For complete records use Scholar's Cite \> BibTeX.

## Examples

``` r
page <- '<div class="gs_r"><div class="gs_ri">
  <h3 class="gs_rt"><a href="https://example.org/a">Retention and advising</a></h3>
  <div class="gs_a">A Smith, B Jones - Journal of Examples, 2019 - Example Press</div>
  </div></div>'
cat(scholar_html_to_bib(page))
#> @article{smith2019retention,
#>   author    = {Smith, A. and Jones, B.},
#>   title     = {{Retention and advising}},
#>   journal   = {Journal of Examples},
#>   year      = 2019,
#>   publisher = {Example Press},
#>   url       = {https://example.org/a}
#> }
```
