#!/usr/bin/env bash
set -euo pipefail


MAP="reference_domain_mags.csv"                 # CSV file with fa_filename,domain
MAGS_DIR="/mnt/hdds/s232979/MiFoDB_MAGs" 
DRY_RUN=0



# check target folders
for d in prokaryote eukaryote unknown; do
  mkdir -p "$d"
done

# read CSV
tail -n +2 "$MAP" | tr -d '\r' | while IFS=',' read -r fa domain || [[ -n "$fa" ]]; do
  fa="$(echo "$fa" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"    # trim
  domain="$(echo "$domain" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  [[ -z "$fa" ]] && continue

  # check for file in MAGs_DIR
  src="$MAGS_DIR/$fa"
  # try with .fa extension if exact file not found
  if [[ ! -f "$src" && -f "$MAGS_DIR/$fa.fa" ]]; then
    src="$MAGS_DIR/$fa.fa"
  fi

  if [[ ! -f "$src" ]]; then
    echo "WARNING: missing $fa"
    continue
  fi

  # determine destination
  d="$(echo "$domain" | tr '[:upper:]' '[:lower:]')"
  if echo "$d" | grep -q "prok"; then dest="prokaryote"
  elif echo "$d" | grep -q "euk"; then dest="eukaryote"
  else dest="unknown"
  fi

  # avoid overwriting
  dest_file="$dest/$(basename "$src")"
  if [[ -f "$dest_file" ]]; then
    echo "SKIP: $dest_file already exists"
    continue
  fi

  # copy
  if [[ $DRY_RUN -eq 1 ]]; then
    echo "DRY_RUN: would copy '$src' -> '$dest/'"
  else
    cp -p "$src" "$dest/" && echo "copied '$src' -> '$dest/'"
  fi
done

echo "Done."
