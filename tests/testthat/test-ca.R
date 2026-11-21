sample_refs <- function() {
  bib_to_df(system.file("extdata", "sample_abstracts.bib", package = "citelens"))
}

# Four periods, each with its own vocabulary plus a shared vocabulary.
period_data <- function(per_period = 8, seed = 1) {
  set.seed(seed)
  groups <- list(
    early  = c("algorithm", "kernel", "vector", "matrix", "tensor", "lattice", "graph", "wavelet"),
    middle = c("orchard", "meadow", "harvest", "pasture", "granary", "furrow", "trellis", "hayloft"),
    late   = c("glacier", "tundra", "permafrost", "moraine", "fjord", "crevasse", "icefield", "sastrugi"),
    recent = c("telescope", "nebula", "quasar", "pulsar", "comet", "asteroid", "galaxy", "eclipse")
  )
  common <- c("bridge", "garden", "window", "harbor", "candle", "ribbon")
  years <- rep(c(2001, 2006, 2011, 2016), each = per_period)
  txt <- vapply(seq_along(years), function(i) {
    g <- groups[[(i - 1) %/% per_period + 1]]
    paste(c(sample(g, 30, replace = TRUE), sample(common, 15, replace = TRUE)), collapse = " ")
  }, character(1))
  list(data = data.frame(abstract = txt, year = as.character(years), stringsAsFactors = FALSE),
       groups = groups)
}

test_that("abstract_ca finds each period's own vocabulary", {
  pd <- period_data()
  ca <- abstract_ca(pd$data, breaks = c(2005, 2010, 2015), min_doc_freq = 3)
  expect_s3_class(ca, "citelens_ca")
  expect_equal(ca$periods$period, c("<2005", "2005-2009", "2010-2014", "2015+"))
  expect_equal(ca$periods$n_abstracts, rep(8L, 4))
  expect_equal(nrow(ca$eigen), 3)                       # periods - 1
  expect_equal(sum(ca$eigen$pct), 100, tolerance = 0.2)
  expect_equal(ca$chisq, ca$total_inertia * ca$n)
  # each period's 8 most distinctive words are exactly that period's own group;
  # the shared words come after them (lower lift)
  for (i in seq_along(pd$groups)) {
    d <- ca$distinctive[ca$distinctive$period == ca$periods$period[i], ]
    expect_setequal(d$term[1:8], pd$groups[[i]])
  }
})

test_that("default periods hold roughly equal numbers of abstracts", {
  pd <- period_data()
  ca <- abstract_ca(pd$data, n_periods = 4, min_doc_freq = 3)
  expect_equal(nrow(ca$periods), 4)
  expect_equal(sum(ca$periods$n_abstracts), 32)
  expect_true(all(ca$periods$n_abstracts >= 4))
})

test_that("n_dims limits the coordinates returned", {
  pd <- period_data()
  ca <- abstract_ca(pd$data, breaks = c(2005, 2010, 2015), min_doc_freq = 3, n_dims = 2)
  expect_true(all(c("Dim1", "Dim2", "ctr1", "ctr2") %in% names(ca$terms)))
  expect_false("Dim3" %in% names(ca$terms))
  expect_equal(nrow(ca$eigen), 3)                       # inertia is still reported for all
})

test_that("periods with no words are dropped with a message", {
  pd <- period_data()
  expect_message(
    ca <- abstract_ca(pd$data, breaks = c(1990, 2005, 2010, 2015), min_doc_freq = 3),
    "Dropped period"
  )
  expect_equal(nrow(ca$periods), 4)
  expect_false("<1990" %in% ca$periods$period)
})

test_that("year text such as 'Spring 2006' is understood", {
  pd <- period_data()
  pd$data$year <- paste("Spring", pd$data$year)
  ca <- abstract_ca(pd$data, breaks = c(2005, 2010, 2015), min_doc_freq = 3)
  expect_equal(nrow(ca$periods), 4)
})

test_that("abstract_ca works on the bundled sample", {
  refs <- sample_refs()
  filler <- c("note", "time", "follow", "shape", "touch", "studied", "evidence",
              "work", "attention", "discussion")
  ca <- abstract_ca(refs, breaks = c(2017, 2020), stopwords = filler, min_doc_freq = 3)
  expect_s3_class(ca, "citelens_ca")
  expect_equal(nrow(ca$periods), 3)
  expect_equal(ca$n_docs, 30)
  expect_output(print(ca), "Correspondence analysis")
})

test_that("input problems give clear errors", {
  pd <- period_data()
  expect_error(abstract_ca(1:3), "data frame")
  expect_error(abstract_ca(pd$data, text = "nope"), "not found")
  expect_error(abstract_ca(pd$data, year = "nope"), "not found")
  expect_error(abstract_ca(pd$data[1:10, ]), "Fewer than 20")
  expect_error(abstract_ca(pd$data, breaks = "a"), "`breaks`")
  expect_error(abstract_ca(pd$data, breaks = NULL, n_periods = 1), "n_periods")
  expect_error(abstract_ca(pd$data, min_doc_freq = 1000), "Lower `min_doc_freq`")
})

test_that("the plot draws and leaves graphics settings unchanged", {
  pd <- period_data()
  ca <- abstract_ca(pd$data, breaks = c(2005, 2010, 2015), min_doc_freq = 3)
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off())
  before <- graphics::par("mar")
  expect_no_error(plot(ca))
  expect_no_error(plot(ca, dims = c(1, 3), n_terms = 10))
  expect_equal(graphics::par("mar"), before)
})

test_that("plot asks for two dimensions when only one exists", {
  pd <- period_data()
  ca <- abstract_ca(pd$data, breaks = 2008, min_doc_freq = 3)   # two periods, one dimension
  expect_equal(nrow(ca$eigen), 1)
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off())
  expect_error(plot(ca), "dimension")
})
