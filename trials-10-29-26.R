convert_refworks("~/Downloads/1bb0e0aa-3ae2-4cf5-968b-18f9c51728ab.ris", "~/downloads/conversion.bib")

bib_to_df("~/Downloads/references.txt", xlsx = "~/Downloads/references.xlsx")

refs <- bib_to_df("~/Downloads/conversion.bib")
m <- topic_model(refs, k = 5, seed = 1)
m
plot_topic_terms(m)


source("data-raw/make_sample_abstracts.R")


m <- topic_model(refs, k = 3, seed = 1)



topic_terms(m, n = 10) # top words per topic
plot_topic_terms(m)    # bar charts
plot_topic_prevalence(m)

a <- doc_similarity(res)
plot_similarity(a, digits = 1)





# How often words appear, by five-year period
w <- word_trends(res, words = c("equity", "belonging", "enrollment"), bin = 5)
w
plot_word_trends(w)

# How your topics change over time
m <- topic_model(res, k = 5, seed = 1)
tt <- topic_trends(m, refs, bin = 5)
plot_topic_trends(tt)
