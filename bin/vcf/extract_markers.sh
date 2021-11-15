#! /bin/bash

# Extract the marker names from the provided vcf file.  The marker 
# names will be extracted as one name per line in the output.
#
# USAGE: ./extract_markers data.vcf > markers.txt
# USAGE:

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 data.vcf > markers.txt"
    exit 1
fi


# Find main header line
header=$(grep -n "^#* *CHROM[[:space:]]POS" "$1" | cut -d ':' -f 1)

# Get markers
tail -n +$header "$1" | tail -n +2 | cut -d $'\t' -f 3 | sort | uniq
