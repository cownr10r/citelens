# ---------------------------------------------------------------------------
# Co-authorship networks
# ---------------------------------------------------------------------------

.require_igraph <- function() {
  if (!requireNamespace("igraph", quietly = TRUE)) {
    stop("Package 'igraph' is required for this function. Install it with ",
         "install.packages(\"igraph\").", call. = FALSE)
  }
}

.check_network <- function(x) {
  if (!inherits(x, "citelens_network")) {
    stop("`x` must be an object from author_network().", call. = FALSE)
  }
}

#' Co-authorship network analysis
#'
#' Builds a weighted co-authorship network from a data frame of papers (authors
#' are the nodes, and there is an edge for every pair of authors who share a
#' paper, weighted by the number of shared papers) and computes statistics for
#' each author and for the network as a whole.
#'
#' Requires the igraph package, which is listed under Suggests.
#'
#' @param data A data frame with one row per paper, such as the result of
#'   [scholar_parse_html()] or [bib_to_df()].
#' @param authors Name of the column holding the author string, for example
#'   `"Barrick, M. R. and Mount, M. K."`. If there is no `authors` column but
#'   there is an `author` column (as from [bib_to_df()]), that one is used.
#' @param cites Name of the column with citation counts. Missing values count as
#'   0, and a missing column means every paper has 0.
#' @param title Name of the column with titles. Rows with no title are dropped.
#' @param sep Regular expression separating authors. Default `"\\s+and\\s+"`.
#' @param seed Random seed for community detection (Louvain is stochastic).
#' @param min_component_papers Drop every cluster of connected authors that is
#'   supported by fewer than this many papers. The default `1` keeps everything;
#'   `2` removes clusters that come from a single paper (including single-author
#'   papers). The filter is applied before any statistics are computed, so all
#'   metrics, communities and component IDs describe the filtered network.
#' @param dedupe Remove duplicate listings of the same paper before building the
#'   network (see [find_duplicate_papers()]). Default `TRUE`: the less-cited copy
#'   of each duplicated paper is dropped, a message says which, and the rows
#'   removed are kept in `$duplicates`. Use `FALSE` to keep every row.
#' @param dedupe_max_dist Title edit-distance tolerance for the duplicate check,
#'   as a share of title length. Default 0.08.
#'
#' @return An object of class `citelens_network`, a list with:
#' \describe{
#'   \item{graph}{The igraph object, with node attributes.}
#'   \item{nodes}{Data frame, one row per author: `n_papers`, `total_citations`
#'     (full credit for each paper), `degree` (distinct co-authors), `strength`
#'     (sum of edge weights), `betweenness`, `closeness` (within the author's
#'     component), `eigenvector`, `component`, `community`. Sorted by `strength`,
#'     then `betweenness`.}
#'   \item{edges}{Data frame of author pairs with `weight` (shared papers).}
#'   \item{summary}{One-row data frame of network-level statistics.}
#'   \item{communities}{Data frame summarising each Louvain community.}
#'   \item{components}{One row per connected component: `component` id (as drawn
#'     on the plots), `n_authors`, `n_papers`, `total_citations`, `authors`, and
#'     the most-cited paper in it (`top_paper`).}
#'   \item{duplicates}{Rows dropped as duplicate listings, or `NULL`.}
#' }
#' @details
#' Because every paper's author list forms a clique, a collection of unrelated
#' papers produces many small disconnected components. Betweenness is non-zero
#' only for authors who bridge others *within* a component. Communities are found
#' with Louvain on the edge weights. When the network is mostly disconnected,
#' communities coincide with components and `modularity` is trivially close to 1;
#' interpret them accordingly.
#'
#' Google Scholar shortens long author lists with "...", so the authors at the
#' end of a long list are missing from [scholar_parse_html()] results, and
#' collaborations involving them are not seen.
#' @seealso [plot.citelens_network()], [plot_cluster()], [plot_clusters()],
#'   [cluster_maps()], [find_duplicate_papers()]
#' @examples
#' if (requireNamespace("igraph", quietly = TRUE)) {
#'   f <- system.file("extdata", "sample_authors.csv", package = "citelens")
#'   papers <- read.csv(f, stringsAsFactors = FALSE)
#'   net <- author_network(papers)
#'   net
#'   net$components
#'   plot(net)
#' }
#' @export
author_network <- function(data, authors = "authors", cites = "cited_by",
                           title = "title", sep = "\\s+and\\s+", seed = 1,
                           min_component_papers = 1, dedupe = TRUE,
                           dedupe_max_dist = 0.08) {
  .require_igraph()
  if (!is.data.frame(data)) stop("`data` must be a data frame.", call. = FALSE)
  acol <- .author_column(data, authors)
  if (is.null(acol)) {
    stop("Column '", authors, "' not found in `data`.", call. = FALSE)
  }
  if (!is.numeric(min_component_papers) || length(min_component_papers) != 1 ||
      min_component_papers < 1) {
    stop("`min_component_papers` must be a number of at least 1.", call. = FALSE)
  }

  # duplicate listings of one paper make authors look like repeat partners
  dup_dropped <- NULL
  if (isTRUE(dedupe) && title %in% names(data)) {
    dd <- find_duplicate_papers(data, title = title, authors = acol, cites = cites,
                                sep = sep, max_dist = dedupe_max_dist)
    if (any(!dd$keep)) {
      dup_dropped <- dd[!dd$keep, , drop = FALSE]
      message("Dropped ", nrow(dup_dropped), " duplicate paper listing(s): row ",
              paste(dup_dropped$row, collapse = ", "),
              ". Use dedupe = FALSE to keep them; see $duplicates.")
      data <- data[-dup_dropped$row, , drop = FALSE]
    }
  }

  cit <- if (cites %in% names(data)) suppressWarnings(as.numeric(data[[cites]])) else rep(0, nrow(data))
  cit[is.na(cit)] <- 0
  ok <- !is.na(data[[acol]]) & nzchar(trimws(data[[acol]]))
  if (title %in% names(data)) ok <- ok & !is.na(data[[title]])
  auth <- strsplit(as.character(data[[acol]][ok]), sep)
  cit <- cit[ok]
  ptitle <- if (title %in% names(data)) {
    gsub("\\s+", " ", trimws(as.character(data[[title]][ok])))
  } else {
    rep(NA_character_, sum(ok))
  }

  auth <- lapply(auth, function(a) {
    a <- trimws(gsub("\u2026|\\.\\.\\.", "", a))   # drop Scholar's "..." markers
    unique(a[nzchar(a)])
  })

  # optionally drop clusters supported by too few papers
  if (min_component_papers > 1) {
    pid <- seq_along(auth)
    bp <- data.frame(a = unlist(auth, use.names = FALSE),
                     p = paste0("\r", rep(pid, lengths(auth))), stringsAsFactors = FALSE)
    gb <- igraph::graph_from_data_frame(bp, directed = FALSE)
    cmb <- igraph::components(gb)
    pm <- unname(cmb$membership[paste0("\r", pid)])        # component of each paper
    n_p <- table(pm)
    keep_p <- !is.na(pm) & as.integer(n_p[as.character(pm)]) >= min_component_papers
    message("Dropped ", sum(!keep_p), " paper(s) in clusters supported by fewer than ",
            min_component_papers, " papers.")
    auth <- auth[keep_p]
    cit <- cit[keep_p]
    ptitle <- ptitle[keep_p]
    if (!length(auth)) stop("No clusters left after filtering.", call. = FALSE)
  }

  # node table: papers and citation credit
  all_auth <- unlist(auth, use.names = FALSE)
  paper_id <- rep(seq_along(auth), lengths(auth))
  n_papers <- tapply(paper_id, all_auth, length)
  tot_cite <- tapply(cit[paper_id], all_auth, sum)

  # edge list: every pair within a paper
  pairs <- do.call(rbind, lapply(auth, function(a) {
    if (length(a) < 2) return(NULL)
    t(utils::combn(sort(a), 2))
  }))
  if (is.null(pairs)) stop("No papers with two or more authors.", call. = FALSE)
  key <- paste(pairs[, 1], pairs[, 2], sep = "\r")
  w <- table(key)
  sp <- strsplit(names(w), "\r", fixed = TRUE)
  edges <- data.frame(from = vapply(sp, `[`, "", 1), to = vapply(sp, `[`, "", 2),
                      weight = as.integer(w), stringsAsFactors = FALSE, row.names = NULL)
  edges <- edges[order(-edges$weight, edges$from, edges$to), ]
  rownames(edges) <- NULL

  g <- igraph::graph_from_data_frame(
    edges, directed = FALSE,
    vertices = data.frame(name = names(n_papers), stringsAsFactors = FALSE)
  )

  # metrics
  comp <- igraph::components(g)
  set.seed(seed)
  comm <- igraph::cluster_louvain(g, weights = igraph::E(g)$weight)

  nodes <- data.frame(
    author          = igraph::V(g)$name,
    n_papers        = as.integer(n_papers[igraph::V(g)$name]),
    total_citations = as.numeric(tot_cite[igraph::V(g)$name]),
    degree          = igraph::degree(g),
    strength        = igraph::strength(g, weights = igraph::E(g)$weight),
    betweenness     = round(igraph::betweenness(g, weights = NA, normalized = FALSE), 2),
    closeness       = round(suppressWarnings(igraph::closeness(g, weights = NA, normalized = TRUE)), 4),
    eigenvector     = round(igraph::eigen_centrality(g, weights = NA)$vector, 4),
    component       = as.integer(comp$membership),
    community       = as.integer(igraph::membership(comm)),
    stringsAsFactors = FALSE, row.names = NULL
  )
  nodes$closeness[is.nan(nodes$closeness)] <- 0
  nodes <- nodes[order(-nodes$strength, -nodes$betweenness, -nodes$total_citations), ]
  rownames(nodes) <- NULL

  giant_id <- which.max(comp$csize)
  gg <- igraph::induced_subgraph(g, which(comp$membership == giant_id))
  net_summary <- data.frame(
    n_papers          = sum(lengths(auth) > 0),
    n_authors         = igraph::vcount(g),
    n_edges           = igraph::ecount(g),
    density           = signif(igraph::edge_density(g), 3),
    mean_degree       = round(mean(igraph::degree(g)), 2),
    n_components      = comp$no,
    largest_component = max(comp$csize),
    pct_in_largest    = round(100 * max(comp$csize) / igraph::vcount(g), 1),
    transitivity      = round(igraph::transitivity(g, type = "global"), 3),
    mean_distance_gc  = round(igraph::mean_distance(gg, weights = NA), 2),
    diameter_gc       = igraph::diameter(gg, weights = NA),
    n_communities     = length(comm),
    modularity        = round(igraph::modularity(comm), 3),
    stringsAsFactors = FALSE
  )

  cs <- split(nodes, nodes$community)
  communities <- do.call(rbind, lapply(names(cs), function(k) {
    x <- cs[[k]]
    data.frame(community = as.integer(k), size = nrow(x),
               total_citations = sum(x$total_citations),
               top_authors = paste(utils::head(x$author, 3), collapse = "; "),
               stringsAsFactors = FALSE)
  }))
  communities <- communities[order(-communities$size, -communities$total_citations), ]
  rownames(communities) <- NULL

  # one row per connected component: who is in it and which paper(s) made it
  paper_comp <- vapply(auth, function(a) {
    if (length(a)) nodes$component[match(a[1], nodes$author)] else NA_integer_
  }, integer(1))
  comp_tab <- do.call(rbind, lapply(sort(unique(nodes$component)), function(k) {
    m <- nodes[nodes$component == k, ]
    pp <- which(paper_comp == k)
    data.frame(component = k, n_authors = nrow(m), n_papers = length(pp),
               total_citations = sum(cit[pp]),
               authors = paste(m$author, collapse = "; "),
               top_paper = if (length(pp)) ptitle[pp[which.max(cit[pp])]] else NA_character_,
               stringsAsFactors = FALSE)
  }))
  comp_tab <- comp_tab[order(-comp_tab$n_authors, -comp_tab$total_citations), ]
  rownames(comp_tab) <- NULL

  igraph::V(g)$component <- nodes$component[match(igraph::V(g)$name, nodes$author)]
  igraph::V(g)$community <- nodes$community[match(igraph::V(g)$name, nodes$author)]
  igraph::V(g)$strength  <- nodes$strength[match(igraph::V(g)$name, nodes$author)]

  structure(list(graph = g, nodes = nodes, edges = edges, summary = net_summary,
                 communities = communities, components = comp_tab,
                 duplicates = dup_dropped),
            class = "citelens_network")
}

#' @export
print.citelens_network <- function(x, n = 10, ...) {
  cat("Co-authorship network\n")
  print(x$summary, row.names = FALSE)
  cat("\nTop ", n, " authors by strength:\n", sep = "")
  print(utils::head(x$nodes[, c("author", "n_papers", "total_citations", "degree",
                                "strength", "betweenness", "community")], n),
        row.names = FALSE)
  invisible(x)
}

#' Plot a co-authorship network
#'
#' The default view is one page of small maps, one per group of authors who
#' published together: a single dot colour, equal-sized dots, every name shown,
#' orange lines for pairs who published together more than once and gray lines
#' for pairs who shared one paper (see [plot_clusters()]). Groups supported by
#' fewer than `min_papers` papers are left out and, if more than `max_panels`
#' qualify, the ones with the most papers are drawn.
#'
#' @param x An object from [author_network()].
#' @param type `"groups"` (default) for the page of small maps, or `"overview"`
#'   for the single combined plot with dots coloured by citations and sized by
#'   collaboration strength (see [plot_network_overview()]).
#' @param ... For `type = "groups"`: `min_papers`, `max_panels`, `components`,
#'   `ncol`, `core_only`, `seed`. For `type = "overview"`: `min_component`,
#'   `giant_only`, `label_top`.
#' @return `x`, invisibly.
#' @examples
#' if (requireNamespace("igraph", quietly = TRUE)) {
#'   f <- system.file("extdata", "sample_authors.csv", package = "citelens")
#'   net <- suppressMessages(author_network(read.csv(f, stringsAsFactors = FALSE)))
#'   plot(net)                      # the page of group maps
#'   plot(net, max_panels = 3)      # only the three groups with the most papers
#'   plot(net, type = "overview")   # the all-in-one plot
#' }
#' @export
plot.citelens_network <- function(x, type = c("groups", "overview"), ...) {
  type <- match.arg(type)
  .check_network(x)
  if (type == "groups") plot_clusters(x, ...) else plot_network_overview(x, ...)
  invisible(x)
}

#' Overview plot of the whole network (dots coloured by citations)
#'
#' Collections of unrelated papers give many tiny disconnected components, so by
#' default only components with at least `min_component` authors are drawn.
#'
#' @param x An object from [author_network()].
#' @param min_component Smallest component (in authors) to draw. Default 3.
#' @param giant_only Plot only the largest connected component.
#' @param label_top Label this many authors with the highest strength.
#' @param ... Ignored.
#' @return `x`, invisibly.
#' @examples
#' if (requireNamespace("igraph", quietly = TRUE)) {
#'   f <- system.file("extdata", "sample_authors.csv", package = "citelens")
#'   net <- suppressMessages(author_network(read.csv(f, stringsAsFactors = FALSE)))
#'   plot_network_overview(net, label_top = 8)
#' }
#' @export
plot_network_overview <- function(x, min_component = 3, giant_only = FALSE,
                                  label_top = 15, ...) {
  .require_igraph()
  .check_network(x)
  g <- x$graph
  cm <- igraph::components(g)
  keep <- if (giant_only) {
    cm$membership == which.max(cm$csize)
  } else {
    cm$csize[cm$membership] >= min_component
  }
  if (!any(keep)) {
    stop("No component has ", min_component, " or more authors. Lower `min_component`.",
         call. = FALSE)
  }
  g <- igraph::induced_subgraph(g, which(keep))

  # Lay out each component on its own, then pack them on a grid with clear gaps
  # so separate components never look connected.
  cmg <- igraph::components(g)
  ord <- order(-cmg$csize)
  subs <- lapply(ord, function(i) igraph::induced_subgraph(g, which(cmg$membership == i)))
  ncol <- ceiling(sqrt(length(subs)))
  maxn <- max(cmg$csize)
  lays <- lapply(seq_along(subs), function(i) {
    sg <- subs[[i]]
    l <- if (igraph::vcount(sg) < 3) igraph::layout_in_circle(sg) else igraph::layout_with_kk(sg)
    l <- scale(l, center = TRUE, scale = FALSE)
    r <- max(abs(l))
    if (!is.finite(r) || r == 0) r <- 1
    l <- l / r * (0.22 + 0.2 * sqrt(igraph::vcount(sg) / maxn))   # radius within a 1x1 cell
    cbind(l[, 1] + ((i - 1) %% ncol), l[, 2] - ((i - 1) %/% ncol))
  })
  lay <- do.call(rbind, lays)
  gg <- igraph::disjoint_union(subs)

  cit <- x$nodes$total_citations[match(igraph::V(gg)$name, x$nodes$author)]
  str_ <- x$nodes$strength[match(igraph::V(gg)$name, x$nodes$author)]
  ramp <- grDevices::hcl.colors(100, "YlOrRd", rev = TRUE)
  lc <- log10(1 + cit)
  col <- ramp[pmax(1, pmin(100, 1 + round(99 * lc / max(max(lc), 1e-9))))]
  top <- utils::head(x$nodes$author[x$nodes$author %in% igraph::V(gg)$name], label_top)
  lab <- ifelse(igraph::V(gg)$name %in% top, igraph::V(gg)$name, NA)

  op <- graphics::par(mar = c(1.5, 0.5, 2.5, 0.5))
  on.exit(graphics::par(op), add = TRUE)
  igraph::plot.igraph(
    gg, layout = lay, rescale = TRUE,
    vertex.size = 3 + 1.6 * sqrt(str_),
    vertex.color = col, vertex.frame.color = "grey30", vertex.frame.width = 0.5,
    vertex.label = lab, vertex.label.cex = 0.6, vertex.label.color = "black",
    vertex.label.family = "sans", vertex.label.dist = 0.7, vertex.label.degree = -pi / 2,
    edge.width = 0.8 + 1.5 * (igraph::E(gg)$weight - 1), edge.color = "grey50",
    main = sprintf("Co-authorship network (%d of %d authors shown)",
                   igraph::vcount(gg), igraph::vcount(x$graph))
  )
  # component id above each cluster (matches x$components$component)
  ids <- vapply(subs, function(sg) igraph::V(sg)$component[1], integer(1))
  rl <- igraph::norm_coords(lay, -1, 1, -1, 1)   # same rescaling plot.igraph applies
  for (i in seq_along(subs)) {
    sel <- which(igraph::V(gg)$name %in% igraph::V(subs[[i]])$name)
    graphics::text(min(rl[sel, 1]) - 0.03, max(rl[sel, 2]) + 0.15, paste0("#", ids[i]),
                   cex = 0.6, col = "grey35", adj = c(0, 0.5), font = 2)
  }
  graphics::mtext(paste("Size = collaboration strength | colour = total citations of the",
                        "author's papers (log) | thick edge = repeat collaboration"),
                  side = 1, line = 0, cex = 0.6, col = "grey30")
  invisible(x)
}

#' Draw one co-author cluster as a node-and-line map
#'
#' Each author is a dot (bigger means more papers). A line joins two authors who
#' share a paper: thin gray for one shared paper, thick orange for two or more,
#' with the number of shared papers printed on the line. Labels are placed on the
#' side of each dot away from its co-authors so they rarely sit on a line. Uses
#' base graphics; needs igraph for the layout.
#'
#' @param x An object from [author_network()]. For clusters supported by two or
#'   more papers, build it with `author_network(data, min_component_papers = 2)`.
#' @param component Cluster ID, as shown on `plot(x)` and in
#'   `x$components$component`.
#' @param seed Random seed for the layout. Change it to get a different
#'   arrangement of the same cluster (the arrangement has no meaning; only the
#'   connections do).
#' @param main Title. The default builds one from the components table.
#' @param label_cex Label size. Default 0.9 (1.2 when `simple = TRUE`).
#' @param core_only Show only authors on two or more papers, and note how many
#'   one-paper co-authors are hidden. Fewer dots, easier for a general audience.
#' @param simple Larger dots and labels and a one-line key. Meant for slides.
#' @param uniform Draw every dot the same size (default `TRUE` when `simple`).
#' @param key Draw the key under the map. Default `TRUE`.
#' @return Invisibly, a data frame of the authors drawn with their `x` and `y`
#'   positions.
#' @examples
#' if (requireNamespace("igraph", quietly = TRUE)) {
#'   f <- system.file("extdata", "sample_authors.csv", package = "citelens")
#'   net <- suppressMessages(author_network(read.csv(f, stringsAsFactors = FALSE),
#'                                          min_component_papers = 2))
#'   net$components
#'   plot_cluster(net, net$components$component[1])
#' }
#' @export
plot_cluster <- function(x, component, seed = 1, main = NULL, label_cex = 0.9,
                         core_only = FALSE, simple = FALSE, uniform = simple, key = TRUE) {
  .require_igraph()
  .check_network(x)
  nd <- x$nodes[x$nodes$component == component, , drop = FALSE]
  if (!nrow(nd)) {
    stop("No cluster with ID ", component, ". See x$components$component.", call. = FALSE)
  }
  n_hidden <- 0
  if (core_only) {   # keep authors on 2+ papers; the rest are one-off co-authors
    core <- nd$n_papers >= 2
    if (sum(core) >= 2) {
      n_hidden <- sum(!core)
      nd <- nd[core, , drop = FALSE]
    } else {
      warning("Fewer than two authors have 2+ papers; showing everyone.", call. = FALSE)
    }
  }
  if (simple && missing(label_cex)) label_cex <- 1.2
  ed <- x$edges[x$edges$from %in% nd$author & x$edges$to %in% nd$author, , drop = FALSE]
  n <- nrow(nd)
  ix <- function(a) match(a, nd$author)

  # layout: force-directed, with heavier edges pulling tighter
  set.seed(seed)
  if (n == 1) {
    xy <- cbind(0, 0)
  } else {
    g <- igraph::graph_from_data_frame(
      data.frame(from = ed$from, to = ed$to, weight = ed$weight),
      directed = FALSE, vertices = data.frame(name = nd$author))
    xy <- igraph::layout_with_fr(g, weights = ed$weight, niter = 1000)
    xy <- xy[match(nd$author, igraph::V(g)$name), , drop = FALSE]
  }
  if (n == 2) xy <- rbind(c(-1, 0), c(1, 0))
  xy <- scale(xy, center = TRUE, scale = FALSE)
  rg <- apply(xy, 2, function(v) diff(range(v)))
  rg[rg == 0] <- 1
  xy[, 1] <- xy[, 1] / rg[1] * 2        # x spans about -1..1
  xy[, 2] <- xy[, 2] / rg[2] * 1.2      # y spans about -0.6..0.6

  # side for each label: away from the author's co-authors
  lean <- vapply(seq_len(n), function(i) {
    nb <- c(ix(ed$to[ed$from == nd$author[i]]), ix(ed$from[ed$to == nd$author[i]]))
    if (length(nb)) mean(xy[nb, 1]) - xy[i, 1] else 0
  }, numeric(1))
  right <- ifelse(abs(lean) > 0.08, lean < 0, xy[, 1] > 0)   # TRUE = label to the right

  col_node <- "#2a78d6"
  col_rep <- "#eb6834"
  col_one <- "#b9b8b1"
  op <- graphics::par(mar = if (key) c(3.2, 0.5, 3.2, 0.5) else c(0.5, 0.5, 2.8, 0.5), xpd = NA)
  on.exit(graphics::par(op), add = TRUE)

  cex_node <- if (uniform) {
    rep(if (simple) 3 else 2.4, n)
  } else {
    (1.6 + 0.55 * pmin(nd$n_papers, 7)) * if (simple) 1.3 else 1
  }
  graphics::plot.new()
  graphics::plot.window(xlim = c(-1.3, 1.3), ylim = c(-0.75, 0.75))   # provisional, to measure text
  # widen the x range so the longest labels are not clipped (two passes, since
  # text widths are measured in user units)
  for (pass in 1:2) {
    w <- graphics::strwidth(nd$author, cex = label_cex) + 0.06
    xl <- range(c(xy[, 1] - ifelse(right, 0, w), xy[, 1] + ifelse(right, w, 0)))
    xl <- c(min(xl[1], -1) - 0.08, max(xl[2], 1) + 0.08)
    graphics::plot.window(xlim = xl, ylim = c(-0.75, 0.75))
  }

  # edges
  if (nrow(ed)) {
    a <- ix(ed$from)
    b <- ix(ed$to)
    o <- order(ed$weight)                       # draw thick ones last
    graphics::segments(xy[a[o], 1], xy[a[o], 2], xy[b[o], 1], xy[b[o], 2],
                       col = ifelse(ed$weight[o] >= 2, col_rep, col_one),
                       lwd = ifelse(ed$weight[o] >= 2, pmin(2 + ed$weight[o] * 1.1, 9), 1.6),
                       lend = "round")
    rpt <- which(ed$weight >= 2)
    if (length(rpt)) {
      mx <- (xy[a[rpt], 1] + xy[b[rpt], 1]) / 2
      my <- (xy[a[rpt], 2] + xy[b[rpt], 2]) / 2
      graphics::symbols(mx, my, circles = rep(0.032, length(rpt)), inches = FALSE,
                        add = TRUE, bg = "white", fg = NA)
      graphics::text(mx, my, ed$weight[rpt], cex = 0.75, font = 2)
    }
  }

  # nodes and labels (white halo so text stays readable over lines)
  graphics::points(xy[, 1], xy[, 2], pch = 21, bg = col_node, col = "white", lwd = 2, cex = cex_node)
  gap <- graphics::xinch(0.5 * cex_node * graphics::par("cin")[2] * 0.75) + 0.02   # clear of the dot
  lx <- xy[, 1] + ifelse(right, gap, -gap)
  adj <- ifelse(right, 0, 1)
  dx <- graphics::strwidth("x", cex = label_cex) * 0.12
  dy <- graphics::strheight("x", cex = label_cex) * 0.25
  for (k in seq_len(n)) {
    for (ang in seq(0, 2 * pi, length.out = 9)[-9]) {
      graphics::text(lx[k] + dx * cos(ang), xy[k, 2] + dy * sin(ang), nd$author[k],
                     adj = c(adj[k], 0.5), cex = label_cex, col = "white")
    }
  }
  for (k in seq_len(n)) {
    graphics::text(lx[k], xy[k, 2], nd$author[k], adj = c(adj[k], 0.5), cex = label_cex)
  }

  # title and key
  if (is.null(main)) {
    cm <- x$components[x$components$component == component, ]
    main <- if (!nrow(cm)) {
      paste("Cluster", component)
    } else if (core_only) {   # the title describes the whole cluster, not just the dots drawn
      sprintf("Cluster %s: %d authors, %d papers", component, cm$n_authors[1], cm$n_papers[1])
    } else {
      sprintf("Cluster %s: %d authors, %d papers, %s citations", component, n, cm$n_papers[1],
              format(cm$total_citations[1], big.mark = ","))
    }
  }
  graphics::title(main = main, adj = 0, cex.main = 1.05, font.main = 2)
  usr <- graphics::par("usr")
  yk <- usr[3] - 0.04 * diff(usr[3:4])
  xk <- usr[1] + 0.01 * diff(usr[1:2])
  if (key && simple) {
    graphics::segments(xk, yk, xk + 0.12, yk, col = col_rep, lwd = 5, lend = "round")
    graphics::text(xk + 0.15, yk, "published together more than once (number = papers)",
                   adj = c(0, 0.5), cex = 0.9)
    if (n_hidden) {
      graphics::text(usr[2], yk,
                     sprintf("+%d author%s on one paper not shown", n_hidden,
                             if (n_hidden == 1) "" else "s"),
                     adj = c(1, 0.5), cex = 0.9, col = "grey35")
    }
  } else if (key) {
    txt <- "wrote 2+ papers together (number = how many)"
    graphics::segments(xk, yk, xk + 0.12, yk, col = col_rep, lwd = 5, lend = "round")
    graphics::text(xk + 0.15, yk, txt, adj = c(0, 0.5), cex = 0.75)
    xk2 <- xk + 0.15 + graphics::strwidth(txt, cex = 0.75) + 0.1
    graphics::segments(xk2, yk, xk2 + 0.12, yk, col = col_one, lwd = 2, lend = "round")
    graphics::text(xk2 + 0.15, yk, "wrote 1 paper together", adj = c(0, 0.5), cex = 0.75)
    graphics::text(usr[2], yk, "bigger dot = more papers", adj = c(1, 0.5), cex = 0.75, col = "grey35")
  }

  invisible(data.frame(author = nd$author, n_papers = nd$n_papers,
                       x = xy[, 1], y = xy[, 2], stringsAsFactors = FALSE))
}

#' Several clusters on one page
#'
#' Draws each cluster as a small map in one figure: one dot colour, equal-sized
#' dots, every name shown, and an orange line where two authors published
#' together more than once (the number is how many papers). Each panel is named
#' after the author with the most papers in that group. A single key at the
#' bottom explains the lines.
#'
#' @param x An object from [author_network()].
#' @param components Cluster IDs to draw. Default: every cluster with two or more
#'   authors and at least `min_papers` papers, those with the most papers first
#'   (at most `max_panels`).
#' @param ncol Panels per row. Default: 2 when there are 2 to 4 clusters, 3 for
#'   more.
#' @param max_panels Most panels on one page. Default 6.
#' @param min_papers Only clusters supported by at least this many papers
#'   (default 2) are drawn, so one-paper author lists don't fill the page. When
#'   more clusters qualify than fit, the ones with the most papers are shown.
#' @param core_only Passed to [plot_cluster()]: drop one-paper co-authors.
#' @param seed Layout seed, as in [plot_cluster()].
#' @return Invisibly, the cluster IDs drawn.
#' @examples
#' if (requireNamespace("igraph", quietly = TRUE)) {
#'   f <- system.file("extdata", "sample_authors.csv", package = "citelens")
#'   net <- suppressMessages(author_network(read.csv(f, stringsAsFactors = FALSE)))
#'   plot_clusters(net)
#' }
#' @export
plot_clusters <- function(x, components = NULL, ncol = NULL, max_panels = 6, min_papers = 2,
                          core_only = FALSE, seed = 1) {
  .require_igraph()
  .check_network(x)
  cm <- x$components
  if (is.null(components)) {
    cm <- cm[cm$n_authors >= 2 & cm$n_papers >= min_papers, , drop = FALSE]
    if (!nrow(cm)) {
      stop("No cluster has ", min_papers, "+ papers and 2+ authors.", call. = FALSE)
    }
    n_all <- nrow(cm)
    cm <- utils::head(cm[order(-cm$n_papers, -cm$total_citations), , drop = FALSE], max_panels)
    cm <- cm[order(-cm$n_authors, -cm$n_papers), , drop = FALSE]      # biggest group first
    components <- cm$component
    if (n_all > length(components)) {
      message("Showing the ", length(components), " groups with the most papers (of ", n_all,
              " with ", min_papers, "+ papers). Use max_panels = or components = to change.")
    }
  }
  k <- length(components)
  if (!k) stop("No clusters to draw.", call. = FALSE)
  if (is.null(ncol)) ncol <- if (k <= 4) min(k, 2) else 3
  nrow_ <- ceiling(k / ncol)

  op <- graphics::par(no.readonly = TRUE)
  on.exit({
    graphics::layout(1)
    graphics::par(op)
  }, add = TRUE)
  if (k == 3 && ncol == 2) {              # biggest cluster gets the full top row
    graphics::layout(matrix(c(1, 1, 2, 3), 2, byrow = TRUE))
    graphics::par(oma = c(2.6, 0, 0, 0))
  } else {
    graphics::par(mfrow = c(nrow_, ncol), oma = c(2.6, 0, 0, 0))
  }
  sn <- function(a) sub(",.*$", "", a)
  for (cid in components) {
    nd <- x$nodes[x$nodes$component == cid, ]
    cr <- x$components[x$components$component == cid, ]
    ed <- x$edges[x$edges$from %in% nd$author & x$edges$to %in% nd$author, , drop = FALSE]
    na <- cr$n_authors[1]
    np <- cr$n_papers[1]
    if (nrow(ed) && max(ed$weight) >= 2) {       # name the strongest pair
      b <- ed[which.max(ed$weight), ]
      who <- sprintf("%s & %s", sn(b$from), sn(b$to))
      others <- na - 2
    } else {                                     # no repeat pair: name the author on the most papers
      who <- sn(nd$author[order(-nd$n_papers, -nd$strength)][1])
      others <- na - 1
    }
    ttl <- sprintf("%s (+%d co-author%s): %d papers", who, others,
                   if (others == 1) "" else "s", np)
    plot_cluster(x, cid, seed = seed, main = ttl, core_only = core_only,
                 uniform = TRUE, key = FALSE, label_cex = 0.95)
  }
  # one key for the whole page
  graphics::par(fig = c(0, 1, 0, 1), oma = c(0, 0, 0, 0), mar = c(0, 0, 0, 0),
                new = TRUE, xpd = NA)
  graphics::plot.new()
  graphics::plot.window(xlim = c(0, 1), ylim = c(0, 1))
  graphics::segments(0.02, 0.018, 0.06, 0.018, col = "#eb6834", lwd = 5, lend = "round")
  graphics::text(0.07, 0.018, "orange line = published together more than once (number = papers)",
                 adj = c(0, 0.5), cex = 0.95)
  graphics::segments(0.62, 0.018, 0.66, 0.018, col = "#b9b8b1", lwd = 2, lend = "round")
  graphics::text(0.67, 0.018, "gray line = published together once", adj = c(0, 0.5), cex = 0.95)
  invisible(components)
}

#' Write a map for every cluster
#'
#' Calls [plot_cluster()] for each cluster and saves one PNG file per cluster
#' and, optionally, a single multi-page PDF with all of them. Nothing is written
#' unless you give a `dir` or a `pdf`.
#'
#' @param x An object from [author_network()].
#' @param dir Folder for the PNG files (created if needed), or `NULL` for none.
#' @param pdf File name for the combined PDF, or `NULL` for none.
#' @param min_authors Skip clusters with fewer authors than this. Default 2.
#' @param order How to order the clusters in the PDF: `"citations"` (default),
#'   `"papers"`, `"authors"` or `"id"`.
#' @param width,height Size in inches. Default 8 by 5.
#' @param res PNG resolution. Default 150.
#' @return Invisibly, the vector of cluster IDs drawn.
#' @examples
#' if (requireNamespace("igraph", quietly = TRUE)) {
#'   f <- system.file("extdata", "sample_authors.csv", package = "citelens")
#'   net <- suppressMessages(author_network(read.csv(f, stringsAsFactors = FALSE),
#'                                          min_component_papers = 2))
#'   out <- tempfile("maps")
#'   cluster_maps(net, dir = out, pdf = file.path(tempdir(), "maps.pdf"))
#' }
#' @export
cluster_maps <- function(x, dir = NULL, pdf = NULL, min_authors = 2,
                         order = c("citations", "papers", "authors", "id"),
                         width = 8, height = 5, res = 150) {
  .require_igraph()
  .check_network(x)
  order <- match.arg(order)
  if (is.null(dir) && is.null(pdf)) {
    stop("Give a folder in `dir` for PNG files and/or a file name in `pdf`.", call. = FALSE)
  }
  cm <- x$components[x$components$n_authors >= min_authors, , drop = FALSE]
  cm <- cm[switch(order,
                  citations = base::order(-cm$total_citations),
                  papers    = base::order(-cm$n_papers, -cm$total_citations),
                  authors   = base::order(-cm$n_authors, -cm$total_citations),
                  id        = base::order(cm$component)), , drop = FALSE]
  ids <- cm$component
  if (!length(ids)) stop("No clusters to draw.", call. = FALSE)
  if (!is.null(dir)) {
    dir.create(dir, showWarnings = FALSE, recursive = TRUE)
    for (k in ids) {
      grDevices::png(file.path(dir, sprintf("cluster_%03d.png", k)), width = width,
                     height = height, units = "in", res = res)
      tryCatch(plot_cluster(x, k), finally = grDevices::dev.off())
    }
    message("Wrote ", length(ids), " PNG files to ", normalizePath(dir))
  }
  if (!is.null(pdf)) {
    if (isTRUE(capabilities("cairo"))) {   # handles accented names
      grDevices::cairo_pdf(pdf, width = width, height = height)
    } else {
      grDevices::pdf(pdf, width = width, height = height)
    }
    tryCatch(for (k in ids) plot_cluster(x, k), finally = grDevices::dev.off())
    message("Wrote ", pdf)
  }
  invisible(ids)
}
