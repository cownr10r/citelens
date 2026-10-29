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
