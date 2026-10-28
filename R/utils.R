# Internal helpers (not exported)

# Read a text file as clean UTF-8 lines.
#
# * Lines that are not valid UTF-8 (typically Windows-1252 curly quotes, dashes
#   and accented letters from older exports) are converted from Windows-1252.
# * Control characters that are illegal in XML (so they would corrupt an Excel
#   file) are removed. Tabs and line breaks are kept.
.read_text_lines <- function(path) {
  lines <- readLines(path, warn = FALSE, encoding = "unknown")

  bad <- !is.na(lines) & !validUTF8(lines)
  if (any(bad)) {
    fixed <- iconv(lines[bad], from = "CP1252", to = "UTF-8", sub = "?")
    still_bad <- is.na(fixed)
    if (any(still_bad)) {
      fixed[still_bad] <- iconv(lines[bad][still_bad], from = "latin1", to = "UTF-8", sub = "?")
    }
    lines[bad] <- fixed
    message(sum(bad), " line(s) were not valid UTF-8 and were converted from Windows-1252.")
  }

  # Byte-level cleanup so it behaves the same in any locale. Control characters
  # are plain ASCII and never occur inside a multi-byte UTF-8 sequence, so
  # useBytes is safe here.
  lines <- gsub("[\\x01-\\x08\\x0B\\x0C\\x0E-\\x1F]", "", lines, perl = TRUE, useBytes = TRUE)
  # The Unicode "non-characters" U+FFFE and U+FFFF are also illegal in XML.
  for (nc in c(0xBE, 0xBF)) {
    lines <- gsub(rawToChar(as.raw(c(0xEF, 0xBF, nc))), "", lines, fixed = TRUE, useBytes = TRUE)
  }

  Encoding(lines) <- "UTF-8"
  lines
}
