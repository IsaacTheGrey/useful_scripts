#!/usr/bin/env bash
set -euo pipefail

# If you want to override the output directory: ./merge_all_lanes.sh my_merged_dir
outdir=${1:-merged_reads}
mkdir -p "$outdir"

# 1) collect all your lane directories (they must end with "_trimmed")
lanes=( *_trimmed )
if (( ${#lanes[@]} == 0 )); then
  echo "ERROR: no directories matching '*_trimmed' found." >&2
  exit 1
fi

# 2) discover unique sample names by stripping the suffix from forward reads
#    Search recursively within each lane folder for *_R1.trimmed.paired.fastq.gz
mapfile -t samples < <(
  find "${lanes[@]}" -type f -name "*_R1.trimmed.paired.fastq.gz" -printf "%f\n" \
  | sed 's/_R1\.trimmed\.paired\.fastq\.gz$//' \
  | sort -u
)

if (( ${#samples[@]} == 0 )); then
  echo "ERROR: no '*_R1.trimmed.paired.fastq.gz' files found under: ${lanes[*]}." >&2
  exit 1
fi

# 3) loop through each sample
for sample in "${samples[@]}"; do
  echo "► Merging sample: $sample"

  # gather per-lane inputs (recursively in subfolders)
  mapfile -t fwd < <(
    find "${lanes[@]}" -type f -name "${sample}_R1.trimmed.paired.fastq.gz" \
    | sort
  )
  mapfile -t rev < <(
    find "${lanes[@]}" -type f -name "${sample}_R2.trimmed.paired.fastq.gz" \
    | sort
  )

  if (( ${#fwd[@]} == 0 )); then
    echo "  ⚠️  No forward reads found for $sample, skipping." >&2
    continue
  fi

  # (optional) sanity warning if counts differ
  if (( ${#rev[@]} > 0 )) && (( ${#rev[@]} != ${#fwd[@]} )); then
    echo "  ⚠️  Forward/Reverse file count mismatch for $sample (${#fwd[@]} R1 vs ${#rev[@]} R2)." >&2
  fi

  # merge forward reads
  out_fwd="$outdir/${sample}_R1.merged.fastq.gz"
  echo "  – Writing $((${#fwd[@]})) forward files → $out_fwd"
  cat "${fwd[@]}" > "$out_fwd"

  # merge reverse reads (if any)
  if (( ${#rev[@]} > 0 )); then
    out_rev="$outdir/${sample}_R2.merged.fastq.gz"
    echo "  – Writing $((${#rev[@]})) reverse files → $out_rev"
    cat "${rev[@]}" > "$out_rev"
  fi
done

echo "✅ Done. All merged files are in '$outdir/'"
