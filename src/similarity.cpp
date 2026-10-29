// similarity.cpp
// Pairwise cosine similarity between sparse weighted documents.
// The user-facing function is doc_similarity() in R/similarity.R.

#include <Rcpp.h>

#include <cmath>
#include <utility>
#include <vector>

//' Cosine similarity of sparse document vectors (internal)
//'
//' @param ids List of integer vectors of 0-based word ids (each id at most once per document).
//' @param weights List of numeric vectors, the weight of each word in the matching `ids`.
//' @param V Vocabulary size.
//' @return A D x D numeric matrix of cosine similarities (NA for documents with no weight).
//' @noRd
// [[Rcpp::export]]
Rcpp::NumericMatrix cosine_sparse_cpp(Rcpp::List ids, Rcpp::List weights, int V) {
    const int D = static_cast<int>(ids.size());
    if (weights.size() != D) Rcpp::stop("`ids` and `weights` must have the same length.");

    std::vector<double> norm(D, 0.0);
    std::vector<std::vector<std::pair<int, double>>> postings(V);

    for (int d = 0; d < D; ++d) {
        Rcpp::IntegerVector wid = ids[d];
        Rcpp::NumericVector wt = weights[d];
        if (wid.size() != wt.size()) Rcpp::stop("Word ids and weights differ in length.");
        double ss = 0.0;
        for (R_xlen_t i = 0; i < wid.size(); ++i) {
            const int w = wid[i];
            if (w < 0 || w >= V) Rcpp::stop("Word id out of range.");
            postings[w].emplace_back(d, wt[i]);
            ss += wt[i] * wt[i];
        }
        norm[d] = std::sqrt(ss);
    }

    Rcpp::NumericMatrix sim(D, D);
    // dot products through the inverted index: only documents sharing a word are touched
    for (int v = 0; v < V; ++v) {
        if ((v & 1023) == 0) Rcpp::checkUserInterrupt();
        const auto& p = postings[v];
        for (size_t a = 0; a < p.size(); ++a) {
            for (size_t b = a; b < p.size(); ++b) {
                const double x = p[a].second * p[b].second;
                sim(p[a].first, p[b].first) += x;
                if (a != b) sim(p[b].first, p[a].first) += x;
            }
        }
    }

    for (int i = 0; i < D; ++i) {
        for (int j = 0; j < D; ++j) {
            if (norm[i] == 0.0 || norm[j] == 0.0) {
                sim(i, j) = NA_REAL;
            } else {
                double s = sim(i, j) / (norm[i] * norm[j]);
                if (s > 1.0) s = 1.0;  // rounding
                sim(i, j) = s;
            }
        }
    }
    return sim;
}
