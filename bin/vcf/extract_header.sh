#! /bin/bash

# Extract the main header line (CHROM POS ... sample names) 
# from the provided vcf file
#
# USAGE: ./extract_header data.vcf > header.txt

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 data.vcf > header.txt"
    exit 1
fi

# Find the header line
grep "^# *CHROM\tPOS" "$1"
