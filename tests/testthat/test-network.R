skip_if_not_installed("igraph")

sample_papers <- function() {
  read.csv(system.file("extdata", "sample_authors.csv", package = "citelens"),
           stringsAsFactors = FALSE)
}

build_net <- function(...) suppressMessages(author_network(sample_papers(), ...))
build_net_from <- function(p) suppressMessages(author_network(p))

test_that("author_network builds the expected network", {
  net <- build_net()
  expect_s3_class(net, "citelens_network")
  expect_equal(net$summary$n_authors, 21)           # 21 distinct authors
  expect_equal(net$summary$n_papers, 17)            # 18 rows minus 1 duplicate
  w <- function(a, b) net$edges$weight[(net$edges$from == a & net$edges$to == b) |
                                         (net$edges$from == b & net$edges$to == a)]
  expect_equal(w("Alder, A.", "Birch, B."), 4)       # 4 papers together, duplicate not counted
  expect_equal(w("Hazel, H.", "Ivy, I."), 2)
  expect_equal(w("Birch, B.", "Cedar, C."), 2)
  expect_equal(net$nodes$author[1], "Birch, B.")     # highest strength
  expect_equal(nrow(net$duplicates), 1)
  expect_equal(net$duplicates$row, 7)
})

test_that("the components table is consistent with the nodes", {
  net <- build_net()
  cm <- net$components
  expect_equal(sum(cm$n_authors), nrow(net$nodes))
  expect_equal(sum(cm$n_papers), net$summary$n_papers)
  big <- cm[1, ]
  expect_equal(big$n_authors, 4)
  expect_equal(big$n_papers, 6)                      # rows 1-6; the duplicate (row 7) is gone
  expect_match(big$authors, "Alder, A.")
})

test_that("dedupe = FALSE keeps the duplicate and inflates the pair weight", {
  net <- build_net(dedupe = FALSE)
  expect_null(net$duplicates)
  e <- net$edges
  expect_equal(e$weight[e$from == "Alder, A." & e$to == "Birch, B."], 5)
})

test_that("min_component_papers removes clusters from a single paper", {
  expect_message(net <- author_network(sample_papers(), min_component_papers = 2),
                 "Dropped")
  expect_true(all(net$components$n_papers >= 2))
  expect_false("Oak, O." %in% net$nodes$author)
  expect_error(suppressMessages(author_network(sample_papers(), min_component_papers = 50)),
               "No clusters left")
})

test_that("the author column can be named author", {
  p <- sample_papers()
  names(p)[names(p) == "authors"] <- "author"
  expect_equal(build_net_from(p)$summary$n_authors, 21)
})

test_that("input problems give clear errors", {
  p <- sample_papers()
  expect_error(author_network(1:3), "data frame")
  expect_error(author_network(p, authors = "nope"), "not found")
  expect_error(suppressMessages(author_network(p[15, ])), "two or more authors")
  expect_error(author_network(p, min_component_papers = 0), "min_component_papers")
  expect_error(plot_clusters(list()), "author_network")
})

test_that("plots draw and leave graphics settings unchanged", {
  net <- build_net()
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off())
  before <- graphics::par("mar")
  expect_no_error(plot(net))
  expect_message(plot(net, max_panels = 1), "Showing the 1 groups")
  expect_no_error(plot(net, type = "overview"))
  expect_no_error(plot(net, type = "overview", giant_only = TRUE))
  id <- net$components$component[1]
  res <- plot_cluster(net, id)
  expect_equal(nrow(res), 4)
  expect_no_error(plot_cluster(net, id, core_only = TRUE, simple = TRUE))
  expect_error(plot_cluster(net, 999), "No cluster")
  expect_equal(graphics::par("mar"), before)
  expect_equal(graphics::par("mfrow"), c(1, 1))
})

test_that("cluster_maps writes files only when asked", {
  net <- suppressMessages(author_network(sample_papers(), min_component_papers = 2))
  expect_error(cluster_maps(net), "dir")
  d <- file.path(tempdir(), "maps_test")
  f <- file.path(tempdir(), "maps_test.pdf")
  expect_message(ids <- cluster_maps(net, dir = d, pdf = f, res = 50), "Wrote")
  expect_equal(length(list.files(d, pattern = "png$")), length(ids))
  expect_true(file.exists(f))
  unlink(c(d, f), recursive = TRUE)
})

test_that("print gives a short summary", {
  expect_output(print(build_net()), "Co-authorship network")
})
