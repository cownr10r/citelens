# Changelog

## citelens 0.1.0

CRAN release: 2026-11-14

- Initial release.
- Convert ‘RefWorks’ Tagged Format and ‘RIS’ exports to ‘BibTeX’
  ([`convert_refworks()`](https://cownr10r.github.io/citelens/reference/convert_refworks.md),
  [`refworks_to_xlsx()`](https://cownr10r.github.io/citelens/reference/refworks_to_xlsx.md)),
  and read ‘BibTeX’ into a data frame or ‘Excel’ file
  ([`bib_to_df()`](https://cownr10r.github.io/citelens/reference/bib_to_df.md)).
- Parse saved ‘Google Scholar’ results pages, or a folder of them
  ([`scholar_parse_html()`](https://cownr10r.github.io/citelens/reference/scholar_parse_html.md),
  [`scholar_html_to_bib()`](https://cownr10r.github.io/citelens/reference/scholar_html_to_bib.md)),
  and look up missing abstracts in ‘OpenAlex’
  ([`fetch_abstracts()`](https://cownr10r.github.io/citelens/reference/fetch_abstracts.md)).
- Text analytics on abstracts: topic modeling
  ([`topic_model()`](https://cownr10r.github.io/citelens/reference/topic_model.md)
  and helpers), cosine document similarity with duplicate finding and
  ‘Excel’ export
  ([`doc_similarity()`](https://cownr10r.github.io/citelens/reference/doc_similarity.md),
  [`similarity_to_df()`](https://cownr10r.github.io/citelens/reference/similarity_to_df.md)),
  and trends over time
  ([`word_trends()`](https://cownr10r.github.io/citelens/reference/word_trends.md),
  [`topic_trends()`](https://cownr10r.github.io/citelens/reference/topic_trends.md)),
  with charts.
