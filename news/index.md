# Changelog

## citelens (development version)

## citelens (development version)

### New functions

- [`abstract_ca()`](https://cownr10r.github.io/citelens/reference/abstract_ca.md)
  runs correspondence analysis on the terms in abstracts, comparing
  groups such as periods, venues or sources. It comes with
  [`plot()`](https://rdrr.io/r/graphics/plot.default.html) and
  [`print()`](https://rdrr.io/r/base/print.html) methods.

- [`author_network()`](https://cownr10r.github.io/citelens/reference/author_network.md)
  builds a weighted co-authorship network and reports author-level and
  network-level statistics, connected components and communities.
  [`plot()`](https://rdrr.io/r/graphics/plot.default.html) draws one
  small map per group of authors, or a single overview.
  [`plot_cluster()`](https://cownr10r.github.io/citelens/reference/plot_cluster.md),
  [`plot_clusters()`](https://cownr10r.github.io/citelens/reference/plot_clusters.md)
  and
  [`plot_network_overview()`](https://cownr10r.github.io/citelens/reference/plot_network_overview.md)
  draw individual views, and
  [`cluster_maps()`](https://cownr10r.github.io/citelens/reference/cluster_maps.md)
  saves maps for every cluster to PNG and PDF files. Nothing is written
  unless you supply `dir` or `pdf`.

- [`find_duplicate_papers()`](https://cownr10r.github.io/citelens/reference/find_duplicate_papers.md)
  and
  [`dedupe_papers()`](https://cownr10r.github.io/citelens/reference/dedupe_papers.md)
  flag and remove papers that are listed more than once, such as a
  journal version and a preprint. Matching uses normalised titles with
  optional edit-distance tolerance, and by default a pair must also
  share an author surname.

- [`citation_rank()`](https://cownr10r.github.io/citelens/reference/citation_rank.md)
  ranks papers, venues or authors by citations and reports the h-index,
  g-index and i10-index for the collection.

### Other changes

- [`author_network()`](https://cownr10r.github.io/citelens/reference/author_network.md)
  and
  [`citation_rank()`](https://cownr10r.github.io/citelens/reference/citation_rank.md)
  drop duplicate listings of the same paper by default (`dedupe = TRUE`)
  and report which rows were removed in `$duplicates`. Use
  `dedupe = FALSE` to keep every row.

- New vignette, “Getting started with citelens”.

- New sample data, `inst/extdata/sample_authors.csv`: a small synthetic
  set of papers used in examples and tests.

- igraph is now in Suggests. The network functions need it, and they
  give a clear error if it isn’t installed.

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
