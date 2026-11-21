# citelens (development version)

# citelens (development version)

## New functions

* `abstract_ca()` runs correspondence analysis on the terms in abstracts,
  comparing groups such as periods, venues or sources. It comes with `plot()`
  and `print()` methods.

* `author_network()` builds a weighted co-authorship network and reports
  author-level and network-level statistics, connected components and
  communities. `plot()` draws one small map per group of authors, or a single
  overview. `plot_cluster()`, `plot_clusters()` and `plot_network_overview()`
  draw individual views, and `cluster_maps()` saves maps for every cluster to
  PNG and PDF files. Nothing is written unless you supply `dir` or `pdf`.

* `find_duplicate_papers()` and `dedupe_papers()` flag and remove papers that
  are listed more than once, such as a journal version and a preprint. Matching
  uses normalised titles with optional edit-distance tolerance, and by default
  a pair must also share an author surname.

* `citation_rank()` ranks papers, venues or authors by citations and reports
  the h-index, g-index and i10-index for the collection.

## Other changes

* `author_network()` and `citation_rank()` drop duplicate listings of the same
  paper by default (`dedupe = TRUE`) and report which rows were removed in
  `$duplicates`. Use `dedupe = FALSE` to keep every row.

* New vignette, "Getting started with citelens".

* New sample data, `inst/extdata/sample_authors.csv`: a small synthetic set of
  papers used in examples and tests.

* igraph is now in Suggests. The network functions need it, and they give a
  clear error if it isn't installed.


# citelens 0.1.0

* Initial release.
* Convert 'RefWorks' Tagged Format and 'RIS' exports to 'BibTeX'
  (`convert_refworks()`, `refworks_to_xlsx()`), and read 'BibTeX' into a data
  frame or 'Excel' file (`bib_to_df()`).
* Parse saved 'Google Scholar' results pages, or a folder of them
  (`scholar_parse_html()`, `scholar_html_to_bib()`), and look up missing
  abstracts in 'OpenAlex' (`fetch_abstracts()`).
* Text analytics on abstracts: topic modeling (`topic_model()` and helpers),
  cosine document similarity with duplicate finding and 'Excel' export
  (`doc_similarity()`, `similarity_to_df()`), and trends over time
  (`word_trends()`, `topic_trends()`), with charts.
