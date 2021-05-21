#! /usr/bin/env Rscript

library(tidyverse)


# PARSE ARGUMENTS
args = commandArgs(TRUE)
if ( length(args) != 3 ) {
    stop("USAGE: ./replace_header_samples.R header.original.txt header.modified.txt matches.csv")
}
header_original_file = args[1]
header_modified_file = args[2]
matches_file = args[3]


# CHECK FILES
if ( !file.exists(header_original_file) ) {
    stop(sprintf("MISSING FILE: header file %s does not exist", header_original_file))
}
if ( !file.exists(matches_file) ) {
    stop(sprintf("MISSING FILE: matches file %s does not exist", matches_file))
}


# READ FILES
headers = as_tibble(read.delim(header_original_file, header=F, sep="\t"))
matches = as_tibble(read.csv(matches_file, header=T))


# REPLACE SAMPLE NAMES
for ( i in c(1:ncol(headers)) ) {
    col = headers[1,i][[1]]
    m = filter(matches, search_term == col)
    r = ifelse(nrow(m) == 1, m[1,]$database_name, col)
    if ( r != col ) {
        print(sprintf("%s --> %s", col, r))
    }
    headers[1,i] = r
}


# WRITE UPDATED HEADER
write.table(headers, header_modified_file, sep="\t", col.names=F, row.names=F, quote=F)
