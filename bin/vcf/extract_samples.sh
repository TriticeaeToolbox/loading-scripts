#! /bin/bash

# Extract the sample names from the main header line of the provided 
# vcf file or header file.  The sample names will be extracted as 
# one name per line in the output.
#
# USAGE: ./extract_samples data.vcf > samples.txt

# non-sample columns to remove
remove=("CHROM", "POS", "ID", "REF", "ALT", "QUAL", "FILTER", "INFO", "FORMAT")


if [ "$#" -ne 1 ]; then
    echo "Usage: $0 data.vcf > samples.txt"
    exit 1
fi


# Find the header line
header=$(grep "^#* *CHROM[[:space:]]POS" "$1")
header=$(echo "$header" | sed -e 's/^#* *//g')

# Convert tab-separated string to a comma-separated string
header_csv=$(echo "$header" | tr '\t' ',')

# Print sample names from columns
IFS=, read -ra cols <<< "$header_csv"
for col in "${cols[@]}"; do 
    if [[ ! "${remove[@]}" =~ "${col}" ]]; then
        echo "$col"
    fi
done
