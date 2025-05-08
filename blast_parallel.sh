#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------------------------------------------
# USAGE
#    blastx_parallel.sh [-t N|--test N] [--ramdisk DIR] -i DIR -o DIR -d DB [--top N]
#
# OPTIONS
#    -t, --test N         Run on only the first N chunks (for quick testing)
#    --ramdisk DIR        Use DIR (e.g. /dev/shm) to copy DB and chunks for faster I/O
#    -i, --input DIR      Directory containing chunked FASTA files (required)
#    -o, --output DIR     Directory for BLASTX outputs (required)
#    -d, --db DB          BLAST DB basename OR directory containing DB files (required)
#    --top N              Keep only top N hits per query (default: 3)
#    -h, --help           Show this message and exit
# -----------------------------------------------------------------------------

usage() {
  cat <<EOF
Usage: $0 [-t N|--test N] [--ramdisk DIR] -i DIR -o DIR -d DB [--top N]

    -t, --test N         Run on only the first N chunks (for quick testing)
    --ramdisk DIR        Use DIR (e.g. /dev/shm) to copy DB and chunks for faster I/O
    -i, --input DIR      Directory containing chunked FASTA files (required)
    -o, --output DIR     Directory for BLASTX outputs (required)
    -d, --db DB          BLAST DB prefix or directory containing DB files
    --top N              Keep only top N hits per query (default: 3)
    -h, --help           Show this message and exit
EOF
  exit 1
}

# Default values
TEST_CHUNKS=0
RAMDISK=""
INPUT_DIR=""
OUT_DIR=""
DB_ARG=""
TOP_HITS=3

# Parse arguments
declare -a POSITIONAL=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    -t|--test)
      TEST_CHUNKS=${2:-0}; shift 2;;
    --ramdisk)
      RAMDISK=${2:-}; shift 2;;
    -i|--input)
      INPUT_DIR=${2:-}; shift 2;;
    -o|--output)
      OUT_DIR=${2:-}; shift 2;;
    -d|--db)
      DB_ARG=${2:-}; shift 2;;
    --top)
      TOP_HITS=${2:-3}; shift 2;;
    -h|--help)
      usage;;
    *)
      POSITIONAL+=("$1"); shift;;
  esac
done
set -- "${POSITIONAL[@]}"

# Ensure required args
if [[ -z "$INPUT_DIR" || -z "$OUT_DIR" || -z "$DB_ARG" ]]; then
  echo "Error: --input, --output, and --db are all required." >&2
  usage
fi

# Determine DB_PATH and DB_DIR
db_base_arg="$DB_ARG"
if [[ -d "$db_base_arg" ]]; then
  DB_DIR="$db_base_arg"
  phr_file=$(ls "$DB_DIR"/*.phr 2>/dev/null | head -n1) || true
  if [[ -z "$phr_file" ]]; then
    echo "Error: No .phr file found in $DB_DIR" >&2; exit 1
  fi
  prefix=$(basename "$phr_file" .phr)
  DB_PATH="$DB_DIR/$prefix"
  echo "Auto-detected BLAST DB: $DB_PATH"
else
  DB_PATH="$db_base_arg"
  DB_DIR=$(dirname "$DB_PATH")
fi

# Configuration
detect_cores=$(nproc)
JOBS=16           # concurrent jobs
TPJ=2             # threads per job
EVALUE="1e-3"
FORMAT="6 qseqid sseqid stitle pident length mismatch gapopen qstart qend sstart send evalue bitscore qlen slen"

# Prep
echo "Detected $detect_cores CPU cores."
if (( JOBS * TPJ > detect_cores )); then
  echo "WARNING: JOBS($JOBS)*TPJ($TPJ)=$((JOBS*TPJ)) > cores ($detect_cores)"
fi
mkdir -p "$OUT_DIR"

# RAM disk copy
if [[ -n "$RAMDISK" ]]; then
  WORKDIR="$RAMDISK/blastx_run_$$"
  echo "Using RAMDISK at $WORKDIR"
  mkdir -p "$WORKDIR/chunks"

  echo "Copying DB files into RAMDISK..."
  cp "${DB_PATH}".* "$WORKDIR/"
  echo "DB size in RAM: $(du -sh "$WORKDIR" | cut -f1)"

  echo "Copying FASTA chunks into RAMDISK..."
  cp "$INPUT_DIR"/*.fa "$WORKDIR/chunks/"
  echo "Chunks size in RAM: $(du -sh "$WORKDIR/chunks" | cut -f1)"

  CHUNK_DIR="$WORKDIR/chunks"
  export BLASTDB="$WORKDIR"
else
  CHUNK_DIR="$INPUT_DIR"
  export BLASTDB="$DB_DIR"
fi

# Verify DB
if [[ ! -f "${DB_PATH}.phr" ]]; then
  echo "Error: DB not found: ${DB_PATH}.phr" >&2; exit 1
fi

# Build file list
if (( TEST_CHUNKS > 0 )); then
  mapfile -t FILES < <(ls "$CHUNK_DIR"/*.fa | head -n "$TEST_CHUNKS")
else
  mapfile -t FILES < <(ls "$CHUNK_DIR"/*.fa)
fi
if [[ ${#FILES[@]} -eq 0 ]]; then echo "No FASTA files in $CHUNK_DIR" >&2; exit 1; fi

echo "Processing ${#FILES[@]} chunks with up to $JOBS jobs... Keeping top $TOP_HITS hits."

# Run parallel
default_cmds=()
for f in "${FILES[@]}"; do
  name=$(basename "$f" .fa)
  default_cmds+=("blastx -query '$f' -db '$DB_PATH' -outfmt '$FORMAT' \
    -evalue $EVALUE -max_target_seqs $TOP_HITS -num_threads $TPJ -out '$OUT_DIR/$name.blastx.tsv'")
done

printf "%s
" "${default_cmds[@]}" | parallel --jobs "$JOBS" --bar

echo "All jobs complete. Results in $OUT_DIR"

# Cleanup
if [[ -n "$RAMDISK" ]]; then
  echo "Cleaning up RAMDISK workspace..."
  rm -rf "$WORKDIR"
fi

# OPTIONAL merge:
cat "$OUT_DIR"/*.blastx.tsv > all_top${TOP_HITS}_results.tsv
echo "Merged into all_top${TOP_HITS}_results.tsv"
