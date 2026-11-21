# Builds inst/extdata/sample_authors.csv: a small SYNTHETIC set of papers for the
# examples and tests of find_duplicate_papers() and author_network(). The names
# and titles are invented. It contains three collaboration clusters, several
# one-paper clusters, a single-author paper, one duplicate listing (row 7, a
# lower-cited copy of row 1 with a new year) and one paper with the same title as
# row 1 but different authors (row 18), which is NOT a duplicate.
papers <- data.frame(
  title = c(
    "Persistence gaps in first-year cohorts",
    "Advising models and degree completion",
    "Peer mentoring and course success",
    "Early alerts in gateway courses",
    "Summer bridge programs revisited",
    "Tracking cohort outcomes with dashboards",
    "Persistence gaps in first-year cohorts.",
    "Transfer pathways between two-year and four-year colleges",
    "Credit transfer and time to degree",
    "Articulation agreements in practice",
    "Dual credit participation and later enrollment",
    "High school partnerships and college readiness",
    "Financial aid packaging and persistence",
    "Workforce program review methods",
    "Course grade distributions over time",
    "Enrollment forecasting with small samples",
    "Student survey response rates",
    "Persistence gaps in first-year cohorts"
  ),
  authors = c(
    "Alder, A. and Birch, B.",
    "Alder, A. and Birch, B. and Cedar, C.",
    "Birch, B. and Cedar, C.",
    "Alder, A. and Dogwood, D.",
    "Alder, A. and Birch, B.",
    "Alder, A. and Birch, B. and Dogwood, D.",
    "Alder, A. and Birch, B.",
    "Elm, E. and Fir, F.",
    "Elm, E. and Fir, F. and Gum, G.",
    "Elm, E. and Gum, G.",
    "Hazel, H. and Ivy, I.",
    "Hazel, H. and Ivy, I.",
    "Juniper, J. and Kapok, K.",
    "Larch, L. and Maple, M. and Nettle, N.",
    "Oak, O.",
    "Pine, P. and Quince, Q.",
    "Rowan, R. and Sage, S.",
    "Tamarack, T. and Willow, W."
  ),
  year = c(2018, 2019, 2020, 2021, 2022, 2023, 2019, 2017, 2019, 2021,
           2020, 2022, 2016, 2018, 2019, 2021, 2022, 2017),
  cited_by = c(120, 85, 60, 40, 25, 10, 1, 200, 95, 30, 55, 18, 44, 12, 7, 3, 5, 9),
  stringsAsFactors = FALSE
)
write.csv(papers, "inst/extdata/sample_authors.csv", row.names = FALSE)
