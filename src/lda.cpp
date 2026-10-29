// lda.cpp
// Latent Dirichlet Allocation fitted by collapsed Gibbs sampling.
// The user-facing function is topic_model() in R/topics.R.
//
// Uses R's random number generator, so set.seed() in R makes a fit reproducible.

#include <Rcpp.h>

#include <cmath>
#include <vector>

//' Collapsed Gibbs sampler for LDA (internal)
//'
//' @param docs List of integer vectors holding 0-based word ids, one vector per document.
//' @param V Vocabulary size.
//' @param K Number of topics.
//' @param alpha Symmetric Dirichlet prior on each document's topic mixture.
//' @param beta Symmetric Dirichlet prior on each topic's word distribution.
//' @param n_iter Number of full sweeps over all tokens.
//' @param log_every Record the log-likelihood every this many sweeps.
//' @return List with `phi` (K x V), `theta` (D x K), `loglik` (trace) and `loglik_iter`.
//' @noRd
// [[Rcpp::export]]
Rcpp::List lda_gibbs_cpp(Rcpp::List docs, int V, int K, double alpha, double beta, int n_iter,
                         int log_every) {
    const int D = static_cast<int>(docs.size());
    if (K < 1 || V < 1 || D < 1) Rcpp::stop("LDA needs at least one topic, word and document.");

    std::vector<std::vector<int>> w(D), z(D);
    std::vector<int> ndk(static_cast<size_t>(D) * K, 0);
    std::vector<int> nkw(static_cast<size_t>(K) * V, 0);
    std::vector<int> nk(K, 0);
    std::vector<int> nd(D, 0);

    // random initial topic for every token
    for (int d = 0; d < D; ++d) {
        Rcpp::IntegerVector doc = docs[d];
        const int len = static_cast<int>(doc.size());
        w[d].assign(doc.begin(), doc.end());
        z[d].resize(len);
        nd[d] = len;
        for (int i = 0; i < len; ++i) {
            if (w[d][i] < 0 || w[d][i] >= V) Rcpp::stop("Word id out of range.");
            int k = static_cast<int>(R::unif_rand() * K);
            if (k >= K) k = K - 1;
            z[d][i] = k;
            ++ndk[static_cast<size_t>(d) * K + k];
            ++nkw[static_cast<size_t>(k) * V + w[d][i]];
            ++nk[k];
        }
    }

    const double Vbeta = V * beta;
    std::vector<double> p(K);
    std::vector<double> trace;
    std::vector<int> trace_iter;

    auto loglik = [&]() {
        // log P(words | topic assignments), up to a constant
        double ll = 0.0;
        const double lg_beta = std::lgamma(beta);
        for (int k = 0; k < K; ++k) {
            ll += std::lgamma(Vbeta) - std::lgamma(nk[k] + Vbeta);
            for (int v = 0; v < V; ++v) {
                ll += std::lgamma(nkw[static_cast<size_t>(k) * V + v] + beta) - lg_beta;
            }
        }
        return ll;
    };

    for (int iter = 0; iter < n_iter; ++iter) {
        Rcpp::checkUserInterrupt();
        for (int d = 0; d < D; ++d) {
            const size_t drow = static_cast<size_t>(d) * K;
            for (size_t i = 0; i < w[d].size(); ++i) {
                const int wi = w[d][i];
                int k = z[d][i];
                --ndk[drow + k];
                --nkw[static_cast<size_t>(k) * V + wi];
                --nk[k];

                double total = 0.0;
                for (int t = 0; t < K; ++t) {
                    p[t] = (ndk[drow + t] + alpha) * (nkw[static_cast<size_t>(t) * V + wi] + beta) /
                           (nk[t] + Vbeta);
                    total += p[t];
                }
                const double u = R::unif_rand() * total;
                double cum = p[0];
                int knew = 0;
                while (cum < u && knew < K - 1) {
                    ++knew;
                    cum += p[knew];
                }

                z[d][i] = knew;
                ++ndk[drow + knew];
                ++nkw[static_cast<size_t>(knew) * V + wi];
                ++nk[knew];
            }
        }
        if ((iter + 1) % log_every == 0 || iter == n_iter - 1) {
            trace.push_back(loglik());
            trace_iter.push_back(iter + 1);
        }
    }

    Rcpp::NumericMatrix phi(K, V);
    for (int k = 0; k < K; ++k) {
        for (int v = 0; v < V; ++v) {
            phi(k, v) = (nkw[static_cast<size_t>(k) * V + v] + beta) / (nk[k] + Vbeta);
        }
    }
    Rcpp::NumericMatrix theta(D, K);
    for (int d = 0; d < D; ++d) {
        for (int k = 0; k < K; ++k) {
            theta(d, k) = (ndk[static_cast<size_t>(d) * K + k] + alpha) / (nd[d] + K * alpha);
        }
    }

    return Rcpp::List::create(Rcpp::Named("phi") = phi, Rcpp::Named("theta") = theta,
                              Rcpp::Named("loglik") = Rcpp::wrap(trace),
                              Rcpp::Named("loglik_iter") = Rcpp::wrap(trace_iter));
}
