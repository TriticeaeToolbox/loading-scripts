#! /bin/bash

# Replace the main header line from the provided vcf file
# with the provided new header line
#
# USAGE: ./replace_header.sh data.vcf header.modified.txt > data.modified.vcf

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 data.vcf header.modified.txt > data.modified.vcf"
    exit 1
fi

# Find the header line
line=$(grep -n "^# *CHROM\tPOS" "$1" | cut -d ':' -f 1)

# Replace the header line
sed "$(echo $line)s/.*/$(cat $2)/" "$1"
