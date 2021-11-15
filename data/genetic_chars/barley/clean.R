#! /usr/bin/env Rscript

library(tidyverse)
library(WriteXLS)

data = as_tibble(read.csv("./LineProperties.csv"))

data$accession = unlist(lapply(data$accession, function(x) { gsub('/', 'x', x) }))

datas = split(data, as.integer(gl(nrow(data), 10000, nrow(data))))

for (i in c(1:length(datas)) ) {
    d = datas[i]
    WriteXLS(d, paste0("3-associations-PART", i, ".xls"))
}