# Parse a saved Google Scholar results page

Reads a Google Scholar search-results page that you saved from your
browser and pulls out what the results list shows for each hit: title,
authors, venue, year, publisher, link, snippet, citation count and
number of versions. It parses the page's HTML/XML with the xml2 package;
it does \*\*not\*\* contact Google Scholar, which blocks automated
requests and whose terms do not allow them.

## Usage

``` r
scholar_parse_html(input, recursive = FALSE, flatten = FALSE)
```

## Arguments

- input:

  One or more paths to saved \`.html\` files, \*\*a folder\*\* (every
  \`.html\` / \`.htm\` file in it is read), or a string of HTML text.
  Results from several pages are combined.

- recursive:

  If \`input\` is a folder, also read files in its subfolders.

- flatten:

  If \`TRUE\`, \`author_list\` is returned as text, with the authors of
  each result joined by \`"; "\`, instead of as a list column. Use this
  before saving the result with \[utils::write.csv()\] or
  \`writexl::write_xlsx()\`. Default \`FALSE\`.

## Value

A data frame with one row per result: \`source_file\` (the file it came
from), \`title\`, \`authors\` (as shown, with initials), \`author_list\`
(a list column of names), \`authors_truncated\`, \`venue\`,
\`venue_truncated\`, \`year\`, \`publisher\`, \`url\`, \`snippet\`,
\`cited_by\`, \`versions\` and \`cid\` (Scholar's internal id for the
result).

\`author_list\` is a list column unless you use \`flatten = TRUE\`. List
columns are not quoted by \[utils::write.csv()\], so the commas inside
names shift the other columns sideways in the saved file. Use \`flatten
= TRUE\` if you plan to save the result.

## Details

To save a page in Chrome or Safari: open the results, then File \> Save
Page As (choose "Webpage, HTML Only" or "Page Source"). Save each
results page you want as its own file.

The results list shortens long author lists and venue names with "...",
and does not show volume, pages or DOI. Entries affected are flagged in
\`authors_truncated\` and \`venue_truncated\`. For complete records, use
Scholar's \*\*Cite \> BibTeX\*\* (or \*\*My library \> Export\*\*)
instead.

## Examples

``` r
page <- '<div class="gs_r" data-cid="x1"><div class="gs_ri">
  <h3 class="gs_rt"><a href="https://example.org/a">Retention and <b>advising</b></a></h3>
  <div class="gs_a">A Smith, B Jones - Journal of Examples, 2019 - Example Press</div>
  <div class="gs_fl"><a>Cite</a> <a>Cited by 12</a></div></div></div>'
scholar_parse_html(page)
#>   source_file                  title                 authors  author_list
#> 1        <NA> Retention and advising Smith, A. and Jones, B. Smith, A....
#>   authors_truncated               venue venue_truncated year     publisher
#> 1             FALSE Journal of Examples           FALSE 2019 Example Press
#>                     url snippet cited_by versions cid
#> 1 https://example.org/a    <NA>       12       NA  x1
scholar_parse_html(page, flatten = TRUE)$author_list
#> [1] "Smith, A.; Jones, B."
```
