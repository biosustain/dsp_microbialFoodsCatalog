#!/bin/bash

# Simple loop to fix MAG headers in .tagged.fa.bz2 files

for file in *.tagged.fa.bz2; do
    MAG=$(basename "$file" .tagged.fa.bz2)
    echo "Processing $file -> ${MAG}.fixed.fa"

    bunzip2 -c "$file" | \
    awk -v mag="$MAG" '
        /^>/ {
            sub(/^>/, "", $0)
            split($0, a, "|")
            print ">" a[1] "|" mag "|" a[2]
            next
        }
        { print }
    ' > "${MAG}.fa"
done

echo "Done!"
