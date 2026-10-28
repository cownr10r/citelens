// refworks2bib.cpp
// Converts RefWorks Tagged Format citations to BibTeX (.bib), callable from R via Rcpp.
//
// From R:
//   Rcpp::sourceCpp("refworks2bib.cpp")
//   refworks_to_bib(readLines("refworks.txt"))     # character vector, one entry per record

#include <Rcpp.h>

#include <algorithm>
#include <cctype>
#include <initializer_list>
#include <map>
#include <set>
#include <sstream>
#include <string>
#include <utility>
#include <vector>

namespace {

struct Record {
    std::string type;                                   // value of the RT line
    std::map<std::string, std::vector<std::string>> f;  // tag -> values (in order)
};

// ---------- small string helpers ----------

std::string trim(const std::string& s) {
    size_t b = 0, e = s.size();
    while (b < e && std::isspace(static_cast<unsigned char>(s[b]))) ++b;
    while (e > b && std::isspace(static_cast<unsigned char>(s[e - 1]))) --e;
    return s.substr(b, e - b);
}

std::string toLower(std::string s) {
    for (char& c : s) c = static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
    return s;
}

std::string alnumLower(const std::string& s) {
    std::string out;
    for (unsigned char c : s)
        if (std::isalnum(c)) out += static_cast<char>(std::tolower(c));
    return out;
}

std::string join(const std::vector<std::string>& v, const std::string& sep) {
    std::string out;
    for (size_t i = 0; i < v.size(); ++i) {
        if (i) out += sep;
        out += v[i];
    }
    return out;
}

std::vector<std::string> splitOn(const std::string& s, char delim) {
    std::vector<std::string> out;
    std::string cur;
    std::stringstream ss(s);
    while (std::getline(ss, cur, delim)) {
        cur = trim(cur);
        if (!cur.empty()) out.push_back(cur);
    }
    return out;
}

// Escape characters that are special to LaTeX (leaves already-escaped ones alone).
std::string esc(const std::string& s) {
    std::string out;
    for (size_t i = 0; i < s.size(); ++i) {
        char c = s[i];
        if ((c == '&' || c == '%' || c == '$' || c == '#' || c == '_') &&
            (i == 0 || s[i - 1] != '\\'))
            out += '\\';
        out += c;
    }
    return out;
}

// ---------- parsing ----------

const std::set<std::string>& knownTags() {
    static const std::set<std::string> tags = {
        "RT", "SR", "ID", "A1", "A2", "A3", "A4", "A5", "A6", "T1", "T2", "T3",
        "JF", "JO", "JA", "YR", "FD", "VO", "IS", "SP", "OP", "K1", "AB", "NO",
        "PB", "PP", "SN", "AD", "AV", "AN", "LA", "CL", "SF", "OT", "LK", "DO",
        "CN", "DB", "DS", "IP", "RD", "ST", "U1", "U2", "U3", "U4", "U5", "UL",
        "SL", "ED", "OL", "LL", "WT", "ER"};
    return tags;
}

bool parseTagLine(const std::string& line, std::string& tag, std::string& val) {
    if (line.size() < 2) return false;
    if (line.size() > 2 && line[2] != ' ' && line[2] != '\t') return false;
    std::string t = line.substr(0, 2);
    if (!knownTags().count(t)) return false;
    tag = t;
    val = line.size() > 3 ? trim(line.substr(3)) : "";
    return true;
}

std::vector<Record> parseRefWorks(const Rcpp::CharacterVector& lines) {
    std::vector<Record> records;
    Record cur;
    bool inRecord = false;
    std::string lastTag;

    auto flush = [&]() {
        if (inRecord) records.push_back(cur);
        cur = Record();
        inRecord = false;
        lastTag.clear();
    };

    for (R_xlen_t i = 0; i < lines.size(); ++i) {
        if (Rcpp::CharacterVector::is_na(lines[i])) continue;
        std::string line = Rcpp::as<std::string>(lines[i]);
        if (!line.empty() && line.back() == '\r') line.pop_back();
        if (i == 0 && line.size() >= 3 && static_cast<unsigned char>(line[0]) == 0xEF &&
            static_cast<unsigned char>(line[1]) == 0xBB &&
            static_cast<unsigned char>(line[2]) == 0xBF)
            line.erase(0, 3);  // strip UTF-8 BOM
        if (trim(line).empty()) continue;

        std::string tag, val;
        if (parseTagLine(line, tag, val)) {
            if (tag == "RT") {
                flush();
                inRecord = true;
                cur.type = val;
            } else if (inRecord) {
                if (!val.empty()) cur.f[tag].push_back(val);
                lastTag = tag;
            }
        } else if (inRecord && !lastTag.empty() && !cur.f[lastTag].empty()) {
            // continuation of the previous field (e.g. wrapped abstract)
            cur.f[lastTag].back() += " " + trim(line);
        }
    }
    flush();
    return records;
}

// ---------- BibTeX generation ----------

std::string bibType(const std::string& rt) {
    std::string t = toLower(rt);
    if (t.find("journal") != std::string::npos) return "article";
    if (t.find("magazine") != std::string::npos) return "article";
    if (t.find("newspaper") != std::string::npos) return "article";
    if (t.find("book, whole") != std::string::npos) return "book";
    if (t.find("book, edited") != std::string::npos) return "book";
    if (t.find("book, section") != std::string::npos) return "incollection";
    if (t.find("conference") != std::string::npos) return "inproceedings";
    if (t.find("dissertation") != std::string::npos || t.find("thesis") != std::string::npos)
        return "phdthesis";
    if (t.find("report") != std::string::npos) return "techreport";
    if (t.find("book") != std::string::npos) return "book";
    return "misc";
}

const std::string& first(const Record& r, const std::string& tag) {
    static const std::string empty;
    auto it = r.f.find(tag);
    return (it == r.f.end() || it->second.empty()) ? empty : it->second.front();
}

std::string firstOf(const Record& r, std::initializer_list<const char*> tags) {
    for (const char* t : tags) {
        const std::string& v = first(r, t);
        if (!v.empty()) return v;
    }
    return "";
}

// All values for a tag, further split on ';' (some exports pack several names in one line).
std::vector<std::string> people(const Record& r, const std::string& tag) {
    std::vector<std::string> out;
    auto it = r.f.find(tag);
    if (it == r.f.end()) return out;
    for (const std::string& v : it->second)
        for (const std::string& p : splitOn(v, ';')) out.push_back(p);
    return out;
}

std::string cleanDoi(std::string d) {
    static const char* prefixes[] = {"https://doi.org/", "http://doi.org/", "https://dx.doi.org/",
                                     "http://dx.doi.org/", "doi:", "DOI:"};
    for (const char* p : prefixes) {
        std::string pre(p);
        if (d.compare(0, pre.size(), pre) == 0) {
            d = d.substr(pre.size());
            break;
        }
    }
    return trim(d);
}

std::string yearOf(const Record& r) {
    std::string y = firstOf(r, {"YR", "FD"});
    for (size_t i = 0; i + 4 <= y.size(); ++i) {
        if (std::isdigit(static_cast<unsigned char>(y[i])) &&
            std::isdigit(static_cast<unsigned char>(y[i + 1])) &&
            std::isdigit(static_cast<unsigned char>(y[i + 2])) &&
            std::isdigit(static_cast<unsigned char>(y[i + 3])))
            return y.substr(i, 4);
    }
    return y;
}

std::string pagesOf(const Record& r) {
    std::string sp = first(r, "SP"), op = first(r, "OP");
    if (sp.empty()) return "";
    std::string out = sp;
    if (!op.empty() && op != sp) out += "-" + op;
    // normalise single hyphens to BibTeX's "--"
    std::string norm;
    for (size_t i = 0; i < out.size(); ++i) {
        if (out[i] == '-' && !(i + 1 < out.size() && out[i + 1] == '-') &&
            !(i > 0 && out[i - 1] == '-'))
            norm += "--";
        else
            norm += out[i];
    }
    return norm;
}

std::string makeKey(const Record& r, std::set<std::string>& used) {
    std::string last = "anon";
    std::vector<std::string> au = people(r, "A1");
    if (au.empty()) au = people(r, "A2");
    if (!au.empty()) {
        const std::string& a = au.front();
        size_t comma = a.find(',');
        std::string ln;
        if (comma != std::string::npos) {
            ln = a.substr(0, comma);
        } else {
            size_t sp = a.find_last_of(' ');
            ln = (sp == std::string::npos) ? a : a.substr(sp + 1);
        }
        ln = alnumLower(ln);
        if (!ln.empty()) last = ln;
    }

    static const std::set<std::string> stop = {"a",   "an",  "the", "of",   "on",   "in",
                                               "and", "for", "to",  "with", "from", "by", "at"};
    std::string word;
    {
        std::string cur;
        std::string title = first(r, "T1") + " ";
        for (unsigned char c : title) {
            if (std::isalnum(c)) {
                cur += static_cast<char>(std::tolower(c));
            } else if (!cur.empty()) {
                if (!stop.count(cur)) {
                    word = cur;
                    break;
                }
                cur.clear();
            }
        }
    }

    std::string base = last + yearOf(r) + word;
    std::string key = base;
    for (char suffix = 'a'; used.count(key) && suffix <= 'z'; ++suffix) key = base + suffix;
    for (int n = 2; used.count(key); ++n) key = base + std::to_string(n);
    used.insert(key);
    return key;
}

std::string toBibtex(const Record& r, std::set<std::string>& used) {
    const std::string type = bibType(r.type);
    std::vector<std::pair<std::string, std::string>> out;

    auto add = [&](const std::string& name, const std::string& value) {
        if (!trim(value).empty()) out.emplace_back(name, trim(value));
    };
    auto addBraced = [&](const std::string& name, const std::string& value) {
        if (!trim(value).empty()) out.emplace_back(name, "{" + esc(trim(value)) + "}");
    };

    // names
    auto au = people(r, "A1");
    for (auto& a : au) a = esc(a);
    if (!au.empty()) add("author", "{" + join(au, " and ") + "}");
    auto ed = people(r, "A2");
    for (auto& a : ed) a = esc(a);
    if (!ed.empty()) add("editor", "{" + join(ed, " and ") + "}");

    // title: double braces keep BibTeX from changing capitalisation
    if (!first(r, "T1").empty()) add("title", "{{" + esc(first(r, "T1")) + "}}");

    // container / venue
    if (type == "article") {
        addBraced("journal", firstOf(r, {"JF", "JO", "T2"}));
    } else if (type == "incollection" || type == "inproceedings") {
        addBraced("booktitle", firstOf(r, {"T2", "JF"}));
    }
    if (type == "book") addBraced("series", first(r, "T3"));

    add("year", yearOf(r));
    addBraced("volume", first(r, "VO"));
    addBraced("number", firstOf(r, {"IS", "IP"}));
    {
        std::string pg = pagesOf(r);
        if (!pg.empty()) add("pages", "{" + pg + "}");
    }
    addBraced("edition", first(r, "ED"));

    // publisher / institution
    if (type == "phdthesis") {
        addBraced("school", first(r, "PB"));
    } else if (type == "techreport") {
        addBraced("institution", first(r, "PB"));
    } else {
        addBraced("publisher", first(r, "PB"));
    }
    addBraced("address", first(r, "PP"));

    // identifiers
    if (!first(r, "SN").empty()) addBraced(type == "article" ? "issn" : "isbn", first(r, "SN"));
    if (!first(r, "DO").empty()) add("doi", "{" + cleanDoi(first(r, "DO")) + "}");
    {
        std::string url = firstOf(r, {"LK", "UL"});
        if (!url.empty()) add("url", "{" + url + "}");  // not escaped: used with \url{}
    }

    // extras
    {
        std::vector<std::string> kw;
        auto it = r.f.find("K1");
        if (it != r.f.end())
            for (const std::string& v : it->second)
                for (const std::string& k : splitOn(v, ';')) kw.push_back(esc(k));
        if (!kw.empty()) add("keywords", "{" + join(kw, ", ") + "}");
    }
    addBraced("abstract", first(r, "AB"));
    addBraced("note", first(r, "NO"));
    addBraced("language", first(r, "LA"));

    std::string key = makeKey(r, used);

    size_t width = 0;
    for (auto& kv : out) width = std::max(width, kv.first.size());

    std::ostringstream os;
    os << "@" << type << "{" << key << ",\n";
    for (size_t i = 0; i < out.size(); ++i) {
        os << "  " << out[i].first << std::string(width - out[i].first.size(), ' ') << " = "
           << out[i].second << (i + 1 < out.size() ? "," : "") << "\n";
    }
    os << "}\n";
    return os.str();
}

}  // namespace

//' Convert RefWorks Tagged Format lines to BibTeX entries
//'
//' @param lines Character vector of lines in RefWorks Tagged Format (e.g. from readLines()).
//' @return Character vector with one BibTeX entry per RefWorks record.
//' @export
// [[Rcpp::export]]
Rcpp::CharacterVector refworks_to_bib(Rcpp::CharacterVector lines) {
    std::vector<Record> records = parseRefWorks(lines);
    std::set<std::string> used;
    Rcpp::CharacterVector out(records.size());
    for (size_t i = 0; i < records.size(); ++i) {
        out[i] = toBibtex(records[i], used);
    }
    return out;
}
