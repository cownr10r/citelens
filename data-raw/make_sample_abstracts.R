# Generates inst/extdata/sample_abstracts.bib: 30 SYNTHETIC abstracts (not real
# publications) on three themes, for examples and tests. Run from the package root.
set.seed(2024)
themes <- list(
  retention = list(
    words = c("retention","persistence","attrition","dropout","advising","firstyear","engagement",
              "belonging","mentoring","cohort","orientation","withdrawal","completion","support","intervention"),
    title = c("Predicting student persistence","Advising and first-year retention","Reducing attrition through mentoring")),
  finance = list(
    words = c("tuition","financial","aid","scholarship","debt","grant","affordability","loan",
              "income","cost","funding","budget","enrollment","pricing","subsidy"),
    title = c("Tuition and enrollment decisions","Financial aid and affordability","Scholarships and student debt")),
  analytics = list(
    words = c("data","dashboard","predictive","model","institutional","assessment","accountability",
              "metrics","warehouse","reporting","analytics","survey","outcomes","evaluation","benchmarking"),
    title = c("Institutional dashboards for decisions","Predictive models in higher education","Assessment and accountability metrics"))
)
glue <- c("Community college students","Colleges","Institutions","Undergraduates","Administrators")
make_abs <- function(th) {
  w <- sample(themes[[th]]$words, 9)
  o <- sample(unlist(lapply(themes[-match(th, names(themes))], `[[`, "words")), 2)
  paste0(sample(glue, 1), " were studied with attention to ", w[1], ", ", w[2], " and ", w[3], ". ",
         "Evidence on ", w[4], " and ", w[5], " suggests that ", w[6], " shapes ", w[7], " over time. ",
         "A discussion of ", w[8], ", ", w[9], " and ", o[1], " follows, with notes on ", w[1], " and ", w[5], ". ",
         "Further ", w[2], " and ", w[6], " work touches ", o[2], ".")
}
th <- rep(names(themes), each = 10)
lines <- character()
for (i in seq_along(th)) {
  lines <- c(lines,
    sprintf("@article{syn%02d,", i),
    sprintf("  author = {Author%d, Sample},", i),
    sprintf("  title = {%s},", sample(themes[[th[i]]]$title, 1)),
    sprintf("  year = {%d},", sample(2015:2024, 1)),
    sprintf("  journal = {Journal of Synthetic Examples},"),
    sprintf("  abstract = {%s}", make_abs(th[i])),
    "}", "")
}
writeLines(lines, file.path("inst", "extdata", "sample_abstracts.bib"), useBytes = TRUE)
