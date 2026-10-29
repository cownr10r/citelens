.biblio_stopwords <- c(
  # common English function words
  "a", "about", "above", "after", "again", "against", "all", "also", "although", "am", "among",
  "an", "and", "any", "are", "as", "at", "be", "because", "been", "before", "being", "below",
  "between", "both", "but", "by", "can", "could", "did", "do", "does", "doing", "down",
  "during", "each", "few", "for", "from", "further", "had", "has", "have", "having", "he",
  "hence", "her", "here", "hers", "herself", "him", "himself", "his", "how", "however", "i",
  "if", "in", "into", "is", "it", "its", "itself", "just", "may", "me", "might", "more",
  "most", "must", "my", "myself", "no", "nor", "not", "now", "of", "off", "on", "once",
  "one", "only", "or", "other", "our", "ours", "ourselves", "out", "over", "own", "per",
  "same", "shall", "she", "should", "so", "some", "such", "than", "that", "the", "their",
  "theirs", "them", "themselves", "then", "there", "therefore", "these", "they", "this",
  "those", "though", "three", "through", "thus", "to", "too", "two", "under", "until", "up",
  "upon", "very", "via", "was", "we", "were", "what", "when", "where", "whether", "which",
  "while", "who", "whom", "why", "will", "with", "within", "without", "would", "yet", "you",
  "your", "yours", "yourself", "yourselves", "first", "second", "third", "across",
  # boilerplate that appears in nearly every abstract
  "abstract", "paper", "article", "study", "studies", "research", "result", "results",
  "finding", "findings", "purpose", "aim", "aims", "objective", "objectives", "method",
  "methods", "methodology", "conclusion", "conclusions", "implication", "implications",
  "present", "presents", "presented", "using", "use", "used", "uses", "based", "show",
  "shows", "showed", "shown", "found", "find", "finds", "examine", "examines", "examined",
  "examining", "investigate", "investigates", "investigated", "explore", "explores",
  "explored", "discuss", "discusses", "discussed", "suggest", "suggests", "suggested",
  "review", "reviews", "reviewed", "report", "reports", "reported", "provide", "provides",
  "provided", "include", "includes", "included", "including"
)

#' Default stop words used by `topic_model()`
#'
#' Common English function words plus words that appear in almost every
#' abstract ("study", "results", "findings", ...). Pass your own additions to
#' the `stopwords` argument of [topic_model()].
#'
#' @return A character vector.
#' @examples
#' head(biblio_stopwords())
#' @export
biblio_stopwords <- function() .biblio_stopwords
