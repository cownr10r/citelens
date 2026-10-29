// bib2df.cpp
// Parses BibTeX (.bib) text into a data frame, callable from R via Rcpp.
// The user-facing function is bib_to_df() in R/bib_to_df.R.

#include <Rcpp.h>

#include "ascii.h"

#include <cctype>
#include <map>
#include <string>
#include <utility>
#include <vector>

using namespace citelens_ascii;

namespace {

struct BibEntry {
    std::string type;
    std::string key;
    std::vector<std::pair<std::string, std::string>> fields;  // in file order
};

std::string lower(std::string s) {
    for (char& c : s) c = toLowerA(c);
    return s;
}

std::string trimStr(const std::string& s) {
    size_t b = 0, e = s.size();
    while (b < e && isSpaceA(s[b])) ++b;
    while (e > b && isSpaceA(s[e - 1])) --e;
    return s.substr(b, e - b);
}

// Tidy a raw BibTeX value: drop grouping braces, unescape \& \% \$ \# \_ , collapse whitespace.
std::string cleanValue(const std::string& v) {
    std::string stripped;
    for (size_t k = 0; k < v.size(); ++k) {
        char c = v[k];
        if (c == '\\' && k + 1 < v.size()) {
            char n = v[k + 1];
            if (n == '&' || n == '%' || n == '$' || n == '#' || n == '_' || n == '{' || n == '}') {
                stripped += n;
                ++k;
                continue;
            }
            stripped += c;  // keep other LaTeX commands (e.g. accents) as they are
            continue;
        }
        if (c == '{' || c == '}') continue;
        stripped += c;
    }
    std::string out;
    bool inSpace = false;
    for (char c : stripped) {
        if (isSpaceA(c)) {
            inSpace = true;
        } else {
            if (inSpace && !out.empty()) out += ' ';
            inSpace = false;
            out += c;
        }
    }
    return out;
}

class Parser {
   public:
    explicit Parser(const std::string& text) : s_(text), i_(0) {
        static const char* months[] = {"January", "February", "March",     "April",   "May",      "June",
                                       "July",    "August",   "September", "October", "November", "December"};
        static const char* abbr[] = {"jan", "feb", "mar", "apr", "may", "jun",
                                     "jul", "aug", "sep", "oct", "nov", "dec"};
        for (int m = 0; m < 12; ++m) macros_[abbr[m]] = months[m];
    }

    std::vector<BibEntry> parse() {
        std::vector<BibEntry> entries;
        while (i_ < s_.size()) {
            size_t at = s_.find('@', i_);
            if (at == std::string::npos) break;
            i_ = at + 1;
            skipWs();
            std::string type;
            while (i_ < s_.size() && isAlphaA(s_[i_])) type += s_[i_++];
            if (type.empty()) continue;
            type = lower(type);
            skipWs();
            if (i_ >= s_.size() || (s_[i_] != '{' && s_[i_] != '(')) continue;

            if (type == "comment" || type == "preamble") {
                skipBlock();
            } else if (type == "string") {
                parseString();
            } else {
                BibEntry e;
                e.type = type;
                if (parseEntryBody(e)) entries.push_back(e);
            }
        }
        return entries;
    }

   private:
    const std::string& s_;
    size_t i_;
    std::map<std::string, std::string> macros_;

    bool eof() const { return i_ >= s_.size(); }

    void skipWs() {
        while (!eof() && isSpaceA(s_[i_])) ++i_;
    }

    // At '{' : returns the content without the outer braces and moves past the closing brace.
    std::string readBraced() {
        ++i_;  // opening brace
        int depth = 1;
        std::string out;
        while (!eof()) {
            char c = s_[i_++];
            if (c == '{') {
                ++depth;
            } else if (c == '}') {
                if (--depth == 0) return out;
            }
            out += c;
        }
        return out;  // unterminated: return what we have
    }

    // At '"' : returns the content up to the closing quote (quotes inside braces don't end it).
    std::string readQuoted() {
        ++i_;  // opening quote
        int depth = 0;
        std::string out;
        while (!eof()) {
            char c = s_[i_++];
            if (c == '{') {
                ++depth;
            } else if (c == '}') {
                --depth;
            } else if (c == '"' && depth <= 0) {
                return out;
            }
            out += c;
        }
        return out;
    }

    // Skips a whole {...} or (...) block, positioned at the opening delimiter.
    void skipBlock() {
        if (s_[i_] == '{') {
            readBraced();
        } else {
            size_t close = s_.find(')', i_);
            i_ = (close == std::string::npos) ? s_.size() : close + 1;
        }
    }

    // A field value: pieces joined by '#', each a {braced}, "quoted", number, or macro name.
    std::string readValue() {
        std::string val;
        while (true) {
            skipWs();
            if (eof()) break;
            char c = s_[i_];
            if (c == '{') {
                val += readBraced();
            } else if (c == '"') {
                val += readQuoted();
            } else {
                std::string tok;
                while (!eof()) {
                    char ch = s_[i_];
                    if (isAlnumA(ch) || ch == '_' || ch == '-' || ch == ':' || ch == '.' ||
                        ch == '/' || ch == '+')
                        tok += s_[i_++];
                    else
                        break;
                }
                if (tok.empty()) break;  // something unexpected: let the caller resync
                auto it = macros_.find(lower(tok));
                val += (it == macros_.end()) ? tok : it->second;
            }
            skipWs();
            if (!eof() && s_[i_] == '#') {
                ++i_;
                continue;
            }
            break;
        }
        return val;
    }

    void parseString() {
        char close = (s_[i_] == '{') ? '}' : ')';
        ++i_;
        skipWs();
        std::string name;
        while (!eof() && s_[i_] != '=' && s_[i_] != close) name += s_[i_++];
        if (!eof() && s_[i_] == '=') {
            ++i_;
            macros_[lower(trimStr(name))] = readValue();
        }
        skipWs();
        while (!eof() && s_[i_] != close) ++i_;
        if (!eof()) ++i_;
    }

    bool parseEntryBody(BibEntry& e) {
        char close = (s_[i_] == '{') ? '}' : ')';
        ++i_;
        std::string key;
        while (!eof() && s_[i_] != ',' && s_[i_] != close) key += s_[i_++];
        e.key = trimStr(key);

        while (!eof()) {
            skipWs();
            while (!eof() && s_[i_] == ',') {
                ++i_;
                skipWs();
            }
            if (eof()) break;
            if (s_[i_] == close) {
                ++i_;
                break;
            }
            std::string name;
            while (!eof() && s_[i_] != '=' && s_[i_] != ',' && s_[i_] != close) name += s_[i_++];
            if (eof() || s_[i_] != '=') continue;  // malformed bit: resync at the next delimiter
            ++i_;                                  // '='
            std::string value = readValue();
            e.fields.emplace_back(lower(trimStr(name)), value);
        }
        return true;
    }
};

Rcpp::String utf8(const std::string& s) { return Rcpp::String(s, CE_UTF8); }

}  // namespace

//' Parse BibTeX text into a data frame (internal)
//'
//' @param lines Character vector of lines from a .bib file.
//' @param clean Strip grouping braces, unescape LaTeX specials and collapse whitespace.
//' @return A data frame with one row per entry.
//' @noRd
// [[Rcpp::export]]
Rcpp::List bib_parse_cpp(Rcpp::CharacterVector lines, bool clean) {
    std::string text;
    for (R_xlen_t i = 0; i < lines.size(); ++i) {
        if (Rcpp::CharacterVector::is_na(lines[i])) continue;
        std::string line = Rcpp::as<std::string>(lines[i]);
        if (i == 0 && line.size() >= 3 && static_cast<unsigned char>(line[0]) == 0xEF &&
            static_cast<unsigned char>(line[1]) == 0xBB && static_cast<unsigned char>(line[2]) == 0xBF)
            line.erase(0, 3);  // strip UTF-8 BOM
        text += line;
        text += '\n';
    }

    std::vector<BibEntry> entries = Parser(text).parse();
    const R_xlen_t n = static_cast<R_xlen_t>(entries.size());

    // Columns: bibtype, bibkey, then every field in order of first appearance.
    std::vector<std::string> colNames = {"bibtype", "bibkey"};
    std::map<std::string, size_t> colIndex = {{"bibtype", 0}, {"bibkey", 1}};
    for (const BibEntry& e : entries) {
        for (const auto& f : e.fields) {
            std::string name = f.first;
            if (name == "bibtype" || name == "bibkey") name += "_field";  // avoid clashes
            if (!colIndex.count(name)) {
                colIndex[name] = colNames.size();
                colNames.push_back(name);
            }
        }
    }

    Rcpp::List cols(colNames.size());
    for (size_t c = 0; c < colNames.size(); ++c) cols[c] = Rcpp::CharacterVector(n, NA_STRING);

    for (R_xlen_t r = 0; r < n; ++r) {
        const BibEntry& e = entries[r];
        Rcpp::CharacterVector type = cols[0];
        Rcpp::CharacterVector key = cols[1];
        type[r] = utf8(e.type);
        key[r] = utf8(e.key);
        for (const auto& f : e.fields) {
            std::string name = f.first;
            if (name == "bibtype" || name == "bibkey") name += "_field";
            Rcpp::CharacterVector col = cols[colIndex[name]];
            col[r] = utf8(clean ? cleanValue(f.second) : f.second);  // a repeated field: last one wins
        }
    }

    cols.attr("names") = Rcpp::CharacterVector(colNames.begin(), colNames.end());
    cols.attr("class") = "data.frame";
    if (n == 0)
        cols.attr("row.names") = Rcpp::IntegerVector(0);
    else
        cols.attr("row.names") = Rcpp::IntegerVector::create(NA_INTEGER, -static_cast<int>(n));
    return cols;
}
