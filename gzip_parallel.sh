#!/bin/bash

TARGET_DIR="${1:-.}"
cd "$TARGET_DIR" || { echo "Cannot access directory: $TARGET_DIR"; exit 1; }

# Parallel gzip with progress output
find . -maxdepth 1 -type f -name "*.fastq" | parallel -j 32 gzip
