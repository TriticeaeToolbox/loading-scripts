#! /usr/bin/env R

library(tidyverse)
library(breedbase)


#'
#' Create Accessions
#'
#' Read a T3 line information file and create a list of Accessions 
#' using the breedbase R package.  The Accessions can then be used 
#' to create a breedbase accession upload template.
#'
#' @param lines = file path to T3 line information
#' @param programs = file path to T3 breeding program information
#' @param genus = Genus name to prepend to line species, if provided
#'
#' @returns a list of breedbase::Accessions with the key set to the 
#' Accession name
#' 
createAccessions <- function(lines=NULL, programs=NULL, genus=NULL) {
  if ( is.null(lines) ) {
    stop("ERROR: You must provide the file path to the T3 line data file")
  }
  
  # Read the T3 line file
  lines <- as_tibble(read.csv(lines, stringsAsFactors = FALSE))
  
  # Read the T3 Breeding Programs file
  if ( !is.null(programs) ) {
    programs <- as_tibble(read.csv(programs, stringsAsFactors = FALSE))
  }
  
  # List of accessions to return
  accessions <- list()
  
  # Parse each line
  for ( i in c(1:nrow(lines)) ) {
    line <- lines[i,]
    name <- line$Name
    species <- line$Species
    grin <- line$GRIN
    synonyms <- line$Synonym
    breeding_program <- line$Breeding.Program
    description <- line$Description
    
    # Parse Line Name
    name <- parseLineName(name)
    
    # Create full species name
    if ( !is.null(genus) ) {
      species <- paste(genus, species, sep=" ")
    }
    
    
    # Accession properties
    properties <- list()
    
    # Get Organization Name
    if ( !is.na(breeding_program) && !is.null(programs) ) {
      program <- filter(programs, Code == breeding_program)
      if ( nrow(program) == 1 ) {
        properties$organization_names = c(program$Breeding.Program)
      }
    }
    
    # Parse synonyms
    syns <- c()
    for ( syn in unlist(strsplit(synonyms, ",")) ) {
      syn <- parseLineName(syn)
      if ( syn != "" ) {
        syns <- c(syns, syn)
      }
    }
    if ( !is.null(syns) ) {
      properties$synonyms <- syns
    }
    
    # Parse GRIN
    gs <- c()
    for ( g in unlist(strsplit(grin, ",")) ) {
      g <- trimws(g)
      if ( g != "" ) {
        gs <- c(gs, g)
      }
    }
    if ( !is.null(gs) ) {
      properties$accession_numbers <- gs
    }
    
    # Create Accession
    accession <- Accession(
      accession_name = name,
      species_name = species,
      properties = properties
    )
    
    # Add Accession to list
    accessions[[name]] <- accession
    
  }
  
  # Return the accessions
  return(accessions)
}


#
# Parse Line Name
# 
# Replace '/' with 'x' and '&' with 'and' 
# in Accession names loaded from T3.
#
parseLineName <- function(name) {
  name <- trimws(name)
  name <- gsub("/", "x", name)
  name <- gsub("&", "and", name)
  return(name)
}

