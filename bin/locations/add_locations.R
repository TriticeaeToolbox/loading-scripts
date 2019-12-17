#! /usr/bin/env R

library(tidyverse)
library(breedbase)



createLocations <- function(locations=NULL, programs=NULL) {
  if ( is.null(locations) ) {
    stop("ERROR: You must provide the file path to the T3 location data file")
  }

  # Read the T3 location file
  locations <- as_tibble(read.csv(locations, stringsAsFactors = FALSE))

  # Read the T3 Breeding Programs file, if provided
  if ( !is.null(programs) ) {
    programs <- as_tibble(read.csv(programs, stringsAsFactors = FALSE))
  }

  # List of locations to return
  rtn <- list()

  # Parse each location
  for ( i in c(1:nrow(locations)) ) {
    location <- locations[i,]
    name <- location$Name
    abbreviation <- location$Abbreviation
    country_code <- location$Country.Code
    country_name <- location$Country.Name
    program <- location$Program
    type <- location$Type
    lat <- location$Latitude
    lon <- location$Longitude
    alt <- location$Altitude

    # Parse Name
    name <- gsub("-USA$", "", name)
    name <- gsub("-CAN$", "", name)

    # Parse Program
    program <- gsub(": data$", "", program)
    program <- gsub("&amp;", "&", program)
    if ( grepl("^USDA-ARS", program) ) {
      program <- "USDA"
    }
    if ( grepl("^University of Florida", program) ) {
      program <- "University of Florida"
    }
    if ( grepl("^Ohio State University", program) ) {
      program <- "Ohio State University"
    }
    if ( grepl("^University of Saskatchewan", program) ) {
      program <- "University of Saskatchewan"
    }
    if ( program == "IHAR Poland" ) {
      program <- "IHAR, Poland"
    }
    if ( program == "Auburn University" ) {
      program <- "AAES, Auburn University"
    }
    
    # Try to match program to existing programs, if provided
    if ( !is.null(programs) ) {
      p <- filter(programs, Breeding.Program == program)
      if ( nrow(p) != 1 ) {
        print(sprintf("WARNING: Could not find matching breeding program [%s]", program))
      }
    }

    # Geocode location
    geo <- geocodeLocation(name)

    # Create the location and add to list
    rtn[name] <- Location(
      name = name,
      abbreviation = abbreviation,
      country_code = country_code,
      country_name = country_name,
      program = program,
      type = type,
      latitude = geo$latitude,
      longitude = geo$longitude,
      altitude = geo$altitude
    )

  }

  # Return the Locations
  return(rtn)

}