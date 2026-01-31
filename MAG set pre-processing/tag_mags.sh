#!/usr/bin/env bash
set -uo pipefail

# Usage:
#   ./tag_mags.sh TAG
TAG="${1:-}"
if [ -z "$TAG" ]; then
  echo "Usage: $0 <TAG>"
  exit 1
fi

# Detect cores and choose parallel jobs
cores=$(nproc 2>/dev/null || echo 1)
jobs=$(( cores>1 ? cores/2 : 1 ))
echo "Using $jobs parallel jobs (detected $cores cores)"

# Enable nullglob so that *.bz2 expands to nothing if no match
shopt -s nullglob
inputs=(*.bz2)
if [ ${#inputs[@]} -eq 0 ]; then
  echo "No .bz2 files found in $(pwd)"
  exit 0
fi

# Worker script for one file
cat > process_one.sh <<'EOF'
#!/usr/bin/env bash
set -o pipefail

file="$1"
tag="$2"

[ -z "$file" ] && exit 1
[ -z "$tag" ] && exit 1

# compute output filename
out="${file%.fa.bz2}.${tag}.tagged.bz2"

# skip if already exists
[ -f "$out" ] && { echo "Skipping $file, output exists"; exit 0; }

# process file
bzcat "$file" 2>/dev/null | awk -v tag="$tag" 'BEGIN{OFS=""}
  /^>/ { print ">", tag, "|", substr($0,2); next }
  { print }
' | bzip2 > "$out"

EOF

chmod +x process_one.sh

# Run in parallel
printf '%s\n' "${inputs[@]}" | xargs -n1 -P "$jobs" -I{} bash -c './process_one.sh "{}" "'"$TAG"'"'

echo "All files processed."
