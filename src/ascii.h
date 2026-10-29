// ascii.h
// Locale-independent character helpers.
//
// The C library's isalnum()/isspace()/tolower() depend on the current locale, and on
// some systems (notably macOS) they classify bytes >= 0x80 as letters or spaces. The
// bytes of multi-byte UTF-8 characters would then be misread and the text corrupted.
// These helpers only ever treat plain ASCII (< 0x80) specially, so every byte of a
// multi-byte UTF-8 character is left alone, whatever the locale.

#ifndef BIBLIO_ASCII_H
#define BIBLIO_ASCII_H

#include <string>

namespace citelens_ascii {

inline bool isSpaceA(char c) {
    return c == ' ' || c == '\t' || c == '\n' || c == '\r' || c == '\f' || c == '\v';
}
inline bool isUpperA(char c) { return c >= 'A' && c <= 'Z'; }
inline bool isLowerA(char c) { return c >= 'a' && c <= 'z'; }
inline bool isAlphaA(char c) { return isUpperA(c) || isLowerA(c); }
inline bool isDigitA(char c) { return c >= '0' && c <= '9'; }
inline bool isAlnumA(char c) { return isAlphaA(c) || isDigitA(c); }
inline char toLowerA(char c) { return isUpperA(c) ? static_cast<char>(c - 'A' + 'a') : c; }

// Reduce UTF-8 text to plain ASCII for use in citation keys:
//  * Latin-1 accented letters become their base letters (García -> Garcia, Müller -> Muller)
//  * curly apostrophes/quotes are dropped (It's -> Its)
//  * any other non-ASCII character becomes a space (so it separates words)
inline std::string asciiFold(const std::string& s) {
    // U+00C0 .. U+00FF
    static const char* const latin1[64] = {
        "A", "A", "A", "A", "A", "A", "AE", "C", "E", "E", "E", "E", "I", "I", "I", "I",
        "D", "N", "O", "O", "O", "O", "O", "",   "O", "U", "U", "U", "U", "Y", "TH", "ss",
        "a", "a", "a", "a", "a", "a", "ae", "c", "e", "e", "e", "e", "i", "i", "i", "i",
        "d", "n", "o", "o", "o", "o", "o", "",   "o", "u", "u", "u", "u", "y", "th", "y"};

    std::string out;
    out.reserve(s.size());
    size_t i = 0;
    while (i < s.size()) {
        unsigned char c = static_cast<unsigned char>(s[i]);
        if (c < 0x80) {
            out += s[i++];
            continue;
        }
        size_t len = 1;
        if (c >= 0xC0 && c < 0xE0)
            len = 2;
        else if (c >= 0xE0 && c < 0xF0)
            len = 3;
        else if (c >= 0xF0 && c < 0xF8)
            len = 4;
        if (i + len > s.size()) len = s.size() - i;

        if (c == 0xC3 && len == 2) {
            unsigned char c2 = static_cast<unsigned char>(s[i + 1]);
            if (c2 >= 0x80 && c2 <= 0xBF) {
                out += latin1[c2 - 0x80];
                i += 2;
                continue;
            }
        }
        // U+2018..U+201B: curly single quotes / apostrophe
        if (c == 0xE2 && len == 3 && static_cast<unsigned char>(s[i + 1]) == 0x80) {
            unsigned char c3 = static_cast<unsigned char>(s[i + 2]);
            if (c3 >= 0x98 && c3 <= 0x9B) {
                i += 3;
                continue;
            }
        }
        out += ' ';
        i += len;
    }
    return out;
}

}  // namespace citelens_ascii

#endif  // BIBLIO_ASCII_H
